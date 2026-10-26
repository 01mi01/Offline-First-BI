import 'dart:io';

import 'package:drift/drift.dart' hide isNull, Column;
import 'package:drift/native.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/category_provider.dart';
import 'package:offline_first_bi/application/client_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/event_provider.dart';
import 'package:offline_first_bi/application/location_provider.dart';
import 'package:offline_first_bi/application/module_permission_provider.dart';
import 'package:offline_first_bi/application/product_provider.dart';
import 'package:offline_first_bi/application/purchase_provider.dart';
import 'package:offline_first_bi/application/report_provider.dart';
import 'package:offline_first_bi/application/report_service.dart';
import 'package:offline_first_bi/application/sale_provider.dart';
import 'package:offline_first_bi/application/supplier_provider.dart';
import 'package:offline_first_bi/config/app_clock.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/models/sale_model.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'helpers/pdf_text.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempPath);
  final String tempPath;
  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

class _FakeShare extends SharePlatform {
  final List<List<XFile>> calls = [];
  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    calls.add(files);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

SaleModel _sale({
  required int id,
  int? clientId,
  int? locationId,
  int? eventId,
  required DateTime date,
  double totalAmount = 100,
  double discount = 0,
  double? finalAmount,
}) {
  return SaleModel(
    id: id,
    clientId: clientId,
    locationId: locationId,
    eventId: eventId,
    totalAmount: totalAmount,
    discount: discount,
    finalAmount: finalAmount ?? (totalAmount - discount),
    date: date,
    createdAt: date,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = appNow();
  DateTime at(DateTime day, [int hour = 12]) =>
      DateTime(day.year, day.month, day.day, hour);
  final today = at(now);
  final lastMonth = DateTime(now.year, now.month - 1, 15, 12);
  final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);
  final nextWeek = DateTime(now.year, now.month, now.day + 7, 12);

  late AppDatabase db;
  late ProviderContainer container;
  late Directory tempDir;
  late _FakeShare fakeShare;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('reports_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    fakeShare = _FakeShare();
    SharePlatform.instance = fakeShare;

    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Tote bag negra',
        priceA: 100,
        priceB: 100,
        stock: const Value(100),
      ),
    );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        readableModulesProvider.overrideWith(
          (ref) async => ['ventas', 'compras'],
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> refresh() async {
    await container.read(saleProvider.notifier).load();
    await container.read(purchaseProvider.notifier).load();
    await container.read(eventProvider.notifier).load();
    await container.read(productProvider.notifier).load();
    await container.read(categoryProvider.notifier).load();
    await container.read(clientProvider.notifier).load();
    await container.read(locationProvider.notifier).load();
    await container.read(supplierProvider.notifier).load();
    container.listen(saleItemsMapProvider, (_, _) {});
    container.invalidate(saleItemsMapProvider);
    await container.read(saleItemsMapProvider.future);
    container.invalidate(purchaseItemsMapProvider);
    container.listen(purchaseItemsMapProvider, (_, _) {});
    await container.read(purchaseItemsMapProvider.future);
  }

  Future<String?> sell(DateTime date, {double amount = 100, int? eventId}) =>
      container.read(saleProvider.notifier).createSale(
        clientId: null,
        locationId: null,
        eventId: eventId,
        totalAmount: amount,
        discount: 0,
        finalAmount: amount,
        date: date,
        items: [
          {'productId': 1, 'quantity': 1, 'unitPrice': amount, 'priceType': 'A'},
        ],
      );

  Future<String?> spend(DateTime date, {double amount = 40, int? eventId}) =>
      container.read(purchaseProvider.notifier).createPurchase(
        supplierId: null,
        locationId: null,
        eventId: eventId,
        isMaterial: false,
        description: 'Participación en feria',
        totalAmount: amount,
        date: date,
        items: const [],
      );

  double income(ReportFilters f) => container.read(reportServiceProvider).summarizeSaleRows(container.read(saleReportRowsProvider(f))).totalAmount;
  int salesCount(ReportFilters f) => container.read(reportServiceProvider).summarizeSaleRows(container.read(saleReportRowsProvider(f))).count;
  double expenses(ReportFilters f) {
    final list = container.read(filteredPurchasesProvider(f));
    return container.read(purchasesSummaryProvider(list)).totalAmount;
  }

  ReportFilters range(DateTime from, [DateTime? to]) =>
      ReportFilters(startDate: DateTime(from.year, from.month, from.day),
          endDate: to == null ? null : DateTime(to.year, to.month, to.day));

  final lastMonthStart = DateTime(now.year, now.month - 1, 1);
  final lastMonthEnd = DateTime(now.year, now.month, 0);
  final thisMonthStart = DateTime(now.year, now.month, 1);

  test('a future-dated sale/purchase never counts, even with no filters', () async {
    await sell(today, amount: 100);
    await sell(tomorrow, amount: 999);
    await sell(nextWeek, amount: 888);
    await spend(today, amount: 40);
    await spend(nextWeek, amount: 777);
    await refresh();

    expect(income(const ReportFilters()), 100);
    expect(salesCount(const ReportFilters()), 1);
    expect(expenses(const ReportFilters()), 40);
  });

  test('PDF and Excel totals equal the on-screen figures for the same filters', () async {
    await sell(today, amount: 100);
    await sell(lastMonth, amount: 250);
    await sell(nextWeek, amount: 999);
    await spend(today, amount: 40);
    await spend(lastMonth, amount: 60);
    await spend(nextWeek, amount: 777);
    await refresh();

    Future<void> check(ReportFilters f, double wantIncome, double wantExpense) async {
      final saleRows = container.read(saleReportRowsProvider(f));
      final summary = container.read(reportServiceProvider).summarizeSaleRows(container.read(saleReportRowsProvider(f)));
      final purchases = container.read(filteredPurchasesProvider(f));
      final purchaseRows = container.read(purchaseReportRowsProvider(purchases));
      final pSummary = container.read(purchasesSummaryProvider(purchases));
      expect(summary.totalAmount, wantIncome);
      expect(pSummary.totalAmount, wantExpense);

      final repo = container.read(reportExportRepositoryProvider);
      fakeShare.calls.clear();

      await repo.exportSalesExcel(title: 'Ventas', rows: saleRows);
      var bytes = await File(fakeShare.calls.last.single.path).readAsBytes();
      var sheet = xl.Excel.decodeBytes(bytes).tables['Reporte']!;
      num total(xl.CellValue? v) => switch (v) {
        xl.IntCellValue i => i.value,
        xl.DoubleCellValue d => d.value,
        _ => 0,
      };
      expect(
        sheet.rows.skip(1).fold<num>(0, (s, r) => s + total(r[6]?.value)),
        wantIncome,
      );
      expect(sheet.rows.length - 1, summary.count);

      await repo.exportSalesPdf(title: 'Ventas', rows: saleRows, summary: summary);
      var pdf = PdfText.extract(await File(fakeShare.calls.last.single.path).readAsBytes());
      expect(pdf.text, contains('Ingresos: Bs. ${wantIncome.toStringAsFixed(2)}'));
      expect(pdf.text, contains('Total ventas: ${summary.count}'));

      await repo.exportPurchasesExcel(title: 'Compras', rows: purchaseRows);
      bytes = await File(fakeShare.calls.last.single.path).readAsBytes();
      sheet = xl.Excel.decodeBytes(bytes).tables['Reporte']!;
      expect(
        sheet.rows.skip(1).fold<num>(0, (s, r) => s + total(r[6]?.value)),
        wantExpense,
      );
      await repo.exportPurchasesPdf(title: 'Compras', rows: purchaseRows, summary: pSummary);
      pdf = PdfText.extract(await File(fakeShare.calls.last.single.path).readAsBytes());
      expect(pdf.text, contains('Gasto: Bs. ${wantExpense.toStringAsFixed(2)}'));
    }

    await check(const ReportFilters(), 350, 100);
    await check(range(lastMonthStart, lastMonthEnd), 250, 60);
    await check(range(thisMonthStart, today), 100, 40);
    await check(range(today), 100, 40);
  });

  final service = ReportService();

  test('a canceled sale is left out of reports (it is no longer income)', () {
    final active = _sale(id: 1, date: DateTime(2024, 1, 5));
    final canceled = SaleModel(
      id: 2,
      totalAmount: 100,
      discount: 0,
      finalAmount: 100,
      date: DateTime(2024, 1, 6),
      createdAt: DateTime(2024, 1, 6),
      isCanceled: true,
      canceledAt: DateTime(2024, 1, 7),
    );

    final result = service.filterSales(
      sales: [active, canceled],
      products: const [],
      saleItemsMap: const {},
      filters: const ReportFilters(),
    );

    expect(result.map((s) => s.id), [1]);
  });
}
