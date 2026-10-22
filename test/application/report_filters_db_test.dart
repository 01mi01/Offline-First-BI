import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/report_service.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/models/product_model.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/models/sale_item_model.dart';
import 'package:offline_first_bi/models/sale_model.dart';

bool _inDateRange(DateTime date, DateTime? start, DateTime? end) {
  if (start != null) {
    final startOfDay = DateTime(start.year, start.month, start.day);
    if (date.isBefore(startOfDay)) return false;
  }
  if (end != null) {
    final dayAfterEnd = DateTime(end.year, end.month, end.day + 1);
    if (!date.isBefore(dayAfterEnd)) return false;
  }
  return true;
}

Set<int> _expectedSaleIds({
  required List<SaleModel> sales,
  required Map<int, List<SaleItemModel>> itemsMap,
  required Map<int, int> productCategory,
  required ReportFilters f,
}) {
  final result = <int>{};
  for (final s in sales) {
    if (!_inDateRange(s.date, f.startDate, f.endDate)) continue;
    if (f.clientId != null && s.clientId != f.clientId) continue;
    if (f.locationId != null && s.locationId != f.locationId) continue;
    if (f.eventId != null && s.eventId != f.eventId) continue;

    final items = itemsMap[s.id] ?? const <SaleItemModel>[];

    final hasLineFilters =
        f.productId != null || f.categoryId != null || f.priceType != null;
    if (hasLineFilters) {
      final someLineMatches = items.any(
        (i) =>
            (f.productId == null || i.productId == f.productId) &&
            (f.categoryId == null ||
                productCategory[i.productId] == f.categoryId) &&
            (f.priceType == null || i.priceType == f.priceType),
      );
      if (!someLineMatches) continue;
    }

    result.add(s.id);
  }
  return result;
}

Set<int> _expectedPurchaseIds({
  required List<PurchaseModel> purchases,
  required ReportFilters f,
}) {
  final result = <int>{};
  for (final p in purchases) {
    if (!_inDateRange(p.date, f.startDate, f.endDate)) continue;
    if (f.supplierId != null && p.supplierId != f.supplierId) continue;
    if (f.locationId != null && p.locationId != f.locationId) continue;
    if (f.eventId != null && p.eventId != f.eventId) continue;
    result.add(p.id);
  }
  return result;
}

typedef _FilterProbe = ({String name, ReportFilters Function(ReportFilters base) apply});

