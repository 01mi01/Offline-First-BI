import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/models/bi_models.dart';
import 'package:offline_first_bi/models/purchase_kind.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/pages/business_intelligence_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import '../support/bi_harness.dart';

// Business Intelligence: cada indicador sobre una base Drift real en memoria y
// los providers reales, con ventas y compras de distintas fechas, una venta
// cancelada y registros con fecha futura.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = BiHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  // Atajos a los ayudantes del arnés.
  DateTime day(int offset, [int hour = 12]) => h.day(offset, hour);
  final refresh = h.refresh;
  final newCategory = h.newCategory;
  final newProduct = h.newProduct;
  final newEvent = h.newEvent;
  final newMaterial = h.newMaterial;
  final sell = h.sell;
  final buyMaterial = h.buyMaterial;
  final spend = h.spend;
  BiReport report([ReportFilters filters = const ReportFilters()]) =>
      h.report(filters);
  Map<String, double> amounts(List<BiEntry> entries) => {
    for (final e in entries) e.label: e.amount,
  };

  group('chart palette', () {
    test('exactly five chart colors, each in its palette family', () {
      final colors = [
        AppColors.chartColor1,
        AppColors.chartColor2,
        AppColors.chartColor3,
        AppColors.chartColor4,
        AppColors.chartColor5,
      ];
      expect(colors.toSet().length, 5);
      expect(AppColors.chartColor1, AppColors.cyan);
      expect(AppColors.chartColor4, AppColors.cyanDark);
      // Cada color pertenece a su familia de la paleta: cian, azul marino,
      // verde lima, cian oscuro y azul.
      const hueRanges = [
        (170.0, 195.0), // chartColor1: cian
        (205.0, 235.0), // chartColor2: azul marino
        (60.0, 90.0), // chartColor3: verde lima
        (170.0, 195.0), // chartColor4: cian oscuro
        (195.0, 215.0), // chartColor5: azul
      ];
      for (var i = 0; i < colors.length; i++) {
        final hue = HSLColor.fromColor(colors[i]).hue;
        expect(
          hue,
          inInclusiveRange(hueRanges[i].$1, hueRanges[i].$2),
          reason: 'chartColor${i + 1}: ${colors[i]}',
        );
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
      final p = await newProduct('Tote bag negra');
      await sell(day(0), p, 2, 100); // 200
      await sell(day(-5), p, 1, 50); // 50
      await sell(day(3), p, 1, 999); // futura: no cuenta
      await sell(day(-1), p, 1, 777); // se cancela
      await spend(day(-2), 30);
      await spend(day(4), 888); // futura: no cuenta
      await h.cancelSaleOf(777);
      await refresh();

      final summary = report().summary;
      expect(summary.ingresos, 250);
      expect(summary.gastos, 30);
      expect(summary.balance, 220);
    });

    test('summary uses the net amount after discounts', () async {
      final p = await newProduct('Tote bag negra');
      await sell(day(0), p, 2, 100, discount: 20);
      await refresh();
      expect(report().summary.ingresos, 180);
    });

    test('sales by product ranks by revenue with units', () async {
      final a = await newProduct('Tote bag negra');
      final b = await newProduct('Stickers holográficos');
      await sell(day(0), a, 1, 300);
      await sell(day(-1), b, 5, 20);
      await sell(day(-2), b, 3, 20);
      await sell(day(2), a, 10, 1000); // futura
      await refresh();

      final entries = report().salesByProduct;
      expect(entries.map((e) => e.label), ['Tote bag negra', 'Stickers holográficos']);
      expect(entries[0].amount, 300);
      expect(entries[0].quantity, 1);
      expect(entries[1].amount, 160);
      expect(entries[1].quantity, 8);
    });

    test('sales by category treats "Sin categoría" as a normal category', () async {
      final miniaturas = await newCategory('Miniaturas');
      final a = await newProduct('Tote bag negra', categoryId: miniaturas);
      final b = await newProduct('Pines grandes'); // sin categoría
      await sell(day(0), a, 1, 100);
      await sell(day(0), b, 4, 10);
      await refresh();

      expect(amounts(report().salesByCategory), {
        'Miniaturas': 100,
        'Sin categoría': 40,
      });
    });

    test('sales by price type splits A and B in A, B order', () async {
      final p = await newProduct('Tote bag negra');
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
      final p = await newProduct('Tote bag negra');
      await sell(day(0), p, 1, 100, priceType: 'B');
      await sell(day(0), p, 2, 50, priceType: 'A');
      await refresh();

      final r = report(const ReportFilters(priceType: 'B'));
      expect(r.summary.ingresos, 100);
      expect(r.salesByPriceType.map((e) => e.label), ['Precio B']);
    });

    test('sales by event use each sale\'s own date, not the event\'s', () async {
      final p = await newProduct('Tote bag negra');
      // El evento duró hace un mes, pero las ventas tienen fechas propias.
      final feria = await newEvent('Feria de Arte', day(-40), day(-38));
      final octubre = await newEvent('Feria de Octubre', day(-1), null);
      await sell(day(-3), p, 1, 100, eventId: feria);
      await sell(day(-60), p, 1, 500, eventId: feria); // fuera del periodo
      await sell(day(0), p, 2, 40, eventId: octubre);
      await sell(day(0), p, 1, 10); // sin evento
      await sell(day(5), p, 1, 999, eventId: octubre); // futura
      await refresh();

      final range = ReportFilters(startDate: day(-10), endDate: day(0));
      final entries = report(range).salesByEvent;
      expect(amounts(entries), {'Feria de Arte': 100, 'Feria de Octubre': 80});
      expect(entries.first.label, 'Feria de Arte');
      // Sin filtro de fechas entra la venta antigua del evento.
      expect(amounts(report().salesByEvent), {'Feria de Arte': 600, 'Feria de Octubre': 80});
    });

    test('purchases by material add up item spending, expenses excluded', () async {
      final tela = await newMaterial('Tela negra');
      final resinaA = await newMaterial('Resina parte A');
      await buyMaterial(day(0), tela, 3, 20); // 60
      await buyMaterial(day(-2), tela, 2, 20); // 40
      await buyMaterial(day(-1), resinaA, 1, 15); // 15
      await buyMaterial(day(6), resinaA, 100, 100); // futura
      await spend(day(0), 500); // gasto general: sin material
      await refresh();

      final entries = report().purchasesByMaterial;
      expect(entries.map((e) => e.label), ['Tela negra', 'Resina parte A']);
      expect(entries[0].amount, 100);
      expect(entries[0].quantity, 5);
      expect(entries[0].unit, isNotNull);
      expect(entries[1].amount, 15);
      // El gasto sí cuenta en el resumen.
      expect(report().summary.gastos, 615);
    });

    test('purchase kind filter only touches purchases', () async {
      final p = await newProduct('Tote bag negra');
      final tela = await newMaterial('Tela negra');
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
      await newProduct('Estuches', stock: 0);
      await newProduct('Libro', stock: 2);
      await newProduct('Miniaturas', stock: 3);
      await newProduct('Pines grandes', stock: 4);
      await newProduct('Tote bag beige', stock: 1, isActive: false);
      await refresh();

      // Un rango sin ningún registro no cambia el stock bajo.
      final empty = report(
        ReportFilters(startDate: day(-400), endDate: day(-399)),
      );
      expect(empty.lowStock.map((e) => e.product.name), [
        'Estuches',
        'Libro',
        'Miniaturas',
      ]);
      expect(empty.lowStock.first.isOutOfStock, isTrue);
      expect(empty.lowStock.last.categoryName, 'Sin categoría');
      expect(
        report(const ReportFilters(priceType: 'B')).lowStock.length,
        3,
      );
    });

    test('date range and Desde-only single day apply to every indicator', () async {
      final p = await newProduct('Tote bag negra');
      final tela = await newMaterial('Tela negra');
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
      final p = await newProduct('Tote bag negra');
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
      final p = await newProduct('Tote bag negra');
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
      final p = await newProduct('Tote bag negra');
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
    Future<void> pumpPage(WidgetTester tester, {bool confirm = true}) async {
      tester.view.physicalSize = const Size(900, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            theme: lightTheme,
            home: const BusinessIntelligencePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Primero se muestra la configuración; al confirmarla, el panel.
      if (confirm) {
        // El botón va al final del contenido que se desplaza.
        await tester.ensureVisible(find.byKey(const ValueKey('bi-config-confirm')));
        await tester.tap(find.byKey(const ValueKey('bi-config-confirm')));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('shows the indicators with their data', (tester) async {
      final miniaturas = await newCategory('Miniaturas');
      final a = await newProduct('Tote bag negra', categoryId: miniaturas);
      await newProduct('Set de pines pequeños', stock: 0);
      final tela = await newMaterial('Tela negra');
      final feria = await newEvent('Feria de Arte', day(-2), null);
      await sell(day(0), a, 1, 100, eventId: feria);
      await buyMaterial(day(-1), tela, 2, 10);
      await refresh();

      await pumpPage(tester);

      expect(find.text('Business Intelligence'), findsOneWidget);
      expect(find.text('Próximamente'), findsNothing);
      // Los predeterminados de la configuración.
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
      expect(find.text('Feria de Arte'), findsOneWidget);
    });

    testWidgets('bars cycle through the five palette colors past the fifth', (
      tester,
    ) async {
      // 7 categorías con ventas: las barras 6 y 7 reutilizan los colores 1 y 2.
      for (var i = 0; i < 7; i++) {
        final cat = await newCategory('Categoría $i');
        final p = await newProduct('Producto $i', categoryId: cat);
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

    testWidgets('the configuration step reuses the Reportes filters and presets', (
      tester,
    ) async {
      final p = await newProduct('Tote bag negra');
      await sell(day(0), p, 1, 100);
      await sell(day(-40), p, 1, 500);
      await refresh();
      await pumpPage(tester, confirm: false);

      // Nada de datos hasta confirmar la configuración.
      expect(find.byKey(const ValueKey('bi-section-salesByProduct')), findsNothing);
      expect(find.byKey(const ValueKey('bi-period')), findsNothing);
      expect(find.text('Bs. 600.00'), findsNothing);

      for (final preset in ['Hoy', 'Esta semana', 'Este mes', 'Este año']) {
        expect(find.text(preset), findsOneWidget);
      }
      for (final chip in [
        'Todas las categorías',
        'Producto',
        'Tipo de precio',
        'Tipo de operación',
        'Evento',
        'Ubicación',
        'Todos los países',
        'Todas las ciudades',
      ]) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
      expect(find.text('Cliente'), findsNothing);
      expect(find.text('Proveedor'), findsNothing);

      // Con "Hoy" solo cuenta la venta de hoy.
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      // El botón va al final del contenido que se desplaza.
      await tester.ensureVisible(find.byKey(const ValueKey('bi-config-confirm')));
      await tester.tap(find.byKey(const ValueKey('bi-config-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Bs. 100.00'), findsWidgets);
      expect(find.text('Bs. 600.00'), findsNothing);
      expect(find.byKey(const ValueKey('bi-period')), findsOneWidget);

      // Volver a configurar sin salir del módulo, y quitar el atajo.
      await tester.tap(find.byKey(const ValueKey('bi-configure')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bi-config-confirm')), findsOneWidget);
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      // El botón va al final del contenido que se desplaza.
      await tester.ensureVisible(find.byKey(const ValueKey('bi-config-confirm')));
      await tester.tap(find.byKey(const ValueKey('bi-config-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Bs. 600.00'), findsWidgets);
    });
  });
}
