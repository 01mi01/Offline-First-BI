import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/category_provider.dart';
import 'package:offline_first_bi/application/client_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/event_provider.dart';
import 'package:offline_first_bi/application/location_provider.dart';
import 'package:offline_first_bi/application/product_provider.dart';
import 'package:offline_first_bi/application/report_provider.dart';
import 'package:offline_first_bi/application/report_service.dart';
import 'package:offline_first_bi/application/sale_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/category_repository.dart';
import 'package:offline_first_bi/data/repositories/product_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/models/report_models.dart';

void main() {
  late AppDatabase db;
  late SaleRepository saleRepo;
  final service = ReportService();

  late int miniaturasId, sinCategoriaId;
  late int estuchesId, pinesGrandesId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    saleRepo = SaleRepository(db);

    miniaturasId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'Miniaturas'));
    sinCategoriaId = (await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Sin categoría'))).getSingle()).id;

    estuchesId = await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: miniaturasId,
        name: 'Estuches',
        priceA: 50,
        priceB: 40,
        stock: const Value(100),
      ),
    );
    pinesGrandesId = await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: sinCategoriaId,
        name: 'Pines grandes',
        priceA: 12,
        priceB: 10,
        stock: const Value(100),
      ),
    );

    await saleRepo.createSale(
      clientId: null,
      locationId: null,
      eventId: null,
      totalAmount: 120,
      discount: 12,
      finalAmount: 108,
      date: DateTime(2024, 1, 10),
      items: [
        {'productId': estuchesId, 'quantity': 2, 'unitPrice': 50.0, 'priceType': 'A'},
        {'productId': pinesGrandesId, 'quantity': 2, 'unitPrice': 10.0, 'priceType': 'B'},
      ],
    );
    await saleRepo.createSale(
      clientId: null,
      locationId: null,
      eventId: null,
      totalAmount: 40,
      discount: 0,
      finalAmount: 40,
      date: DateTime(2024, 1, 11),
      items: [
        {'productId': estuchesId, 'quantity': 1, 'unitPrice': 40.0, 'priceType': 'B'},
      ],
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<SaleReportRow>> rowsFor(ReportFilters filters) async {
    final sales = await saleRepo.getAll();
    final products = await ProductRepository(db).getAllIncludingInactive();
    final categories = await CategoryRepository(db).getAllIncludingInactive();
    final itemsMap = {
      for (final s in sales) s.id: await saleRepo.getItemsForSale(s.id),
    };
    final filtered = service.filterSales(
      sales: sales,
      products: products,
      saleItemsMap: itemsMap,
      filters: filters,
    );
    return service.buildSaleRows(
      sales: filtered,
      clients: const [],
      locations: const [],
      events: const [],
      linesBySale: service.buildSaleLines(
        sales: filtered,
        products: products,
        categories: categories,
        saleItemsMap: itemsMap,
        filters: filters,
      ),
    );
  }

  List<String> lineNames(SaleReportRow row) =>
      row.lines!.map((l) => l.item.productName).toList();

  test('no line filters: every line of every sale, totals equal the sales totals', () async {
    final rows = await rowsFor(const ReportFilters());
    final summary = service.summarizeSaleRows(rows);

    expect(rows, hasLength(2));
    expect(summary.count, 2);
    expect(summary.totalAmount, closeTo(148, 1e-9));
    expect(summary.totalDiscount, closeTo(12, 1e-9));
  });

  test('filtering by "Sin categoría" keeps only the Pines grandes line of the mixed sale', () async {
    final rows = await rowsFor(ReportFilters(categoryId: sinCategoriaId));

    expect(rows, hasLength(1));
    final row = rows.single;
    expect(lineNames(row), ['Pines grandes']);
    expect(row.lines!.single.categoryName, 'Sin categoría');
    expect(row.subtotalAmount, closeTo(20, 1e-9));
    expect(row.discountAmount, closeTo(2, 1e-9));
    expect(row.netAmount, closeTo(18, 1e-9));

    final summary = service.summarizeSaleRows(rows);
    expect(summary.count, 1);
    expect(summary.totalAmount, closeTo(18, 1e-9));
    expect(summary.totalDiscount, closeTo(2, 1e-9));
  });

  test('filtering by the other category breaks the same sale down the other way', () async {
    final rows = await rowsFor(ReportFilters(categoryId: miniaturasId));

    expect(rows, hasLength(2));
    final byDate = {for (final r in rows) r.sale.date.day: r};
    expect(lineNames(byDate[10]!), ['Estuches']);
    expect(byDate[10]!.netAmount, closeTo(90, 1e-9));
    expect(lineNames(byDate[11]!), ['Estuches']);
    expect(byDate[11]!.netAmount, closeTo(40, 1e-9));

    final summary = service.summarizeSaleRows(rows);
    expect(summary.totalAmount, closeTo(130, 1e-9));
    expect(summary.totalDiscount, closeTo(10, 1e-9));
  });

  test('the per-category pieces of a mixed sale add up to the whole sale', () async {
    final sin = service.summarizeSaleRows(
      await rowsFor(ReportFilters(categoryId: sinCategoriaId)),
    );
    final pin = service.summarizeSaleRows(
      await rowsFor(ReportFilters(
        categoryId: miniaturasId,
        endDate: DateTime(2024, 1, 10),
      )),
    );
    expect(pin.totalAmount + sin.totalAmount, closeTo(108, 1e-9));
    expect(pin.totalDiscount + sin.totalDiscount, closeTo(12, 1e-9));
  });

  test('filtering by price type totals only the lines charged at that band', () async {
    final b = await rowsFor(const ReportFilters(priceType: 'B'));
    expect(b, hasLength(2));
    final bByDay = {for (final r in b) r.sale.date.day: r};
    expect(lineNames(bByDay[10]!), ['Pines grandes']);
    expect(bByDay[10]!.netAmount, closeTo(18, 1e-9));
    expect(bByDay[11]!.netAmount, closeTo(40, 1e-9));
    expect(service.summarizeSaleRows(b).totalAmount, closeTo(58, 1e-9));

    final a = await rowsFor(const ReportFilters(priceType: 'A'));
    expect(a, hasLength(1));
    expect(lineNames(a.single), ['Estuches']);
    expect(a.single.netAmount, closeTo(90, 1e-9));
  });

  test('filtering by product totals only that product\'s line', () async {
    final rows = await rowsFor(ReportFilters(productId: pinesGrandesId));
    expect(rows, hasLength(1));
    expect(lineNames(rows.single), ['Pines grandes']);
    expect(rows.single.netAmount, closeTo(18, 1e-9));
  });

  test('line filters combine on the SAME line, not across different lines of a sale', () async {
    final estuchesB = await rowsFor(
      ReportFilters(productId: estuchesId, priceType: 'B'),
    );
    expect(estuchesB.map((r) => r.sale.date.day), [11]);
    expect(service.summarizeSaleRows(estuchesB).totalAmount, closeTo(40, 1e-9));

    final none = await rowsFor(
      ReportFilters(categoryId: sinCategoriaId, priceType: 'A'),
    );
    expect(none, isEmpty);
    expect(service.summarizeSaleRows(none).totalAmount, 0);
  });

  test('sale-level filters (date) still apply on top of the line filters', () async {
    final rows = await rowsFor(
      ReportFilters(
        categoryId: miniaturasId,
        startDate: DateTime(2024, 1, 11),
        endDate: DateTime(2024, 1, 11),
      ),
    );
    expect(rows.map((r) => r.sale.date.day), [11]);
  });

  group('through the real Riverpod providers (what the Reportes screen watches)', () {
    late ProviderContainer container;

    setUp(() async {
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      await Future.wait([
        container.read(saleProvider.notifier).load(),
        container.read(productProvider.notifier).load(),
        container.read(categoryProvider.notifier).load(),
        container.read(clientProvider.notifier).load(),
        container.read(locationProvider.notifier).load(),
        container.read(eventProvider.notifier).load(),
      ]);
      await container.read(saleItemsMapProvider.future);
    });

    tearDown(() => container.dispose());

    test('saleReportRowsProvider + summarizeSaleRows total per line item', () {
      final filters = ReportFilters(categoryId: sinCategoriaId);

      final rows = container.read(saleReportRowsProvider(filters));
      final summary = container.read(reportServiceProvider).summarizeSaleRows(container.read(saleReportRowsProvider(filters)));

      expect(rows, hasLength(1));
      expect(rows.single.lines!.map((l) => l.item.productName), ['Pines grandes']);
      expect(summary.count, 1);
      expect(summary.totalAmount, closeTo(18, 1e-9));
      expect(summary.totalDiscount, closeTo(2, 1e-9));
    });

    test('with no filters the summary equals the whole sales', () {
      final summary = container.read(reportServiceProvider).summarizeSaleRows(container.read(saleReportRowsProvider(const ReportFilters())));
      expect(summary.count, 2);
      expect(summary.totalAmount, closeTo(148, 1e-9));
    });
  });
}
