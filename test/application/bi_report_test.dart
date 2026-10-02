import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/bi_provider.dart';
import 'package:offline_first_bi/application/category_provider.dart';
import 'package:offline_first_bi/application/client_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/event_provider.dart';
import 'package:offline_first_bi/application/location_provider.dart';
import 'package:offline_first_bi/application/material_provider.dart';
import 'package:offline_first_bi/application/product_provider.dart';
import 'package:offline_first_bi/application/purchase_provider.dart';
import 'package:offline_first_bi/application/report_provider.dart';
import 'package:offline_first_bi/application/sale_provider.dart';
import 'package:offline_first_bi/application/supplier_provider.dart';
import 'package:offline_first_bi/application/unit_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/bi_models.dart';
import 'package:offline_first_bi/models/purchase_kind.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/pages/business_intelligence_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// Business Intelligence: cada indicador sobre una base Drift real en memoria y
// los providers reales, con ventas y compras de distintas fechas, una venta
// cancelada y registros con fecha futura.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();
  DateTime day(int offset, [int hour = 12]) =>
      DateTime(now.year, now.month, now.day + offset, hour);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
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
    await container.read(materialProvider.notifier).load();
    await container.read(unitProvider.notifier).load();
    container.listen(saleItemsMapProvider, (_, _) {});
    container.invalidate(saleItemsMapProvider);
    await container.read(saleItemsMapProvider.future);
    container.listen(purchaseItemsMapProvider, (_, _) {});
    container.invalidate(purchaseItemsMapProvider);
    await container.read(purchaseItemsMapProvider.future);
  }

  Future<int> newCategory(String name) async {
    await container.read(categoryProvider.notifier).save(name: name);
    return container
        .read(categoryProvider)
        .categories
        .firstWhere((c) => c.name == name)
        .id;
  }

  Future<int> newProduct(
    String name, {
    int? categoryId,
    int stock = 100,
    bool isActive = true,
  }) async {
    await container
        .read(productProvider.notifier)
        .save(
          categoryId: categoryId,
          name: name,
          priceA: 10,
          priceB: 8,
          stock: stock,
          isActive: isActive,
        );
    return container
        .read(productProvider)
        .products
        .firstWhere((p) => p.name == name)
        .id;
  }

  Future<int> newEvent(String name, DateTime start, DateTime? end) async {
    await container
        .read(eventProvider.notifier)
        .save(name: name, startDate: start, endDate: end);
    return container
        .read(eventProvider)
        .events
        .firstWhere((e) => e.name == name)
        .id;
  }

  Future<int> newMaterial(String name) async {
    await container.read(unitProvider.notifier).load();
    final unit = container.read(unitProvider).units.first;
    await container
        .read(materialProvider.notifier)
        .save(name: name, unitId: unit.id, stock: 0, pricePerUnit: 1);
    return container
        .read(materialProvider)
        .materials
        .firstWhere((m) => m.name == name)
        .id;
  }

  // Una venta de una sola línea: [qty] unidades de [productId] a [price].
  Future<void> sell(
    DateTime date,
    int productId,
    int qty,
    double price, {
    String priceType = 'A',
    int? eventId,
    double discount = 0,
  }) async {
    final subtotal = qty * price;
    final error = await container
        .read(saleProvider.notifier)
        .createSale(
          clientId: null,
          locationId: null,
          eventId: eventId,
          totalAmount: subtotal,
          discount: discount,
          finalAmount: subtotal - discount,
          date: date,
          items: [
            {
              'productId': productId,
              'quantity': qty,
              'unitPrice': price,
              'priceType': priceType,
            },
          ],
        );
    expect(error, isNull);
  }

  Future<void> buyMaterial(
    DateTime date,
    int materialId,
    double qty,
    double price, {
    int? eventId,
  }) async {
    final error = await container
        .read(purchaseProvider.notifier)
        .createPurchase(
          supplierId: null,
          locationId: null,
          eventId: eventId,
          isMaterial: true,
          description: null,
          totalAmount: qty * price,
          date: date,
          items: [
            {'materialId': materialId, 'quantity': qty, 'unitPrice': price},
          ],
        );
    expect(error, isNull);
  }

  Future<void> spend(DateTime date, double amount, {int? eventId}) async {
    final error = await container
        .read(purchaseProvider.notifier)
        .createPurchase(
          supplierId: null,
          locationId: null,
          eventId: eventId,
          isMaterial: false,
          description: 'Gasto',
          totalAmount: amount,
          date: date,
          items: const [],
        );
    expect(error, isNull);
  }

  BiReport report([ReportFilters filters = const ReportFilters()]) =>
      container.read(biReportProvider(filters));

  Map<String, double> amounts(List<BiEntry> entries) => {
    for (final e in entries) e.label: e.amount,
  };

  group('chart palette', () {
    test('exactly five chart colors, derived from the primary hue family', () {
      final colors = [
        AppColors.chartColor1,
        AppColors.chartColor2,
        AppColors.chartColor3,
        AppColors.chartColor4,
        AppColors.chartColor5,
      ];
      expect(colors.toSet().length, 5);
      expect(AppColors.chartColor1, AppColors.primary);
      expect(AppColors.chartColor2, AppColors.primaryDark);
      // Todos en la familia verde / verde azulado / cian (HSL 140°–195°).
      for (final c in colors) {
        final hue = HSLColor.fromColor(c).hue;
        expect(hue, inInclusiveRange(140, 195), reason: '$c');
      }
    });

    test('chartColorAt cycles through the same five colors in order', () {
      final first = [for (var i = 0; i < 5; i++) chartColorAt(i)];
      for (var i = 0; i < 20; i++) {
        expect(chartColorAt(i), first[i % 5], reason: 'index $i');
      }
      expect(chartColorAt(5), AppColors.chartColor1);
      expect(chartColorAt(6), AppColors.chartColor2);
      expect(chartColorAt(9), AppColors.chartColor5);
      expect(chartColorAt(10), AppColors.chartColor1);
    });
  });

  group('indicators', () {
    test('summary excludes canceled and future-dated records', () async {
      final p = await newProduct('Cuadro');
      await sell(day(0), p, 2, 100); // 200
      await sell(day(-5), p, 1, 50); // 50
      await sell(day(3), p, 1, 999); // futura: no cuenta
      await sell(day(-1), p, 1, 777); // se cancela
      await spend(day(-2), 30);
      await spend(day(4), 888); // futura: no cuenta
      await refresh();
      final canceled = container
          .read(saleProvider)
          .sales
          .firstWhere((s) => s.totalAmount == 777);
      await container.read(saleProvider.notifier).cancelSale(canceled.id);
      await refresh();

      final summary = report().summary;
      expect(summary.ingresos, 250);
      expect(summary.gastos, 30);
      expect(summary.balance, 220);
    });

    test('summary uses the net amount after discounts', () async {
      final p = await newProduct('Cuadro');
      await sell(day(0), p, 2, 100, discount: 20);
      await refresh();
      expect(report().summary.ingresos, 180);
    });

    test('sales by product ranks by revenue with units', () async {
      final a = await newProduct('Cuadro');
      final b = await newProduct('Taza');
      await sell(day(0), a, 1, 300);
      await sell(day(-1), b, 5, 20);
      await sell(day(-2), b, 3, 20);
      await sell(day(2), a, 10, 1000); // futura
      await refresh();

      final entries = report().salesByProduct;
      expect(entries.map((e) => e.label), ['Cuadro', 'Taza']);
      expect(entries[0].amount, 300);
      expect(entries[0].quantity, 1);
      expect(entries[1].amount, 160);
      expect(entries[1].quantity, 8);
    });

    test('sales by category treats "Sin categoría" as a normal category', () async {
      final pinturas = await newCategory('Pinturas');
      final a = await newProduct('Cuadro', categoryId: pinturas);
      final b = await newProduct('Llavero'); // sin categoría
      await sell(day(0), a, 1, 100);
      await sell(day(0), b, 4, 10);
      await refresh();

      expect(amounts(report().salesByCategory), {
        'Pinturas': 100,
        'Sin categoría': 40,
      });
    });

    test('sales by price type splits A and B in A, B order', () async {
      final p = await newProduct('Cuadro');
      await sell(day(0), p, 1, 100, priceType: 'B');
      await sell(day(0), p, 2, 50, priceType: 'A');
      await sell(day(-1), p, 1, 25, priceType: 'A');
      await refresh();

      final entries = report().salesByPriceType;
      expect(entries.map((e) => e.label), ['Precio A', 'Precio B']);
      expect(entries[0].amount, 125);
      expect(entries[1].amount, 100);
    });

    test('price type filter leaves only that type', () async {
      final p = await newProduct('Cuadro');
      await sell(day(0), p, 1, 100, priceType: 'B');
      await sell(day(0), p, 2, 50, priceType: 'A');
      await refresh();

      final r = report(const ReportFilters(priceType: 'B'));
      expect(r.summary.ingresos, 100);
      expect(r.salesByPriceType.map((e) => e.label), ['Precio B']);
    });

    test('sales by event use each sale\'s own date, not the event\'s', () async {
      final p = await newProduct('Cuadro');
      // El evento duró hace un mes, pero las ventas tienen fechas propias.
      final feria = await newEvent('Feria', day(-40), day(-38));
      final bazar = await newEvent('Bazar', day(-1), null);
      await sell(day(-3), p, 1, 100, eventId: feria);
      await sell(day(-60), p, 1, 500, eventId: feria); // fuera del periodo
      await sell(day(0), p, 2, 40, eventId: bazar);
      await sell(day(0), p, 1, 10); // sin evento
      await sell(day(5), p, 1, 999, eventId: bazar); // futura
      await refresh();

      final range = ReportFilters(startDate: day(-10), endDate: day(0));
      final entries = report(range).salesByEvent;
      expect(amounts(entries), {'Feria': 100, 'Bazar': 80});
      expect(entries.first.label, 'Feria');
      // Sin filtro de fechas entra la venta antigua del evento.
      expect(amounts(report().salesByEvent), {'Feria': 600, 'Bazar': 80});
    });

    test('purchases by material add up item spending, expenses excluded', () async {
      final tela = await newMaterial('Tela');
      final hilo = await newMaterial('Hilo');
      await buyMaterial(day(0), tela, 3, 20); // 60
      await buyMaterial(day(-2), tela, 2, 20); // 40
      await buyMaterial(day(-1), hilo, 1, 15); // 15
      await buyMaterial(day(6), hilo, 100, 100); // futura
      await spend(day(0), 500); // gasto general: sin material
      await refresh();

      final entries = report().purchasesByMaterial;
      expect(entries.map((e) => e.label), ['Tela', 'Hilo']);
      expect(entries[0].amount, 100);
      expect(entries[0].quantity, 5);
      expect(entries[0].unit, isNotNull);
      expect(entries[1].amount, 15);
      // El gasto sí cuenta en el resumen.
      expect(report().summary.gastos, 615);
    });

    test('purchase kind filter only touches purchases', () async {
      final p = await newProduct('Cuadro');
      final tela = await newMaterial('Tela');
      await sell(day(0), p, 1, 100);
      await buyMaterial(day(0), tela, 1, 40);
      await spend(day(0), 25);
      await refresh();

      final onlyExpenses = report(
        const ReportFilters(purchaseKind: PurchaseKind.expense),
      );
      expect(onlyExpenses.summary.gastos, 25);
      expect(onlyExpenses.summary.ingresos, 100);
      expect(onlyExpenses.purchasesByMaterial, isEmpty);

      final onlyMaterials = report(
        const ReportFilters(purchaseKind: PurchaseKind.material),
      );
      expect(onlyMaterials.summary.gastos, 40);
    });

    test('low stock lists active products at or below the threshold, ignoring filters', () async {
      await newProduct('Agotado', stock: 0);
      await newProduct('Poco', stock: 2);
      await newProduct('Justo', stock: 3);
      await newProduct('Suficiente', stock: 4);
      await newProduct('Inactivo', stock: 1, isActive: false);
      await refresh();

      // Un rango sin ningún registro no cambia el stock bajo.
      final empty = report(
        ReportFilters(startDate: day(-400), endDate: day(-399)),
      );
      expect(empty.lowStock.map((e) => e.product.name), [
        'Agotado',
        'Poco',
        'Justo',
      ]);
      expect(empty.lowStock.first.isOutOfStock, isTrue);
      expect(empty.lowStock.last.categoryName, 'Sin categoría');
      expect(
        report(const ReportFilters(priceType: 'B')).lowStock.length,
        3,
      );
    });

    test('date range and Desde-only single day apply to every indicator', () async {
      final p = await newProduct('Cuadro');
      final tela = await newMaterial('Tela');
      await sell(day(0), p, 1, 100);
      await sell(day(-1), p, 1, 40);
      await buyMaterial(day(0), tela, 1, 10);
      await buyMaterial(day(-1), tela, 1, 20);
      await refresh();

      final single = report(ReportFilters(startDate: day(-1)));
      expect(single.summary.ingresos, 40);
      expect(single.summary.gastos, 20);
      expect(single.salesByProduct.single.amount, 40);
      expect(single.purchasesByMaterial.single.amount, 20);
      expect(single.timeSeries.buckets.length, 1);
    });
  });

  group('time series', () {
    test('short range is daily and fills empty days with zeros', () async {
      final p = await newProduct('Cuadro');
      await sell(day(0), p, 1, 100);
      await sell(day(-4), p, 1, 40);
      await spend(day(-2), 30);
      await refresh();

      final series = report().timeSeries;
      expect(series.granularity, BiGranularity.day);
      expect(series.buckets.length, 5);
      expect(series.buckets.map((b) => b.ingresos), [40, 0, 0, 0, 100]);
      expect(series.buckets.map((b) => b.gastos), [0, 0, 30, 0, 0]);
    });

    test('a long range is bucketed monthly, a medium one weekly', () async {
      final p = await newProduct('Cuadro');
      await sell(day(0), p, 1, 100);
      await sell(day(-200), p, 1, 40);
      await refresh();

      final long = report().timeSeries;
      expect(long.granularity, BiGranularity.month);
      expect(
        long.buckets.fold<double>(0, (s, b) => s + b.ingresos),
        140,
      );
      // Meses consecutivos, sin huecos.
      for (var i = 1; i < long.buckets.length; i++) {
        final prev = long.buckets[i - 1].start;
        expect(
          long.buckets[i].start,
          DateTime(prev.year, prev.month + 1),
        );
      }

      final medium = report(
        ReportFilters(startDate: day(-60), endDate: day(0)),
      ).timeSeries;
      expect(medium.granularity, BiGranularity.week);
      expect(
        medium.buckets.every((b) => b.start.weekday == DateTime.monday),
        isTrue,
      );
    });

    test('future-dated records never appear in the series', () async {
      final p = await newProduct('Cuadro');
      await sell(day(0), p, 1, 100);
      await sell(day(10), p, 1, 999);
      await refresh();

      final series = report().timeSeries;
      expect(series.buckets.length, 1);
      expect(series.buckets.single.ingresos, 100);
    });

    test('no data gives an empty series', () async {
      await refresh();
      expect(report().timeSeries.isEmpty, isTrue);
    });
  });

  group('screen', () {
    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: lightTheme,
            home: const BusinessIntelligencePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the eight indicators with their data', (tester) async {
      final pinturas = await newCategory('Pinturas');
      final a = await newProduct('Cuadro', categoryId: pinturas);
      await newProduct('Lienzo', stock: 0);
      final tela = await newMaterial('Tela');
      final feria = await newEvent('Feria', day(-2), null);
      await sell(day(0), a, 1, 100, eventId: feria);
      await buyMaterial(day(-1), tela, 2, 10);
      await refresh();

      await pumpPage(tester);

      expect(find.text('Business Intelligence'), findsOneWidget);
      expect(find.text('Próximamente'), findsNothing);
      for (final title in [
        'Ventas por producto',
        'Ventas por categoría',
        'Compras por material',
        'Ventas por tipo de precio',
        'Evolución en el tiempo',
        'Ventas por evento',
        'Productos con bajo stock',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('Bs. 100.00'), findsWidgets); // ingresos
      expect(find.text('Bs. 20.00'), findsWidgets); // gastos
      expect(find.text('Bs. 80.00'), findsOneWidget); // balance
      expect(find.text('Agotado'), findsOneWidget);
      expect(find.text('Feria'), findsOneWidget);
    });

    testWidgets('bars cycle through the five palette colors past the fifth', (
      tester,
    ) async {
      // 7 categorías con ventas: las barras 6 y 7 reutilizan los colores 1 y 2.
      for (var i = 0; i < 7; i++) {
        final cat = await newCategory('Cat $i');
        final p = await newProduct('Prod $i', categoryId: cat);
        await sell(day(0), p, 1, 100.0 - i * 10);
      }
      await refresh();
      await pumpPage(tester);

      Color barColor(int i) {
        final box = tester.widget<Container>(
          find.byKey(ValueKey('bi-bar-$i')).first,
        );
        return box.color!;
      }

      final expected = [
        AppColors.chartColor1,
        AppColors.chartColor2,
        AppColors.chartColor3,
        AppColors.chartColor4,
        AppColors.chartColor5,
        AppColors.chartColor1,
        AppColors.chartColor2,
      ];
      for (var i = 0; i < 7; i++) {
        expect(barColor(i), expected[i], reason: 'bar $i');
      }
    });

    testWidgets('filters and presets reuse the Reportes components', (
      tester,
    ) async {
      final p = await newProduct('Cuadro');
      await sell(day(0), p, 1, 100);
      await sell(day(-40), p, 1, 500);
      await refresh();
      await pumpPage(tester);

      expect(find.text('Bs. 600.00'), findsWidgets); // todo el historial

      for (final preset in ['Hoy', 'Esta semana', 'Este mes', 'Este año']) {
        expect(find.text(preset), findsOneWidget);
      }
      for (final chip in [
        'Categoría',
        'Producto',
        'Tipo de precio',
        'Tipo de operación',
        'Evento',
        'Ubicación',
      ]) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
      expect(find.text('Cliente'), findsNothing);
      expect(find.text('Proveedor'), findsNothing);

      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      expect(find.text('Bs. 100.00'), findsWidgets);
      expect(find.text('Bs. 600.00'), findsNothing);

      // Tocar otra vez el atajo quita el filtro.
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      expect(find.text('Bs. 600.00'), findsWidgets);
    });
  });
}
