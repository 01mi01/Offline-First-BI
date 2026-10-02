import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/bi_provider.dart';
import 'package:offline_first_bi/models/bi_config.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/pages/business_intelligence_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import '../support/bi_harness.dart';

// Pantalla de Business Intelligence: paso de configuración, panel con los
// indicadores elegidos, iconos de información, selector de tipo de gráfico
// (que se recuerda) y cada indicador nuevo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = BiHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  DateTime day(int offset, [int hour = 12]) => h.day(offset, hour);

  Future<void> confirmConfig(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('bi-config-confirm')));
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    bool confirm = false,
    BiConfig? config,
  }) async {
    tester.view.physicalSize = const Size(900, 30000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (config != null) {
      h.container.read(biConfigProvider.notifier).state = config;
    }
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
    if (confirm) await confirmConfig(tester);
  }

  Finder section(BiIndicator i) =>
      find.byKey(ValueKey('bi-section-${i.name}'));

  BiConfig config() => h.container.read(biConfigProvider);

  BiConfig allIndicators({ReportFilters filters = const ReportFilters()}) =>
      BiConfig(filters: filters, indicators: {...BiIndicator.values});

  bool checked(WidgetTester tester, BiIndicator i) => tester
      .widget<Checkbox>(
        find.descendant(
          of: find.byKey(ValueKey('bi-indicator-${i.name}')),
          matching: find.byType(Checkbox),
        ),
      )
      .value!;

  group('paso de configuración', () {
    testWidgets('opens first, with sensible defaults and no data shown', (tester) async {
      final p = await h.newProduct('Cuadro');
      await h.sell(day(0), p, 1, 100);
      await h.refresh();
      await pumpPage(tester);

      expect(find.byKey(const ValueKey('bi-config-confirm')), findsOneWidget);
      expect(find.byKey(const ValueKey('bi-period')), findsNothing);
      for (final i in BiIndicator.values) {
        expect(section(i), findsNothing, reason: i.name);
        expect(checked(tester, i), i.defaultSelected, reason: i.name);
      }
      final defaults = BiIndicator.values.where((i) => i.defaultSelected).length;
      expect(find.text('Ver indicadores ($defaults)'), findsOneWidget);
      // Los 8 indicadores originales vienen marcados.
      for (final i in [
        BiIndicator.summary,
        BiIndicator.salesByProduct,
        BiIndicator.salesByCategory,
        BiIndicator.purchasesByMaterial,
        BiIndicator.salesByPriceType,
        BiIndicator.timeSeries,
        BiIndicator.salesByEvent,
        BiIndicator.lowStock,
      ]) {
        expect(i.defaultSelected, isTrue, reason: i.name);
      }
    });

    testWidgets('lists all fifteen indicators and every one has an info icon', (tester) async {
      await h.refresh();
      await pumpPage(tester);
      expect(BiIndicator.values.length, 15);
      for (final i in BiIndicator.values) {
        expect(find.byKey(ValueKey('bi-indicator-${i.name}')), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('bi-config-info-${i.name}')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget, reason: i.name);
        expect(find.textContaining('Para qué sirve'), findsWidgets);
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Todos / Ninguno and the confirm button', (tester) async {
      await h.refresh();
      await pumpPage(tester);

      await tester.tap(find.byKey(const ValueKey('bi-select-none')));
      await tester.pumpAndSettle();
      expect(config().indicators, isEmpty);
      expect(find.text('Elige al menos un indicador'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('bi-config-confirm')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('bi-select-all')));
      await tester.pumpAndSettle();
      expect(config().indicators.length, 15);
      expect(find.text('Ver indicadores (15)'), findsOneWidget);
    });

    testWidgets('only the chosen indicators are shown after confirming', (tester) async {
      final p = await h.newProduct('Cuadro');
      await h.sell(day(0), p, 1, 100);
      await h.refresh();
      await pumpPage(tester);

      await tester.tap(find.byKey(const ValueKey('bi-select-none')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bi-indicator-salesByProduct')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bi-indicator-lowStock')));
      await tester.pumpAndSettle();
      expect(find.text('Ver indicadores (2)'), findsOneWidget);
      await confirmConfig(tester);

      expect(section(BiIndicator.salesByProduct), findsOneWidget);
      expect(section(BiIndicator.lowStock), findsOneWidget);
      expect(section(BiIndicator.summary), findsNothing);
      expect(section(BiIndicator.timeSeries), findsNothing);
      expect(section(BiIndicator.productRadar), findsNothing);
    });

    testWidgets('can go back to the configuration from the dashboard without leaving the module', (
      tester,
    ) async {
      final p = await h.newProduct('Cuadro');
      await h.sell(day(0), p, 1, 100);
      await h.refresh();
      await pumpPage(tester, confirm: true);
      expect(find.byKey(const ValueKey('bi-period')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bi-configure')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bi-config-confirm')), findsOneWidget);
      expect(find.byType(BusinessIntelligencePage), findsOneWidget);

      // Se conserva lo elegido: quitar un indicador y volver al panel.
      await tester.tap(find.byKey(const ValueKey('bi-indicator-summary')));
      await tester.pumpAndSettle();
      await confirmConfig(tester);
      expect(section(BiIndicator.summary), findsNothing);
      expect(section(BiIndicator.salesByProduct), findsOneWidget);
    });

    testWidgets('re-entering the module reopens the configuration with the last choices', (
      tester,
    ) async {
      await h.refresh();
      await pumpPage(
        tester,
        config: BiConfig(indicators: {BiIndicator.lowStock}),
      );
      expect(checked(tester, BiIndicator.lowStock), isTrue);
      expect(checked(tester, BiIndicator.summary), isFalse);
      expect(find.byKey(const ValueKey('bi-config-confirm')), findsOneWidget);
    });
  });

  group('iconos de información en el panel', () {
    testWidgets('every indicator card has an info icon that explains it', (tester) async {
      final p = await h.newProduct('Cuadro');
      await h.sell(day(0), p, 1, 100);
      await h.refresh();
      await pumpPage(tester, confirm: true, config: allIndicators());

      for (final i in BiIndicator.values) {
        expect(section(i), findsOneWidget, reason: i.name);
        final icon = find.descendant(
          of: section(i),
          matching: find.byKey(ValueKey('bi-info-${i.title}')),
        );
        expect(icon, findsOneWidget, reason: i.name);
        await tester.tap(icon);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget, reason: i.name);
        expect(
          find.descendant(of: find.byType(AlertDialog), matching: find.text(i.title)),
          findsOneWidget,
        );
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }
    });

    test('the explanations carry the caveats that were asked for', () {
      expect(BiIndicator.salesProjection.info, contains('estimación'));
      expect(BiIndicator.salesProjection.info, contains('no una garantía'));
      expect(BiIndicator.materialCostRatio.info, contains('aproximado'));
      expect(BiIndicator.materialCostRatio.info, contains('costo de producción'));
      expect(BiIndicator.productRadar.info, contains('Cómo leerlo'));
      expect(BiIndicator.productMargin.info, contains('rentabilidad real'));
      expect(BiIndicator.noMovement.info, contains('No depende del periodo'));
      for (final i in BiIndicator.values) {
        expect(i.info, isNotEmpty);
        expect(i.info, contains('Para qué sirve'), reason: i.name);
      }
    });
  });

  group('selector de tipo de gráfico', () {
    test('only indicators with more than one reasonable view offer a picker', () {
      expect(BiIndicator.salesByProduct.chartTypes, [BiChartType.bar, BiChartType.pie]);
      expect(BiIndicator.timeSeries.chartTypes, [BiChartType.line, BiChartType.bar]);
      expect(BiIndicator.productMargin.chartTypes, [BiChartType.bar, BiChartType.list]);
      expect(BiIndicator.lowStock.hasChartPicker, isFalse);
      expect(BiIndicator.productRadar.hasChartPicker, isFalse);
      expect(BiIndicator.salesProjection.hasChartPicker, isFalse);
      expect(BiIndicator.noMovement.hasChartPicker, isFalse);
      expect(BiIndicator.summary.hasChartPicker, isFalse);
    });

    testWidgets('ranking: bars <-> pie, remembered in the configuration', (tester) async {
      for (var i = 0; i < 3; i++) {
        final p = await h.newProduct('P$i');
        await h.sell(day(0), p, 1, 100.0 - i * 10);
      }
      await h.refresh();
      await pumpPage(tester, confirm: true);

      final byProduct = section(BiIndicator.salesByProduct);
      expect(find.descendant(of: byProduct, matching: find.byKey(const ValueKey('bi-bar-0'))), findsOneWidget);
      expect(find.descendant(of: byProduct, matching: find.byType(PieChart)), findsNothing);

      await tester.tap(find.descendant(of: byProduct, matching: find.byKey(const ValueKey('bi-chart-type-pie'))));
      await tester.pumpAndSettle();
      expect(find.descendant(of: byProduct, matching: find.byType(PieChart)), findsOneWidget);
      expect(find.descendant(of: byProduct, matching: find.byKey(const ValueKey('bi-bar-0'))), findsNothing);
      expect(config().chartTypeFor(BiIndicator.salesByProduct), BiChartType.pie);
      // Los otros indicadores conservan el suyo.
      expect(config().chartTypeFor(BiIndicator.salesByCategory), BiChartType.bar);

      // Ir a configurar y volver: sigue en pastel.
      await tester.tap(find.byKey(const ValueKey('bi-configure')));
      await tester.pumpAndSettle();
      await confirmConfig(tester);
      expect(
        find.descendant(of: section(BiIndicator.salesByProduct), matching: find.byType(PieChart)),
        findsOneWidget,
      );

      await tester.tap(find.descendant(of: section(BiIndicator.salesByProduct), matching: find.byKey(const ValueKey('bi-chart-type-bar'))));
      await tester.pumpAndSettle();
      expect(config().chartTypeFor(BiIndicator.salesByProduct), BiChartType.bar);
    });

    testWidgets('time series: line <-> bar', (tester) async {
      final p = await h.newProduct('Cuadro');
      await h.sell(day(0), p, 1, 100);
      await h.sell(day(-3), p, 1, 50);
      await h.spend(day(-2), 30);
      await h.refresh();
      await pumpPage(tester, confirm: true);

      final s = section(BiIndicator.timeSeries);
      expect(find.descendant(of: s, matching: find.byType(LineChart)), findsOneWidget);
      await tester.tap(find.descendant(of: s, matching: find.byKey(const ValueKey('bi-chart-type-bar'))));
      await tester.pumpAndSettle();
      expect(find.descendant(of: s, matching: find.byType(BarChart)), findsOneWidget);
      expect(find.descendant(of: s, matching: find.byType(LineChart)), findsNothing);
      expect(config().chartTypeFor(BiIndicator.timeSeries), BiChartType.bar);
    });

    testWidgets('margin: bars <-> sorted list, and the metric toggle', (tester) async {
      final oleo = await h.newProduct('Óleo', productionCost: 90);
      final taza = await h.newProduct('Taza', productionCost: 40);
      await h.sell(day(0), oleo, 2, 300);
      await h.sell(day(0), taza, 5, 45);
      await h.refresh();
      await pumpPage(tester, confirm: true);

      final s = section(BiIndicator.productMargin);
      expect(find.descendant(of: s, matching: find.text('Margen 70.0%')), findsOneWidget);
      await tester.tap(find.descendant(of: s, matching: find.text('Ganancia')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: s, matching: find.text('Bs. 420.00')), findsOneWidget);

      await tester.tap(find.descendant(of: s, matching: find.byKey(const ValueKey('bi-chart-type-list'))));
      await tester.pumpAndSettle();
      expect(find.descendant(of: s, matching: find.textContaining('Costo Bs. 180.00')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('70.0%')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('11.1%')), findsOneWidget);
      expect(config().chartTypeFor(BiIndicator.productMargin), BiChartType.list);
    });

    testWidgets('comparison indicators: cards <-> bars', (tester) async {
      final p = await h.newProduct('Cuadro', stock: 1000);
      await h.newEvent('Feria', day(-2), day(-1));
      await h.sell(day(-1), p, 1, 300);
      await h.sell(day(-5), p, 1, 50);
      await h.sell(day(0), p, 1, 60);
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: allIndicators(
          filters: ReportFilters(startDate: day(-5), endDate: day(0)),
        ),
      );

      for (final i in [
        BiIndicator.eventComparison,
        BiIndicator.materialCostRatio,
        BiIndicator.periodComparison,
      ]) {
        final s = section(i);
        expect(find.descendant(of: s, matching: find.byType(BarChart)), findsNothing, reason: i.name);
        await tester.tap(find.descendant(of: s, matching: find.byKey(const ValueKey('bi-chart-type-bar'))));
        await tester.pumpAndSettle();
        // Barras: una gráfica de barras agrupadas, o las barras del ranking.
        final hasBars =
            find.descendant(of: s, matching: find.byType(BarChart)).evaluate().isNotEmpty ||
            find.descendant(of: s, matching: find.byKey(const ValueKey('bi-bar-0'))).evaluate().isNotEmpty;
        expect(hasBars, isTrue, reason: i.name);
        expect(config().chartTypeFor(i), BiChartType.bar, reason: i.name);
      }
    });
  });

  group('paleta de gráficos', () {
    testWidgets('a pie with more than 5 slices cycles through the same 5 colors', (tester) async {
      for (var i = 0; i < 7; i++) {
        final cat = await h.newCategory('Cat $i');
        final p = await h.newProduct('Prod $i', categoryId: cat);
        await h.sell(day(0), p, 1, 100.0 - i * 10);
      }
      await h.refresh();
      await pumpPage(tester, confirm: true);

      final s = section(BiIndicator.salesByCategory);
      await tester.tap(find.descendant(of: s, matching: find.byKey(const ValueKey('bi-chart-type-pie'))));
      await tester.pumpAndSettle();

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
        final swatch = tester.widget<Container>(
          find.descendant(of: s, matching: find.byKey(ValueKey('bi-pie-swatch-$i'))),
        );
        expect((swatch.decoration as BoxDecoration).color, expected[i], reason: 'slice $i');
      }
      final pie = tester.widget<PieChart>(find.descendant(of: s, matching: find.byType(PieChart)));
      expect(pie.data.sections.map((e) => e.color), expected);
    });

    testWidgets('Precio A keeps the first color in the price-type pie, also by units', (tester) async {
      final p = await h.newProduct('Cuadro', stock: 1000);
      await h.sell(day(0), p, 1, 500, priceType: 'A');
      await h.sell(day(0), p, 10, 10, priceType: 'B');
      await h.refresh();
      await pumpPage(tester, confirm: true);
      final s = section(BiIndicator.salesByPriceType);
      await tester.tap(find.descendant(of: s, matching: find.byKey(const ValueKey('bi-chart-type-pie'))));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: s, matching: find.text('Unidades')));
      await tester.pumpAndSettle();

      // Por unidades B es mayor (10 contra 1), pero A sigue primero y con su color.
      final aTop = tester.getTopLeft(find.descendant(of: s, matching: find.text('Precio A'))).dy;
      final bTop = tester.getTopLeft(find.descendant(of: s, matching: find.text('Precio B'))).dy;
      expect(aTop, lessThan(bTop));
      final pie = tester.widget<PieChart>(find.descendant(of: s, matching: find.byType(PieChart)));
      expect(pie.data.sections.map((e) => e.color), [AppColors.chartColor1, AppColors.chartColor2]);
    });

    testWidgets('the radar and the line charts only use palette colors', (tester) async {
      final a = await h.newProduct('A', productionCost: 1);
      final b = await h.newProduct('B', productionCost: 1);
      final c = await h.newProduct('C', productionCost: 1);
      for (final p in [a, b, c]) {
        await h.sell(day(0), p, 1, 50);
      }
      await h.refresh();
      await pumpPage(tester, confirm: true, config: allIndicators());

      const palette = [
        AppColors.chartColor1,
        AppColors.chartColor2,
        AppColors.chartColor3,
        AppColors.chartColor4,
        AppColors.chartColor5,
      ];
      final radar = tester.widget<RadarChart>(find.byType(RadarChart));
      // El primer conjunto (invisible) solo fija la escala; los demás, un
      // color de la paleta por producto, en orden.
      final visible = radar.data.dataSets.skip(1).toList();
      expect(visible.length, 3);
      for (var i = 0; i < visible.length; i++) {
        expect(visible[i].borderColor, chartColorAt(i));
        expect(palette, contains(visible[i].borderColor));
      }
      final line = tester.widget<LineChart>(
        find.descendant(of: section(BiIndicator.timeSeries), matching: find.byType(LineChart)),
      );
      for (final bar in line.data.lineBarsData) {
        expect(palette, contains(bar.color));
      }
    });
  });

  group('ancho de teléfono', () {
    // Un teléfono pequeño (360 dp): sin desbordes en ningún indicador ni en la
    // configuración, también con textos largos y todos los tipos de gráfico.
    Future<void> pumpNarrow(WidgetTester tester, BiConfig config) async {
      tester.view.physicalSize = const Size(360, 60000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      h.container.read(biConfigProvider.notifier).state = config;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(theme: lightTheme, home: const BusinessIntelligencePage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('configuration and every indicator fit, in every chart type', (tester) async {
      final prod = await h.newProduct('Un producto con un nombre bastante largo para probar', productionCost: 20, stock: 500);
      final other = await h.newProduct('Otro producto de nombre también largo', productionCost: 80, stock: 3);
      await h.newProduct('Producto sin ventas con nombre muy largo número tres');
      final mat = await h.newMaterial('Material con un nombre extremadamente largo para ver el recorte');
      await h.newEvent('Evento con un nombre larguísimo de prueba', day(-3), day(-2));
      for (var i = 0; i < 20; i++) {
        await h.sell(day(-i * 5), prod, 1 + i % 3, 120.0 + i * 3);
        await h.sell(day(-i * 5 - 1), other, 1, 99, priceType: 'B');
      }
      await h.buyMaterial(day(-100), mat, 200, 3);
      await h.spend(day(-4), 321.5);
      await h.refresh();

      await pumpNarrow(
        tester,
        allIndicators(filters: ReportFilters(startDate: day(-45), endDate: day(0))),
      );
      expect(tester.takeException(), isNull, reason: 'configuración');
      await confirmConfig(tester);
      expect(tester.takeException(), isNull, reason: 'panel');

      for (final i in BiIndicator.values.where((i) => i.hasChartPicker)) {
        for (final type in i.chartTypes) {
          final picker = find.descendant(
            of: section(i),
            matching: find.byKey(ValueKey('bi-chart-type-${type.name}')),
          );
          if (picker.evaluate().isEmpty) continue; // indicador sin datos
          await tester.tap(picker);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${i.name} / ${type.name}');
        }
      }
      // El selector del radar y el de sin movimiento también caben.
      await tester.tap(find.byKey(const ValueKey('bi-radar-pick')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'selector del radar');
    });
  });

  group('selector de productos del radar (aspecto)', () {
    testWidgets('"Los más vendidos" stays on one line and the title clears the status bar', (
      tester,
    ) async {
      final a = await h.newProduct('A', productionCost: 1);
      final b = await h.newProduct('B', productionCost: 1);
      await h.sell(day(0), a, 1, 50);
      await h.sell(day(0), b, 1, 40);
      // Muchos productos: la hoja ocupa toda la altura, como en el teléfono.
      for (var i = 0; i < 15; i++) {
        await h.newProduct('Extra $i');
      }
      await h.refresh();

      // Teléfono angosto (360 x 640 px) con barra de estado de 40 px.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 40);
      tester.view.viewPadding = const FakeViewPadding(top: 40);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      h.container.read(biConfigProvider.notifier).state = BiConfig(
        indicators: {BiIndicator.productRadar},
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(theme: lightTheme, home: const BusinessIntelligencePage()),
        ),
      );
      await tester.pumpAndSettle();
      await confirmConfig(tester);

      await tester.tap(find.byKey(const ValueKey('bi-radar-pick')));
      await tester.pumpAndSettle();

      // El título no queda pegado a la barra de estado.
      final title = tester.getTopLeft(find.text('Elige de 2 a 4 productos'));
      expect(title.dy, greaterThanOrEqualTo(40));

      // El botón cabe en una sola línea.
      final label = find.text('Los más vendidos');
      expect(label, findsOneWidget);
      expect(tester.getSize(label).height, lessThan(30));
      expect(tester.takeException(), isNull);
    });
  });

  group('indicadores nuevos en pantalla', () {
    testWidgets('period comparison shows previous, current and the % change', (tester) async {
      final p = await h.newProduct('Cuadro', stock: 1000);
      // Un rango de ~10 días que termina hoy y que no empieza el día 1 ni es
      // de semana: así el periodo anterior son los mismos días de justo antes.
      var len = 10;
      while (day(-(len - 1)).day == 1) {
        len++;
      }
      final start = day(-(len - 1));
      await h.sell(day(-1), p, 1, 600);
      await h.sell(day(-len - 2), p, 1, 400);
      await h.spend(day(-2), 100);
      await h.spend(day(-len - 5), 200);
      await h.refresh();

      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(
          filters: ReportFilters(startDate: start, endDate: day(0)),
          indicators: {BiIndicator.periodComparison},
        ),
      );
      final s = section(BiIndicator.periodComparison);
      expect(find.descendant(of: s, matching: find.text('Anterior: Bs. 400.00')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Actual: Bs. 600.00')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('+50.0%')), findsOneWidget);
      // Gastos bajaron (200 → 100): -50 %, y eso es bueno (verde).
      expect(find.descendant(of: s, matching: find.text('−50.0%')), findsOneWidget);
      final gastosChange = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('bi-change-gastos')),
          matching: find.text('−50.0%'),
        ),
      );
      expect(gastosChange.style!.color, AppColors.primary);
      // Balance: 200 → 500 = +150 %.
      expect(find.descendant(of: s, matching: find.text('+150.0%')), findsOneWidget);
    });

    testWidgets('period comparison without dates explains what is needed', (tester) async {
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(indicators: {BiIndicator.periodComparison}),
      );
      expect(
        find.descendant(
          of: section(BiIndicator.periodComparison),
          matching: find.textContaining('Elige un periodo con fecha de inicio'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('projection shows the estimate, the dashed trend and the caveat', (tester) async {
      final p = await h.newProduct('Cuadro', stock: 1000);
      final t = h.now;
      final monday = DateTime(t.year, t.month, t.day - (t.weekday - 1), 12);
      for (var k = 16; k >= 1; k--) {
        await h.sell(
          DateTime(monday.year, monday.month, monday.day - 7 * k + 2, 12),
          p,
          1,
          300.0 + 40 * (16 - k),
        );
      }
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(indicators: {BiIndicator.salesProjection}),
      );
      final s = section(BiIndicator.salesProjection);
      expect(
        find.descendant(of: s, matching: find.byKey(const ValueKey('bi-projection-summary'))),
        findsOneWidget,
      );
      expect(find.descendant(of: s, matching: find.textContaining('≈ Bs. 4160.00')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.textContaining('Tendencia al alza')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.textContaining('no es una garantía')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.textContaining('punteada')), findsOneWidget);

      final chart = tester.widget<LineChart>(find.descendant(of: s, matching: find.byType(LineChart)));
      expect(chart.data.lineBarsData.length, 2);
      expect(chart.data.lineBarsData[0].dashArray, isNull); // real
      expect(chart.data.lineBarsData[1].dashArray, isNotNull); // tendencia
      // La proyección se extiende más allá de lo real (4 intervalos más).
      expect(
        chart.data.lineBarsData[1].spots.last.x,
        greaterThan(chart.data.lineBarsData[0].spots.last.x),
      );
    });

    testWidgets('projection explains why it is unavailable', (tester) async {
      final p = await h.newProduct('Cuadro');
      await h.sell(day(0), p, 1, 100);
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(indicators: {BiIndicator.salesProjection}),
      );
      expect(
        find.descendant(of: section(BiIndicator.salesProjection), matching: find.textContaining('3 intervalos')),
        findsOneWidget,
      );
    });

    testWidgets('event vs. regular days shows the per-day averages and a verdict', (tester) async {
      final p = await h.newProduct('Cuadro', stock: 1000);
      await h.newEvent('Feria', day(-3), day(-2));
      await h.sell(day(-3), p, 1, 300);
      await h.sell(day(-2), p, 1, 300);
      await h.sell(day(0), p, 1, 100);
      await h.sell(day(-1), p, 1, 100);
      await h.sell(day(-4), p, 1, 100);
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(
          filters: ReportFilters(startDate: day(-4), endDate: day(0)),
          indicators: {BiIndicator.eventComparison},
        ),
      );
      final s = section(BiIndicator.eventComparison);
      // Evento: 600 en 2 días = 300/día. Regular: 300 en 3 días = 100/día.
      expect(find.descendant(of: s, matching: find.text('Bs. 300.00')), findsWidgets);
      expect(find.descendant(of: s, matching: find.text('Bs. 100.00')), findsWidgets);
      final verdict = tester.widget<Text>(
        find.descendant(of: s, matching: find.byKey(const ValueKey('bi-event-verdict'))),
      );
      expect(verdict.data, contains('200.0% más por día'));
    });

    testWidgets('material cost vs. revenue states the ratio and the caveat', (tester) async {
      final p = await h.newProduct('Cuadro');
      final tela = await h.newMaterial('Tela');
      await h.sell(day(0), p, 4, 200);
      await h.buyMaterial(day(-1), tela, 16, 10);
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(indicators: {BiIndicator.materialCostRatio}),
      );
      final s = section(BiIndicator.materialCostRatio);
      expect(find.descendant(of: s, matching: find.text('20.0%')), findsOneWidget);
      expect(
        find.descendant(of: s, matching: find.textContaining('Bs. 0.20 en materiales')),
        findsOneWidget,
      );
      expect(find.descendant(of: s, matching: find.textContaining('no es un costo de ventas exacto')), findsOneWidget);
    });

    testWidgets('no-movement list with an adjustable window', (tester) async {
      final a = await h.newProduct('Reciente');
      final b = await h.newProduct('Antiguo');
      await h.newProduct('Nunca');
      await h.sell(day(-5), a, 1, 10);
      await h.sell(day(-40), b, 1, 20);
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(indicators: {BiIndicator.noMovement}),
      );
      final s = section(BiIndicator.noMovement);
      expect(find.descendant(of: s, matching: find.text('Nunca')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Antiguo')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Reciente')), findsNothing);
      expect(find.descendant(of: s, matching: find.text('Hace 40 días')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Sin ventas')), findsOneWidget);

      await tester.tap(find.descendant(of: s, matching: find.text('60 d')));
      await tester.pumpAndSettle();
      expect(config().noMovementDays, 60);
      expect(find.descendant(of: s, matching: find.text('Antiguo')), findsNothing);
      expect(find.descendant(of: s, matching: find.text('Nunca')), findsOneWidget);

      await tester.tap(find.descendant(of: s, matching: find.text('7 d')));
      await tester.pumpAndSettle();
      expect(config().noMovementDays, 7);
      expect(find.descendant(of: s, matching: find.text('Antiguo')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Reciente')), findsNothing); // hace 5 días
    });

    testWidgets('radar: pick 2-4 products, limited to 4, and reset to the best sellers', (tester) async {
      final ids = <int>[];
      for (var i = 0; i < 6; i++) {
        final id = await h.newProduct('P$i', productionCost: 1);
        ids.add(id);
        await h.sell(day(0), id, 1, 100.0 - i * 10);
      }
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(indicators: {BiIndicator.productRadar}),
      );
      final s = section(BiIndicator.productRadar);
      // Por defecto, los 3 con más ingresos.
      expect(find.descendant(of: s, matching: find.byType(RadarChart)), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('P0')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('P3')), findsNothing);
      expect(find.textContaining('Mostrando los productos con más ingresos'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bi-radar-pick')));
      await tester.pumpAndSettle();
      // Mínimo 2: con los 3 que vienen marcados, quitar 2 deja 1 y "Listo" se
      // desactiva; con 4 marcados, el resto queda deshabilitado.
      Finder option(int id) => find.byKey(ValueKey('bi-radar-option-$id'));
      bool enabled(int id) =>
          tester.widget<CheckboxListTile>(option(id)).onChanged != null;

      await tester.tap(option(ids[3]));
      await tester.pumpAndSettle();
      expect(enabled(ids[4]), isFalse); // 4 elegidos: el quinto no se puede
      expect(enabled(ids[0]), isTrue); // los marcados sí se pueden quitar

      await tester.tap(option(ids[0]));
      await tester.tap(option(ids[1]));
      await tester.tap(option(ids[2]));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ElevatedButton>(find.byKey(const ValueKey('bi-radar-done'))).onPressed,
        isNull, // solo queda 1
      );
      await tester.tap(option(ids[5]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bi-radar-done')));
      await tester.pumpAndSettle();

      expect(config().radarProductIds, [ids[3], ids[5]]);
      expect(find.descendant(of: s, matching: find.text('P3')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('P5')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('P0')), findsNothing);
      expect(find.textContaining('Mostrando los productos con más ingresos'), findsNothing);

      // "Los más vendidos" vuelve a la selección automática.
      await tester.tap(find.byKey(const ValueKey('bi-radar-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Los más vendidos'));
      await tester.pumpAndSettle();
      expect(config().radarProductIds, isEmpty);
      expect(find.descendant(of: s, matching: find.text('P0')), findsOneWidget);
    });

    testWidgets('radar with fewer than two products with sales explains it', (tester) async {
      final p = await h.newProduct('Solo');
      await h.sell(day(0), p, 1, 100);
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(indicators: {BiIndicator.productRadar}),
      );
      expect(
        find.descendant(of: section(BiIndicator.productRadar), matching: find.textContaining('al menos 2 productos')),
        findsOneWidget,
      );
    });

    testWidgets('margin explains when no sold product has a production cost', (tester) async {
      final p = await h.newProduct('Sin costo');
      await h.sell(day(0), p, 1, 100);
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(indicators: {BiIndicator.productMargin}),
      );
      expect(
        find.descendant(of: section(BiIndicator.productMargin), matching: find.textContaining('costo de producción')),
        findsWidgets,
      );
    });
  });
}
