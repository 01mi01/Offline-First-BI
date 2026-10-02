import 'dart:io';

import 'package:drift/drift.dart' hide isNull, Column;
import 'package:drift/native.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/category_provider.dart';
import 'package:offline_first_bi/application/client_provider.dart';
import 'package:offline_first_bi/application/event_provider.dart';
import 'package:offline_first_bi/application/location_provider.dart';
import 'package:offline_first_bi/application/product_provider.dart';
import 'package:offline_first_bi/application/supplier_provider.dart';
import 'package:offline_first_bi/application/purchase_provider.dart';
import 'package:offline_first_bi/application/report_provider.dart';
import 'package:offline_first_bi/application/sale_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/pages/home_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import '../support/pdf_text.dart';

// Auditoría de fechas: cada venta, compra o monto ligado a un evento se cuenta
// en el periodo de SU PROPIA fecha (la de la venta/compra), en Inicio,
// Reportes y exportaciones, sobre una base Drift real en memoria y los
// providers reales.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();
  DateTime at(DateTime day, [int hour = 12]) =>
      DateTime(day.year, day.month, day.day, hour);
  final today = at(now);
  // Un día de un mes anterior: nunca cae en "este mes".
  final lastMonth = DateTime(now.year, now.month - 1, 15, 12);
  final earlierLastMonth = DateTime(now.year, now.month - 1, 3, 12);
  final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);
  final nextWeek = DateTime(now.year, now.month, now.day + 7, 12);

  late AppDatabase db;
  late ProviderContainer container;
  late Directory tempDir;
  late _FakeShare fakeShare;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('date_audit_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    fakeShare = _FakeShare();
    SharePlatform.instance = fakeShare;

    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Cuadro',
        priceA: 100,
        priceB: 100,
        stock: const Value(100),
      ),
    );
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // Carga el estado real de los providers y mantiene vivos los autoDispose.
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
        description: 'Gasto',
        totalAmount: amount,
        date: date,
        items: const [],
      );

  Future<int> newEvent(String name, DateTime start, DateTime? end) async {
    await container.read(eventProvider.notifier).save(
      name: name,
      startDate: start,
      endDate: end,
    );
    await container.read(eventProvider.notifier).load();
    return container.read(eventProvider).events.firstWhere((e) => e.name == name).id;
  }

  double income(ReportFilters f) => container.read(salesSummaryProvider(f)).totalAmount;
  int salesCount(ReportFilters f) => container.read(salesSummaryProvider(f)).count;
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

  group('Reportes (item 2) - totales por fecha propia', () {
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

    test('past-dated sale appears only in its own period', () async {
      await sell(today, amount: 100);
      await sell(lastMonth, amount: 250);
      await spend(today, amount: 40);
      await spend(lastMonth, amount: 60);
      await refresh();

      // Rango "mes pasado"
      expect(income(range(lastMonthStart, lastMonthEnd)), 250);
      expect(expenses(range(lastMonthStart, lastMonthEnd)), 60);
      // Rango "este mes" (1.º a hoy)
      expect(income(range(thisMonthStart, today)), 100);
      expect(expenses(range(thisMonthStart, today)), 40);
      // Sin filtro: todo lo ya ocurrido
      expect(income(const ReportFilters()), 350);
      expect(expenses(const ReportFilters()), 100);
    });

    test('day, week, month, year, custom range and Desde-only single day', () async {
      DateTime d(int dayOffset, [int h = 12, int m = 0]) =>
          DateTime(now.year, now.month, now.day + dayOffset, h, m);
      final data = <(DateTime, double)>[
        (d(0), 10),
        (d(-1, 23, 59), 20),
        (d(-1, 0, 0), 40),
        (lastMonth, 80),
        (DateTime(now.year - 1, 6, 1, 12), 160),
        (d(3), 999), // futura: nunca cuenta
      ];
      for (final (date, amount) in data) {
        await sell(date, amount: amount);
      }
      await refresh();

      // Esperado calculado aparte: suma de lo ya ocurrido cuyo DÍA cae en
      // [from, to].
      double expected(DateTime from, DateTime to) {
        final a = DateTime(from.year, from.month, from.day);
        final b = DateTime(to.year, to.month, to.day);
        return data
            .where((e) {
              final day = DateTime(e.$1.year, e.$1.month, e.$1.day);
              final isToday = DateTime(now.year, now.month, now.day);
              return !day.isBefore(a) && !day.isAfter(b) && !day.isAfter(isToday);
            })
            .fold(0.0, (sum, e) => sum + e.$2);
      }

      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final cases = <String, (DateTime, DateTime?, DateTime)>{
        'día (Desde = Hasta)': (today, today, today),
        'Desde solo (un día)': (today, null, today),
        'ayer, Desde solo': (yesterday, null, yesterday),
        'ayer a hoy': (yesterday, today, today),
        'semana (lunes a hoy)': (monday, today, today),
        'mes pasado': (lastMonthStart, lastMonthEnd, lastMonthEnd),
        'este mes': (thisMonthStart, today, today),
        'año actual': (DateTime(now.year, 1, 1), today, today),
        'año anterior': (DateTime(now.year - 1, 1, 1), DateTime(now.year - 1, 12, 31), DateTime(now.year - 1, 12, 31)),
        'rango sin ventas': (DateTime(2020, 1, 1), DateTime(2020, 1, 31), DateTime(2020, 1, 31)),
      };
      cases.forEach((name, c) {
        expect(income(range(c.$1, c.$2)), expected(c.$1, c.$3), reason: name);
      });
      // Sin ningún filtro: todo lo ya ocurrido (sin la futura de 999).
      expect(income(const ReportFilters()), 10 + 20 + 40 + 80 + 160);
    });
  });

  group('Inicio (item 1)', () {
    Future<void> pumpHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: lightTheme, home: const HomePage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    String metric(WidgetTester tester, String label) {
      // La tarjeta es una Column: valor y luego etiqueta.
      final card = find.ancestor(
        of: find.text(label),
        matching: find.byType(Column),
      ).first;
      final texts = tester
          .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
          .map((t) => t.data!)
          .toList();
      return texts.first;
    }

    testWidgets('future-dated and last-month records stay out of the monthly figures', (tester) async {
      await tester.runAsync(() async {
        await sell(today, amount: 100);
        await sell(tomorrow, amount: 999);
        await sell(lastMonth, amount: 555);
        await spend(today, amount: 40);
        await spend(nextWeek, amount: 777);
        await spend(lastMonth, amount: 333);
        await refresh();
      });
      await pumpHome(tester);

      expect(metric(tester, 'Ingresos del mes'), 'Bs. 100.00');
      expect(metric(tester, 'Gastos del mes'), 'Bs. 40.00');
      // "Últimas ventas" tampoco muestra la venta futura (999).
      expect(find.text('Bs. 999.00'), findsNothing);
    });

    testWidgets('a past sale edited into this month moves into the monthly figure', (tester) async {
      await tester.runAsync(() async {
        await sell(lastMonth, amount: 250);
        await refresh();
      });
      await pumpHome(tester);
      expect(metric(tester, 'Ingresos del mes'), 'Bs. 0.00');

      await tester.runAsync(() async {
        final sale = container.read(saleProvider).sales.single;
        final err = await container.read(saleProvider.notifier).editSale(
          saleId: sale.id,
          clientId: sale.clientId,
          locationId: null,
          eventId: null,
          totalAmount: 250,
          discount: 0,
          finalAmount: 250,
          date: today,
          newItems: [
            {'productId': 1, 'quantity': 1, 'unitPrice': 250.0, 'priceType': 'A'},
          ],
        );
        expect(err, isNull);
      });
      await tester.pumpAndSettle();
      expect(metric(tester, 'Ingresos del mes'), 'Bs. 250.00');
    });
  });

  group('Crear / editar fecha (items 4 y 5)', () {
    test('editing the date moves a sale between periods: no double count, no orphan', () async {
      await sell(lastMonth, amount: 250);
      await refresh();
      final id = container.read(saleProvider).sales.single.id;

      expect(income(range(lastMonthStart, lastMonthEnd)), 250);
      expect(income(range(thisMonthStart, today)), 0);

      Future<void> moveTo(DateTime date) async {
        final err = await container.read(saleProvider.notifier).editSale(
          saleId: id,
          clientId: null,
          locationId: null,
          eventId: null,
          totalAmount: 250,
          discount: 0,
          finalAmount: 250,
          date: date,
          newItems: [
            {'productId': 1, 'quantity': 1, 'unitPrice': 250.0, 'priceType': 'A'},
          ],
        );
        expect(err, isNull);
        await refresh();
      }

      await moveTo(today);
      expect(income(range(lastMonthStart, lastMonthEnd)), 0);
      expect(income(range(thisMonthStart, today)), 250);
      expect(income(const ReportFilters()), 250);

      await moveTo(earlierLastMonth);
      expect(income(range(lastMonthStart, lastMonthEnd)), 250);
      expect(income(range(thisMonthStart, today)), 0);
      expect(income(const ReportFilters()), 250);

      // Hacia el futuro: sale de todos los periodos actuales (no queda huérfana
      // en el viejo) y vuelve a contar cuando la fecha llega.
      await moveTo(nextWeek);
      expect(income(range(lastMonthStart, lastMonthEnd)), 0);
      expect(income(const ReportFilters()), 0);
      expect(container.read(saleProvider).sales, hasLength(1));

      // El stock no se toca por cambiar solo la fecha.
      final product = await db.select(db.products).getSingle();
      expect(product.stock, 99);
    });

    test('editing a purchase date moves it between periods', () async {
      await spend(lastMonth, amount: 60);
      await refresh();
      final id = container.read(purchaseProvider).purchases.single.id;
      expect(expenses(range(lastMonthStart, lastMonthEnd)), 60);

      await container.read(purchaseProvider.notifier).editPurchase(
        purchaseId: id,
        supplierId: null,
        locationId: null,
        eventId: null,
        isMaterial: false,
        description: 'Gasto',
        totalAmount: 60,
        date: today,
        newItems: const [],
      );
      await refresh();
      expect(expenses(range(lastMonthStart, lastMonthEnd)), 0);
      expect(expenses(range(thisMonthStart, today)), 60);
    });
  });

  group('Cancelaciones (item 6)', () {
    test('canceling a past-dated sale removes it from ITS period, not from today', () async {
      await sell(today, amount: 100);
      await sell(lastMonth, amount: 250);
      await refresh();
      final past = container.read(saleProvider).sales.firstWhere((s) => s.finalAmount == 250);

      expect(await container.read(saleProvider.notifier).cancelSale(past.id), isNull);
      await refresh();

      expect(income(range(lastMonthStart, lastMonthEnd)), 0);
      expect(salesCount(range(lastMonthStart, lastMonthEnd)), 0);
      // El periodo de hoy no cambia.
      expect(income(range(thisMonthStart, today)), 100);
      expect(income(const ReportFilters()), 100);
      // La venta conserva su fecha original (no se reescribe a la de hoy).
      final stored = container.read(saleProvider).sales.firstWhere((s) => s.id == past.id);
      expect(stored.isCanceled, isTrue);
      expect(stored.date, lastMonth);
      // Stock devuelto: 100 - 2 vendidas + 1 devuelta.
      expect((await db.select(db.products).getSingle()).stock, 99);
    });

    test('canceling a material usage has no date and only returns stock', () async {
      final matId = await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Tela',
          unitId: 1,
          stock: const Value(10),
          pricePerUnit: 5,
        ),
      );
      await spend(lastMonth, amount: 60);
      await refresh();
      final repo = MaterialRepository(db);
      expect(await repo.registerMaterialUsage(productId: 1, materialId: matId, quantityUsed: 4), isNull);
      final record = (await db.select(db.productMaterials).get()).single;
      expect((await db.select(db.materials).getSingle()).stock, 6);

      expect(await repo.cancelMaterialUsage(record.id), isNull);
      expect((await db.select(db.materials).getSingle()).stock, 10);
      // Ningún total por periodo cambia: el uso de material no es un monto.
      expect(expenses(range(lastMonthStart, lastMonthEnd)), 60);
      expect(expenses(range(thisMonthStart, today)), 0);
    });
  });

  group('Eventos (item 7)', () {
    test('linked amounts use the sale/purchase date, not the event date', () async {
      // Evento de 3 días, hace ~3 semanas.
      final evStart = DateTime(now.year, now.month, now.day - 21);
      final evEnd = DateTime(now.year, now.month, now.day - 19);
      final eventId = await newEvent('Feria', evStart, evEnd);
      final evMid = DateTime(evStart.year, evStart.month, evStart.day + 1, 12);

      await sell(DateTime(evStart.year, evStart.month, evStart.day, 10), amount: 10, eventId: eventId);
      await sell(evMid, amount: 20, eventId: eventId);
      // Venta ligada al evento pero registrada DESPUÉS de que terminó.
      await sell(today, amount: 40, eventId: eventId);
      // Venta sin evento el día medio del evento.
      await sell(evMid, amount: 80);
      await spend(evMid, amount: 5, eventId: eventId);
      await spend(today, amount: 7, eventId: eventId);
      await refresh();

      ReportFilters ev([DateTime? from, DateTime? to]) => ReportFilters(
        eventId: eventId,
        startDate: from,
        endDate: to,
      );

      // Solo evento: todas las ligadas (ya ocurridas).
      expect(income(ev()), 70);
      expect(expenses(ev()), 12);
      // Evento + el día medio: solo la venta de ESE día.
      final midDay = DateTime(evMid.year, evMid.month, evMid.day);
      expect(income(ev(midDay)), 20);
      expect(expenses(ev(midDay)), 5);
      // Evento + todo el rango del evento: 10 + 20 (la de hoy queda fuera aunque
      // esté ligada al evento).
      expect(income(ev(evStart, evEnd)), 30);
      // Evento + hoy: solo la venta de hoy.
      expect(income(ev(DateTime(today.year, today.month, today.day))), 40);
      expect(expenses(ev(DateTime(today.year, today.month, today.day))), 7);
      // Rango del evento SIN filtrar por evento: incluye la venta sin evento.
      expect(income(range(evStart, evEnd)), 110);
    });

    test('a sale linked to an event but dated in the future is not counted', () async {
      final eventId = await newEvent('Feria futura', nextWeek, null);
      await sell(nextWeek, amount: 300, eventId: eventId);
      await refresh();
      expect(income(ReportFilters(eventId: eventId)), 0);
      expect(income(const ReportFilters()), 0);
    });
  });

  group('Compras de material con fecha pasada (item 9)', () {
    Future<void> buyMaterial(int matId, DateTime date, double unitPrice) =>
        container.read(purchaseProvider.notifier).createPurchase(
          supplierId: null,
          locationId: null,
          eventId: null,
          isMaterial: true,
          description: null,
          totalAmount: unitPrice * 2,
          date: date,
          items: [
            {'materialId': matId, 'quantity': 2.0, 'unitPrice': unitPrice},
          ],
        );

    test('a backdated purchase does not overwrite the price set by a later one', () async {
      final matId = await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Hilo',
          unitId: 1,
          stock: const Value(0),
          pricePerUnit: 1,
        ),
      );
      await buyMaterial(matId, today, 10); // vigente
      await buyMaterial(matId, lastMonth, 3); // anotada tarde, más antigua
      var mat = await db.select(db.materials).getSingle();
      expect(mat.pricePerUnit, 10);
      expect(mat.stock, 4); // el stock sí se suma
      await buyMaterial(matId, DateTime.now().add(const Duration(minutes: 1)), 12);
      mat = await db.select(db.materials).getSingle();
      expect(mat.pricePerUnit, 12); // una compra más reciente sí actualiza
    });
  });

  group('Exportaciones (item 8)', () {
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
        final summary = container.read(salesSummaryProvider(f));
        final purchases = container.read(filteredPurchasesProvider(f));
        final purchaseRows = container.read(purchaseReportRowsProvider(purchases));
        final pSummary = container.read(purchasesSummaryProvider(purchases));
        expect(summary.totalAmount, wantIncome);
        expect(pSummary.totalAmount, wantExpense);

        final repo = container.read(reportExportRepositoryProvider);
        fakeShare.calls.clear();

        // Excel de ventas: la suma de la columna Total == Ingresos en pantalla.
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

        // PDF de ventas: el resumen impreso es el mismo.
        await repo.exportSalesPdf(title: 'Ventas', rows: saleRows, summary: summary);
        var pdf = PdfText.extract(await File(fakeShare.calls.last.single.path).readAsBytes());
        expect(pdf.text, contains('Ingresos: Bs. ${wantIncome.toStringAsFixed(2)}'));
        expect(pdf.text, contains('Total ventas: ${summary.count}'));

        // Compras: Excel y PDF.
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

      await check(const ReportFilters(), 350, 100); // futuros fuera
      await check(range(lastMonthStart, lastMonthEnd), 250, 60);
      await check(range(thisMonthStart, today), 100, 40);
      await check(range(today), 100, 40); // solo "Desde": un día
    });
  });
}