void main() {
  late AppDatabase db;
  late SaleRepository saleRepo;
  late PurchaseRepository purchaseRepo;
  final service = ReportService();

  late int catBolsasId, catLibrosId, catSinCategoriaId;
  late int p1Id, p2Id, p3Id;
  late int l1Id, l2Id, l3Id;
  late int e1Id, e2Id, e3Id;
  late int cl1Id, cl2Id, cl3Id;
  late int su1Id, su2Id, su3Id;

  late List<ProductModel> allProducts;
  late List<SaleModel> allSales;
  late List<PurchaseModel> allPurchases;
  late Map<int, List<SaleItemModel>> itemsMap;
  late Map<int, int> productCategory;

  final rangeStart = DateTime(2024, 1, 1);
  final rangeEnd = DateTime(2024, 1, 31);

  setUpAll(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    saleRepo = SaleRepository(db);
    purchaseRepo = PurchaseRepository(db);

    catBolsasId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'Bolsas'));
    catLibrosId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'Libros'));
    catSinCategoriaId = (await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Sin categoría'))).getSingle()).id;

    p1Id = await db.into(db.products).insert(
          ProductsCompanion.insert(
            categoryId: catBolsasId,
            name: 'Pines grandes',
            priceA: 100,
            priceB: 80,
          ),
        );
    p2Id = await db.into(db.products).insert(
          ProductsCompanion.insert(
            categoryId: catLibrosId,
            name: 'Set de pines pequeños',
            priceA: 50,
            priceB: 40,
          ),
        );
    p3Id = await db.into(db.products).insert(
          ProductsCompanion.insert(
            categoryId: catSinCategoriaId,
            name: 'Stickers',
            priceA: 20,
            priceB: 15,
          ),
        );
    productCategory = {
      p1Id: catBolsasId,
      p2Id: catLibrosId,
      p3Id: catSinCategoriaId,
    };

    l1Id = await db
        .into(db.locations)
        .insert(LocationsCompanion.insert(city: 'La Paz - Calacoto', country: 'Bolivia'));
    l2Id = await db.into(db.locations).insert(
          LocationsCompanion.insert(city: 'Santa Cruz - Equipetrol', country: 'Bolivia'),
        );
    l3Id = await db
        .into(db.locations)
        .insert(LocationsCompanion.insert(city: 'Santa Cruz - Las Palmas', country: 'Bolivia'));

    e1Id = await db.into(db.events).insert(
          EventsCompanion.insert(name: 'Feria del Libro Cochabamba', startDate: DateTime(2024, 1, 1)),
        );
    e2Id = await db.into(db.events).insert(
          EventsCompanion.insert(
            name: 'Larga Noche de Museos La Paz',
            startDate: DateTime(2024, 1, 15),
          ),
        );
    e3Id = await db.into(db.events).insert(
          EventsCompanion.insert(
            name: 'Feria Activa',
            startDate: DateTime(2024, 6, 1),
          ),
        );

    cl1Id = await db.into(db.clients).insert(ClientsCompanion.insert(name: 'John Smith'));
    cl2Id = await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Emily Johnson'));
    cl3Id = await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Ana Martínez'));

    su1Id = await db
        .into(db.suppliers)
        .insert(SuppliersCompanion.insert(name: 'Riverside Supply Co.'));
    su2Id = await db
        .into(db.suppliers)
        .insert(SuppliersCompanion.insert(name: 'Harbor Textiles'));
    su3Id = await db
        .into(db.suppliers)
        .insert(SuppliersCompanion.insert(name: 'Aurelia Studio'));

    await saleRepo.createSale(
      clientId: cl1Id,
      locationId: l1Id,
      eventId: e1Id,
      totalAmount: 200,
      discount: 0,
      finalAmount: 200,
      date: rangeStart,
      notes: 'S1',
      items: [
        {'productId': p1Id, 'quantity': 2, 'unitPrice': 100.0, 'priceType': 'A'},
      ],
    );
    await saleRepo.createSale(
      clientId: cl2Id,
      locationId: l2Id,
      eventId: e2Id,
      totalAmount: 40,
      discount: 0,
      finalAmount: 40,
      date: DateTime(2024, 1, 15),
      notes: 'S2',
      items: [
        {'productId': p2Id, 'quantity': 1, 'unitPrice': 40.0, 'priceType': 'B'},
      ],
    );
    await saleRepo.createSale(
      clientId: cl1Id,
      locationId: l1Id,
      eventId: e1Id,
      totalAmount: 110,
      discount: 10,
      finalAmount: 100,
      date: rangeEnd,
      notes: 'S3',
      items: [
        {'productId': p3Id, 'quantity': 3, 'unitPrice': 20.0, 'priceType': 'A'},
        {'productId': p2Id, 'quantity': 1, 'unitPrice': 50.0, 'priceType': 'A'},
      ],
    );
    await saleRepo.createSale(
      clientId: cl2Id,
      locationId: l2Id,
      eventId: e2Id,
      totalAmount: 80,
      discount: 0,
      finalAmount: 80,
      date: DateTime(2024, 2, 2),
      notes: 'S4',
      items: [
        {'productId': p1Id, 'quantity': 1, 'unitPrice': 80.0, 'priceType': 'B'},
      ],
    );
    await saleRepo.createSale(
      clientId: cl1Id,
      locationId: l1Id,
      eventId: e1Id,
      totalAmount: 50,
      discount: 0,
      finalAmount: 50,
      date: DateTime(2023, 12, 31),
      notes: 'S5',
      items: [
        {'productId': p2Id, 'quantity': 1, 'unitPrice': 50.0, 'priceType': 'A'},
      ],
    );

    await purchaseRepo.createPurchase(
      supplierId: su1Id,
      isMaterial: true,
      description: 'Hotel',
      totalAmount: 100,
      date: rangeStart,
      locationId: l1Id,
      eventId: e1Id,
      notes: 'PU1',
      items: const [],
    );
    await purchaseRepo.createPurchase(
      supplierId: su2Id,
      isMaterial: false,
      description: 'Pasaje de bus',
      totalAmount: 30,
      date: DateTime(2024, 1, 15),
      locationId: l2Id,
      eventId: e2Id,
      notes: 'PU2',
      items: const [],
    );
    await purchaseRepo.createPurchase(
      supplierId: su1Id,
      isMaterial: true,
      description: 'Participación en feria',
      totalAmount: 70,
      date: rangeEnd,
      locationId: l1Id,
      eventId: e1Id,
      notes: 'PU3',
      items: const [],
    );
    await purchaseRepo.createPurchase(
      supplierId: su2Id,
      isMaterial: true,
      description: 'Pasaje de avión',
      totalAmount: 20,
      date: DateTime(2024, 2, 2),
      locationId: l2Id,
      eventId: e2Id,
      notes: 'PU4',
      items: const [],
    );
    await purchaseRepo.createPurchase(
      supplierId: su1Id,
      isMaterial: true,
      description: 'Hotel',
      totalAmount: 10,
      date: DateTime(2023, 12, 31),
      locationId: l1Id,
      eventId: e1Id,
      notes: 'PU5',
      items: const [],
    );

    allProducts = await db.select(db.products).get().then(
          (rows) => rows
              .map(
                (r) => ProductModel(
                  id: r.id,
                  categoryId: r.categoryId,
                  name: r.name,
                  priceA: r.priceA,
                  priceB: r.priceB,
                  stock: r.stock,
                  isActive: r.isActive,
                  createdAt: r.createdAt,
                ),
              )
              .toList(),
        );
    allSales = await saleRepo.getAll();
    allPurchases = await purchaseRepo.getAll();
    itemsMap = {
      for (final s in allSales) s.id: await saleRepo.getItemsForSale(s.id),
    };
  });

  tearDownAll(() async {
    await db.close();
  });

  Set<int> actualSaleIds(ReportFilters f) => service
      .filterSales(
        sales: allSales,
        products: allProducts,
        saleItemsMap: itemsMap,
        filters: f,
      )
      .map((s) => s.id)
      .toSet();

  Set<int> actualPurchaseIds(ReportFilters f) => service
      .filterPurchases(purchases: allPurchases, filters: f)
      .map((p) => p.id)
      .toSet();

  void expectSalesMatch(ReportFilters f, {String? reason}) {
    final expected = _expectedSaleIds(
      sales: allSales,
      itemsMap: itemsMap,
      productCategory: productCategory,
      f: f,
    );
    expect(actualSaleIds(f), expected, reason: reason ?? f.toString());
  }

  void expectPurchasesMatch(ReportFilters f, {String? reason}) {
    final expected = _expectedPurchaseIds(purchases: allPurchases, f: f);
    expect(actualPurchaseIds(f), expected, reason: reason ?? f.toString());
  }

  group('regression: endDate + 1 day boundary (previously a known bug)', () {
    test('a sale dated exactly at endDate + 1 day (midnight) is excluded', () {
      final oneDayAfterEndDate = rangeEnd.add(const Duration(days: 1));
      final leakingSale = SaleModel(
        id: 90001,
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 1,
        discount: 0,
        finalAmount: 1,
        date: oneDayAfterEndDate,
        createdAt: oneDayAfterEndDate,
      );

      final result = service.filterSales(
        sales: [leakingSale],
        products: const [],
        saleItemsMap: const {},
        filters: ReportFilters(startDate: rangeStart, endDate: rangeEnd),
      );

      expect(result, isEmpty);
    });

    test('a purchase dated exactly at endDate + 1 day (midnight) is excluded', () {
      final oneDayAfterEndDate = rangeEnd.add(const Duration(days: 1));
      final leakingPurchase = PurchaseModel(
        id: 90002,
        supplierId: null,
        locationId: null,
        eventId: null,
        isMaterial: false,
        totalAmount: 1,
        date: oneDayAfterEndDate,
        createdAt: oneDayAfterEndDate,
      );

      final result = service.filterPurchases(
        purchases: [leakingPurchase],
        filters: ReportFilters(startDate: rangeStart, endDate: rangeEnd),
      );

      expect(result, isEmpty);
    });
  });

  test('fixture sanity: 5 sales and 5 purchases were seeded with distinct tags', () {
    expect(allSales.map((s) => s.notes).toSet(), {'S1', 'S2', 'S3', 'S4', 'S5'});
    expect(
      allPurchases.map((p) => p.notes).toSet(),
      {'PU1', 'PU2', 'PU3', 'PU4', 'PU5'},
    );
  });

  group('sales filters', () {
    late final List<_FilterProbe> probes;

    setUpAll(() {
      probes = [
        (
          name: 'dateRange',
          apply: (f) => f.copyWith(startDate: rangeStart, endDate: rangeEnd),
        ),
        (name: 'client', apply: (f) => f.copyWith(clientId: cl1Id)),
        (name: 'location', apply: (f) => f.copyWith(locationId: l1Id)),
        (name: 'event', apply: (f) => f.copyWith(eventId: e1Id)),
        (name: 'product', apply: (f) => f.copyWith(productId: p2Id)),
        (name: 'category', apply: (f) => f.copyWith(categoryId: catLibrosId)),
        (name: 'priceType', apply: (f) => f.copyWith(priceType: 'A')),
      ];
    });

    test('no filters returns every seeded sale', () {
      expectSalesMatch(const ReportFilters());
      expect(actualSaleIds(const ReportFilters()), hasLength(5));
    });

    group('each filter alone', () {
      test('setup produces 7 probes', () => expect(probes, hasLength(7)));

      for (final name in [
        'dateRange',
        'client',
        'location',
        'event',
        'product',
        'category',
        'priceType',
      ]) {
        test('filter alone: $name', () {
          final probe = probes.firstWhere((p) => p.name == name);
          expectSalesMatch(probe.apply(const ReportFilters()));
        });
      }
    });

    test('every pairwise combination of the 7 sales filter dimensions', () {
      var pairsChecked = 0;
      for (var i = 0; i < probes.length; i++) {
        for (var j = i + 1; j < probes.length; j++) {
          final filters = probes[i].apply(probes[j].apply(const ReportFilters()));
          expectSalesMatch(
            filters,
            reason: 'pair ${probes[i].name} + ${probes[j].name}: $filters',
          );
          pairsChecked++;
        }
      }
      expect(pairsChecked, 21);
    });

    test('all 7 sales filter dimensions combined at once', () {
      final combined = probes.fold<ReportFilters>(
        const ReportFilters(),
        (acc, p) => p.apply(acc),
      );
      expectSalesMatch(combined);
    });

    group('hand-verified spot checks (independent of the probe/reference machinery)', () {
      test('date range + client -> S1 and S3 only', () {
        final result = service.filterSales(
          sales: allSales,
          products: allProducts,
          saleItemsMap: itemsMap,
          filters: ReportFilters(
            startDate: rangeStart,
            endDate: rangeEnd,
            clientId: cl1Id,
          ),
        );
        expect(result.map((s) => s.notes).toSet(), {'S1', 'S3'});
      });

      test('"Sin categoría" filters exactly like any other category (-> S3 only)', () {
        final result = service.filterSales(
          sales: allSales,
          products: allProducts,
          saleItemsMap: itemsMap,
          filters: ReportFilters(
            startDate: rangeStart,
            endDate: rangeEnd,
            categoryId: catSinCategoriaId,
          ),
        );
        expect(result.map((s) => s.notes).toSet(), {'S3'});
      });

      test('priceType B + location L2 -> S2 only', () {
        final result = service.filterSales(
          sales: allSales,
          products: allProducts,
          saleItemsMap: itemsMap,
          filters: ReportFilters(priceType: 'B', locationId: l2Id),
        );
        expect(result.map((s) => s.notes).toSet(), {'S2', 'S4'});
      });

      test('single-day range on the start boundary -> S1 only', () {
        final result = service.filterSales(
          sales: allSales,
          products: allProducts,
          saleItemsMap: itemsMap,
          filters: ReportFilters(startDate: rangeStart, endDate: rangeStart),
        );
        expect(result.map((s) => s.notes).toSet(), {'S1'});
      });

      test('single-day range on the end boundary -> S3 only', () {
        final result = service.filterSales(
          sales: allSales,
          products: allProducts,
          saleItemsMap: itemsMap,
          filters: ReportFilters(startDate: rangeEnd, endDate: rangeEnd),
        );
        expect(result.map((s) => s.notes).toSet(), {'S3'});
      });
    });

    group('edge cases: filters that match nothing', () {
      test('unused location -> empty result, zero totals, no crash', () {
        final filtered = service.filterSales(
          sales: allSales,
          products: allProducts,
          saleItemsMap: itemsMap,
          filters: ReportFilters(locationId: l3Id),
        );
        expect(filtered, isEmpty);
        final summary = service.summarizeSaleRows(
          service.buildSaleRows(
            sales: filtered,
            clients: const [],
            locations: const [],
            events: const [],
          ),
        );
        expect(summary.count, 0);
        expect(summary.totalAmount, 0);
        expect(summary.totalDiscount, 0);
      });

      test('unused event -> empty result', () {
        expect(actualSaleIds(ReportFilters(eventId: e3Id)), isEmpty);
      });

      test('unused client -> empty result', () {
        expect(actualSaleIds(ReportFilters(clientId: cl3Id)), isEmpty);
      });

      test('nonexistent product id -> empty result', () {
        expect(actualSaleIds(const ReportFilters(productId: 999999)), isEmpty);
      });

      test('nonexistent category id -> empty result', () {
        expect(actualSaleIds(const ReportFilters(categoryId: 999999)), isEmpty);
      });

      test('date range strictly outside all seeded sales -> empty result', () {
        expect(
          actualSaleIds(ReportFilters(startDate: DateTime(2025, 1, 1), endDate: DateTime(2025, 1, 2))),
          isEmpty,
        );
      });
    });
  });

  group('purchases filters', () {
    late final List<_FilterProbe> probes;

    setUpAll(() {
      probes = [
        (
          name: 'dateRange',
          apply: (f) => f.copyWith(startDate: rangeStart, endDate: rangeEnd),
        ),
        (name: 'supplier', apply: (f) => f.copyWith(supplierId: su1Id)),
        (name: 'location', apply: (f) => f.copyWith(locationId: l1Id)),
        (name: 'event', apply: (f) => f.copyWith(eventId: e1Id)),
      ];
    });

    test('no filters returns every seeded purchase', () {
      expectPurchasesMatch(const ReportFilters());
      expect(actualPurchaseIds(const ReportFilters()), hasLength(5));
    });

    group('each filter alone', () {
      for (final name in ['dateRange', 'supplier', 'location', 'event']) {
        test('filter alone: $name', () {
          final probe = probes.firstWhere((p) => p.name == name);
          expectPurchasesMatch(probe.apply(const ReportFilters()));
        });
      }
    });

    test('every pairwise combination of the 4 purchases filter dimensions', () {
      var pairsChecked = 0;
      for (var i = 0; i < probes.length; i++) {
        for (var j = i + 1; j < probes.length; j++) {
          final filters = probes[i].apply(probes[j].apply(const ReportFilters()));
          expectPurchasesMatch(
            filters,
            reason: 'pair ${probes[i].name} + ${probes[j].name}: $filters',
          );
          pairsChecked++;
        }
      }
      expect(pairsChecked, 6);
    });

    test('all 4 purchases filter dimensions combined at once', () {
      final combined = probes.fold<ReportFilters>(
        const ReportFilters(),
        (acc, p) => p.apply(acc),
      );
      expectPurchasesMatch(combined);
    });

    group('hand-verified spot checks', () {
      test('date range + supplier -> PU1 and PU3 only', () {
        final result = service.filterPurchases(
          purchases: allPurchases,
          filters: ReportFilters(
            startDate: rangeStart,
            endDate: rangeEnd,
            supplierId: su1Id,
          ),
        );
        expect(result.map((p) => p.notes).toSet(), {'PU1', 'PU3'});
      });

      test('filterPurchases ignores clientId/productId/categoryId/priceType entirely', () {
        final withIrrelevantFilters = ReportFilters(
          startDate: rangeStart,
          endDate: rangeEnd,
          clientId: cl2Id,
          productId: p1Id,
          categoryId: catBolsasId,
          priceType: 'B',
        );
        final withoutThem = ReportFilters(startDate: rangeStart, endDate: rangeEnd);
        expect(actualPurchaseIds(withIrrelevantFilters), actualPurchaseIds(withoutThem));
      });
    });

    group('edge cases: filters that match nothing', () {
      test('unused supplier -> empty result, zero totals, no crash', () {
        final filtered = service.filterPurchases(
          purchases: allPurchases,
          filters: ReportFilters(supplierId: su3Id),
        );
        expect(filtered, isEmpty);
        final summary = service.summarizePurchases(filtered);
        expect(summary.count, 0);
        expect(summary.totalAmount, 0);
        expect(summary.materialCount, 0);
      });

      test('unused location -> empty result', () {
        expect(actualPurchaseIds(ReportFilters(locationId: l3Id)), isEmpty);
      });

      test('unused event -> empty result', () {
        expect(actualPurchaseIds(ReportFilters(eventId: e3Id)), isEmpty);
      });
    });
  });

  group('summarizeSaleRows / summarizePurchases / test-side balance over a filtered window', () {
    test('totals for the [rangeStart, rangeEnd] window match hand computation', () {
      final filters = ReportFilters(startDate: rangeStart, endDate: rangeEnd);
      final sales = service.filterSales(
        sales: allSales,
        products: allProducts,
        saleItemsMap: itemsMap,
        filters: filters,
      );
      final purchases = service.filterPurchases(purchases: allPurchases, filters: filters);

      final salesSummary = service.summarizeSaleRows(
        service.buildSaleRows(
          sales: sales,
          clients: const [],
          locations: const [],
          events: const [],
        ),
      );
      final purchasesSummary = service.summarizePurchases(purchases);

      expect(salesSummary.count, 3);
      expect(salesSummary.totalAmount, 340);
      expect(salesSummary.totalDiscount, 10);

      expect(purchasesSummary.count, 3);
      expect(purchasesSummary.totalAmount, 200);
      expect(purchasesSummary.materialCount, 2);

      final balance = salesSummary.totalAmount - purchasesSummary.totalAmount;
      expect(balance, 140);
    });
  });
}
