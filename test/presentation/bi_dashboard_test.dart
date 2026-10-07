import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
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
    // El botón va al final del contenido que se desplaza.
    await tester.ensureVisible(find.byKey(const ValueKey('bi-config-confirm')));
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
      final p = await h.newProduct('Tote bag negra');
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

    testWidgets('lists all twenty-one indicators and every one has an info icon', (tester) async {
      await h.refresh();
      await pumpPage(tester);
      expect(BiIndicator.values.length, 21);
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
      expect(config().indicators.length, 21);
      expect(find.text('Ver indicadores (21)'), findsOneWidget);
    });

    testWidgets('only the chosen indicators are shown after confirming', (tester) async {
      final p = await h.newProduct('Tote bag negra');
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
      final p = await h.newProduct('Tote bag negra');
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
      final p = await h.newProduct('Tote bag negra');
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
        final p = await h.newProduct('Producto $i');
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
      final p = await h.newProduct('Tote bag negra');
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
      final oleo = await h.newProduct('Miniaturas', productionCost: 90);
      final stickersHolo = await h.newProduct('Stickers holográficos', productionCost: 40);
      await h.sell(day(0), oleo, 2, 300);
      await h.sell(day(0), stickersHolo, 5, 45);
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
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      await h.newEvent('Feria de Arte', day(-2), day(-1));
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
        final cat = await h.newCategory('Categoría $i');
        final p = await h.newProduct('Producto $i', categoryId: cat);
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
      final p = await h.newProduct('Tote bag negra', stock: 1000);
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
      final a = await h.newProduct('Estuches', productionCost: 1);
      final b = await h.newProduct('Libro', productionCost: 1);
      final c = await h.newProduct('Miniaturas', productionCost: 1);
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
      final prod = await h.newProduct('Set de pines pequeños', productionCost: 20, stock: 500);
      final other = await h.newProduct('Stickers holográficos', productionCost: 80, stock: 3);
      await h.newProduct('Pines grandes');
      final mat = await h.newMaterial('Base metálica pequeña para pines');
      await h.newEvent('Larga Noche de Museos La Paz', day(-3), day(-2));
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
      final a = await h.newProduct('Estuches', productionCost: 1);
      final b = await h.newProduct('Libro', productionCost: 1);
      await h.sell(day(0), a, 1, 50);
      await h.sell(day(0), b, 1, 40);
      // Muchos productos: la hoja ocupa toda la altura, como en el teléfono.
      for (var i = 0; i < 15; i++) {
        await h.newProduct('Producto $i');
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

      // El botón (al final de la lista que se desplaza) cabe en una sola línea.
      final label = find.text('Los más vendidos');
      await tester.scrollUntilVisible(
        label,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(label, findsOneWidget);
      expect(tester.getSize(label).height, lessThan(30));
      expect(tester.takeException(), isNull);
    });
  });

  group('indicadores nuevos en pantalla', () {
    testWidgets('period comparison shows previous, current and the % change', (tester) async {
      final p = await h.newProduct('Tote bag negra', stock: 1000);
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
      final p = await h.newProduct('Tote bag negra', stock: 1000);
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
      final p = await h.newProduct('Tote bag negra');
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
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      await h.newEvent('Feria de Arte', day(-3), day(-2));
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
      final p = await h.newProduct('Tote bag negra');
      final tela = await h.newMaterial('Tela negra');
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
      final a = await h.newProduct('Stickers');
      final b = await h.newProduct('Pines grandes');
      await h.newProduct('Estuches');
      await h.sell(day(-5), a, 1, 10);
      await h.sell(day(-40), b, 1, 20);
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(indicators: {BiIndicator.noMovement}),
      );
      final s = section(BiIndicator.noMovement);
      expect(find.descendant(of: s, matching: find.text('Estuches')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Pines grandes')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Stickers')), findsNothing);
      expect(find.descendant(of: s, matching: find.text('Hace 40 días')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Sin ventas')), findsOneWidget);

      await tester.tap(find.descendant(of: s, matching: find.text('60 d')));
      await tester.pumpAndSettle();
      expect(config().noMovementDays, 60);
      expect(find.descendant(of: s, matching: find.text('Pines grandes')), findsNothing);
      expect(find.descendant(of: s, matching: find.text('Estuches')), findsOneWidget);

      await tester.tap(find.descendant(of: s, matching: find.text('7 d')));
      await tester.pumpAndSettle();
      expect(config().noMovementDays, 7);
      expect(find.descendant(of: s, matching: find.text('Pines grandes')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Stickers')), findsNothing); // hace 5 días
    });

    testWidgets('radar: pick 2-4 products, limited to 4, and reset to the best sellers', (tester) async {
      final ids = <int>[];
      for (var i = 0; i < 6; i++) {
        final id = await h.newProduct('Producto $i', productionCost: 1);
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
      expect(find.descendant(of: s, matching: find.text('Producto 0')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Producto 3')), findsNothing);
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
      expect(find.descendant(of: s, matching: find.text('Producto 3')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Producto 5')), findsOneWidget);
      expect(find.descendant(of: s, matching: find.text('Producto 0')), findsNothing);
      expect(find.textContaining('Mostrando los productos con más ingresos'), findsNothing);

      // "Los más vendidos" vuelve a la selección automática.
      await tester.tap(find.byKey(const ValueKey('bi-radar-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Los más vendidos'));
      await tester.pumpAndSettle();
      expect(config().radarProductIds, isEmpty);
      expect(find.descendant(of: s, matching: find.text('Producto 0')), findsOneWidget);
    });

    testWidgets('radar with fewer than two products with sales explains it', (tester) async {
      final p = await h.newProduct('Libro');
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
      final p = await h.newProduct('Libro');
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

  group('indicadores de ventas adicionales (pantalla)', () {
    const added = [
      BiIndicator.coPurchase,
      BiIndicator.weekdaySales,
      BiIndicator.averageTicket,
      BiIndicator.eventProfit,
      BiIndicator.discountImpact,
      BiIndicator.costReturn,
    ];

    // The given weekday of the week that started [weeksAgo] weeks ago (>= 1).
    DateTime weekday(int weekday, int weeksAgo) {
      final t = h.now;
      final monday = DateTime(t.year, t.month, t.day - (t.weekday - 1), 12);
      return DateTime(monday.year, monday.month, monday.day - 7 * weeksAgo + (weekday - 1), 12);
    }

    BiConfig only(BiIndicator i) => BiConfig(indicators: {i});

    Finder inSection(BiIndicator i, Finder f) => find.descendant(of: section(i), matching: f);

    Future<void> pickType(WidgetTester tester, BiIndicator i, BiChartType t) async {
      await tester.tap(inSection(i, find.byKey(ValueKey('bi-chart-type-${t.name}'))));
      await tester.pumpAndSettle();
    }

    Color? barColor(WidgetTester tester, BiIndicator i, int index) {
      return tester.widget<Container>(inSection(i, find.byKey(ValueKey('bi-bar-$index')))).color;
    }

    Color? textColor(WidgetTester tester, Finder f) => tester.widget<Text>(f).style?.color;

    testWidgets('configuration: listed under Ventas, unchecked, each with an info icon', (tester) async {
      await h.refresh();
      await pumpPage(tester);

      final timeSeriesTop = tester.getTopLeft(find.byKey(const ValueKey('bi-indicator-timeSeries'))).dy;
      final materialsHeaderTop = tester.getTopLeft(find.text('Compras y materiales')).dy;
      const phrases = {
        BiIndicator.coPurchase: 'al menos 3 ventas',
        BiIndicator.weekdaySales: 'de lunes a domingo',
        BiIndicator.averageTicket: 'Evolución en el tiempo',
        BiIndicator.eventProfit: 'compras de materiales',
        BiIndicator.discountImpact: 'porcentaje de las ventas brutas',
        BiIndicator.costReturn: 'costo de producción manual',
      };
      for (final i in added) {
        final tile = find.byKey(ValueKey('bi-indicator-${i.name}'));
        expect(tile, findsOneWidget, reason: i.name);
        expect(checked(tester, i), isFalse, reason: i.name);
        // In the Ventas group: after the first Ventas indicators and before
        // the "Compras y materiales" header.
        final top = tester.getTopLeft(tile).dy;
        expect(top, greaterThan(timeSeriesTop), reason: i.name);
        expect(top, lessThan(materialsHeaderTop), reason: i.name);
        expect(find.text(i.title), findsOneWidget, reason: i.name);
        expect(find.text(i.description), findsOneWidget, reason: i.name);

        await tester.tap(find.byKey(ValueKey('bi-config-info-${i.name}')));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget, reason: i.name);
        expect(find.descendant(of: dialog, matching: find.text(i.title)), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.textContaining('Qué muestra')), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.textContaining('Para qué sirve')), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.textContaining(phrases[i]!)), findsOneWidget, reason: i.name);
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
      }

      // They are not part of the default selection; ticking one adds it.
      final defaults = BiIndicator.values.where((i) => i.defaultSelected).length;
      expect(find.text('Ver indicadores ($defaults)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bi-indicator-eventProfit')));
      await tester.pumpAndSettle();
      expect(checked(tester, BiIndicator.eventProfit), isTrue);
      expect(find.text('Ver indicadores (${defaults + 1})'), findsOneWidget);
    });

    testWidgets('every new card has its info icon and, with more than one view, a chart picker', (tester) async {
      final p = await h.newProduct('Tote bag negra', productionCost: 40, stock: 1000);
      final feria = await h.newEvent('Feria de Arte', day(-30), day(-28));
      await h.sell(day(-3), p, 1, 100, eventId: feria);
      await h.sellMany(day(-2), [(p, 1, 100), (await h.newProduct('Stickers'), 1, 10)]);
      await h.spend(day(-3), 50, eventId: feria);
      await h.refresh();
      await pumpPage(tester, confirm: true, config: BiConfig(indicators: {...added}));

      for (final i in added) {
        expect(section(i), findsOneWidget, reason: i.name);
        final icon = inSection(i, find.byKey(ValueKey('bi-info-${i.title}')));
        expect(icon, findsOneWidget, reason: i.name);
        await tester.tap(icon);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget, reason: i.name);
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
        for (final type in i.chartTypes) {
          expect(
            inSection(i, find.byKey(ValueKey('bi-chart-type-${type.name}'))),
            findsOneWidget,
            reason: '${i.name} / ${type.name}',
          );
        }
      }
    });

    group('productos comprados juntos', () {
      Future<void> seedPairs() async {
        final a = await h.newProduct('Tote bag negra', stock: 1000);
        final b = await h.newProduct('Pines grandes', stock: 1000);
        final c = await h.newProduct('Stickers', stock: 1000);
        final d = await h.newProduct('Libro', stock: 1000);
        // A+B in 4 sales, A+C in 3, A+D in only 2, plus a single-product sale.
        for (var i = 1; i <= 4; i++) {
          await h.sellMany(day(-i), [(a, 1, 100), (b, 1, 20)]);
        }
        for (var i = 5; i <= 7; i++) {
          await h.sellMany(day(-i), [(a, 1, 100), (c, 1, 10)]);
        }
        for (var i = 8; i <= 9; i++) {
          await h.sellMany(day(-i), [(a, 1, 100), (d, 1, 50)]);
        }
        await h.sell(day(-10), b, 1, 20);
        await h.refresh();
      }

      testWidgets('ranked list by default, then bars, with the 3-sale minimum noted', (tester) async {
        await seedPairs();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.coPurchase));
        const i = BiIndicator.coPurchase;

        expect(inSection(i, find.byKey(const ValueKey('bi-pair-0'))), findsOneWidget);
        expect(inSection(i, find.byKey(const ValueKey('bi-pair-1'))), findsOneWidget);
        expect(inSection(i, find.byKey(const ValueKey('bi-pair-2'))), findsNothing); // A+D: 2 sales
        expect(inSection(i, find.text('Pines grandes + Tote bag negra')), findsOneWidget);
        expect(inSection(i, find.text('4 ventas')), findsOneWidget);
        expect(inSection(i, find.text('40.0%')), findsOneWidget);
        expect(inSection(i, find.text('Stickers + Tote bag negra')), findsOneWidget);
        expect(inSection(i, find.text('3 ventas')), findsOneWidget);
        expect(inSection(i, find.text('30.0%')), findsOneWidget);
        expect(inSection(i, find.textContaining('Libro')), findsNothing);
        final first = tester.getTopLeft(inSection(i, find.text('Pines grandes + Tote bag negra'))).dy;
        final second = tester.getTopLeft(inSection(i, find.text('Stickers + Tote bag negra'))).dy;
        expect(first, lessThan(second));
        expect(
          tester.widget<Text>(inSection(i, find.byKey(const ValueKey('bi-pair-footnote')))).data,
          'Solo pares vistos en al menos 3 ventas. 10 ventas en el periodo, '
          '9 con 2 o más productos distintos.',
        );

        await pickType(tester, i, BiChartType.bar);
        expect(inSection(i, find.byKey(const ValueKey('bi-bar-0'))), findsOneWidget);
        expect(inSection(i, find.byKey(const ValueKey('bi-bar-1'))), findsOneWidget);
        expect(inSection(i, find.byKey(const ValueKey('bi-bar-2'))), findsNothing);
        expect(inSection(i, find.text('40.0% de las ventas del periodo')), findsOneWidget);
        expect(barColor(tester, i, 0), chartColorAt(0));
        expect(config().chartTypeFor(i), BiChartType.bar);
        // The 4-sale bar is longer than the 3-sale bar (proportional).
        final w0 = tester.getSize(inSection(i, find.byKey(const ValueKey('bi-bar-0')))).width;
        final w1 = tester.getSize(inSection(i, find.byKey(const ValueKey('bi-bar-1')))).width;
        expect(w1 / w0, closeTo(3 / 4, 0.01));

        await pickType(tester, i, BiChartType.list);
        expect(inSection(i, find.byKey(const ValueKey('bi-pair-0'))), findsOneWidget);
      });

      testWidgets('respects the period filter', (tester) async {
        await seedPairs();
        // Last 3 days: 3 sales, all A+B → 3 sales, 100 %.
        await pumpPage(
          tester,
          confirm: true,
          config: BiConfig(
            indicators: {BiIndicator.coPurchase},
            filters: ReportFilters(startDate: day(-3), endDate: day(0)),
          ),
        );
        const i = BiIndicator.coPurchase;
        expect(inSection(i, find.text('Pines grandes + Tote bag negra')), findsOneWidget);
        expect(inSection(i, find.text('3 ventas')), findsOneWidget);
        expect(inSection(i, find.text('100.0%')), findsOneWidget);
        expect(inSection(i, find.byKey(const ValueKey('bi-pair-1'))), findsNothing);
      });

      testWidgets('explains why there are no pairs', (tester) async {
        final a = await h.newProduct('Tote bag negra', stock: 1000);
        final b = await h.newProduct('Pines grandes', stock: 1000);
        await h.sell(day(-1), a, 1, 100);
        await h.refresh();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.coPurchase));
        expect(
          inSection(BiIndicator.coPurchase, find.text('Ninguna venta del periodo incluye 2 o más productos distintos.')),
          findsOneWidget,
        );

        // Two sales of the same pair: below the 3-sale minimum.
        await h.sellMany(day(-2), [(a, 1, 100), (b, 1, 20)]);
        await h.sellMany(day(-3), [(a, 1, 100), (b, 1, 20)]);
        await h.refresh();
        await tester.tap(find.byKey(const ValueKey('bi-configure')));
        await tester.pumpAndSettle();
        await confirmConfig(tester);
        expect(
          inSection(BiIndicator.coPurchase, find.text('Ningún par de productos coincide en al menos 3 ventas del periodo.')),
          findsOneWidget,
        );
      });
    });

    group('ventas por día de la semana', () {
      Future<void> seedDays() async {
        final p = await h.newProduct('Tote bag negra', stock: 1000);
        await h.sell(weekday(DateTime.monday, 1), p, 1, 100);
        await h.sell(weekday(DateTime.monday, 2), p, 1, 50);
        await h.sell(weekday(DateTime.saturday, 1), p, 1, 200);
        await h.sell(weekday(DateTime.sunday, 1), p, 1, 30);
        await h.refresh();
      }

      testWidgets('seven Spanish days from Monday, with ingresos and sales, bars or line', (tester) async {
        await seedDays();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.weekdaySales));
        const i = BiIndicator.weekdaySales;

        const names = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        double? previousTop;
        for (var d = 0; d < 7; d++) {
          final row = inSection(i, find.byKey(ValueKey('bi-weekday-row-$d')));
          expect(row, findsOneWidget);
          expect(find.descendant(of: row, matching: find.text(names[d])), findsOneWidget);
          final top = tester.getTopLeft(row).dy;
          if (previousTop != null) expect(top, greaterThan(previousTop));
          previousTop = top;
        }
        Finder rowText(int d, String text) =>
            find.descendant(of: inSection(i, find.byKey(ValueKey('bi-weekday-row-$d'))), matching: find.text(text));
        expect(rowText(0, 'Bs. 150.00 · 2 ventas'), findsOneWidget); // Lunes: 100 + 50
        expect(rowText(1, 'Bs. 0.00 · 0 ventas'), findsOneWidget);
        expect(rowText(5, 'Bs. 200.00 · 1 venta'), findsOneWidget); // Sábado
        expect(rowText(6, 'Bs. 30.00 · 1 venta'), findsOneWidget); // Domingo
        expect(find.byType(BarChart), findsOneWidget);
        expect(find.byType(LineChart), findsNothing);

        await pickType(tester, i, BiChartType.line);
        expect(find.byType(LineChart), findsOneWidget);
        expect(find.byType(BarChart), findsNothing);
        expect(config().chartTypeFor(i), BiChartType.line);
        await pickType(tester, i, BiChartType.bar);
        expect(find.byType(BarChart), findsOneWidget);
      });

      testWidgets('toggles between ingresos and number of sales', (tester) async {
        await seedDays();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.weekdaySales));
        const i = BiIndicator.weekdaySales;

        Finder best = inSection(i, find.byKey(const ValueKey('bi-weekday-best')));
        // By revenue Saturday (200) beats Monday (150); by sales Monday wins (2).
        expect(tester.widget<Text>(best).data, 'Día más fuerte: Sábado (Bs. 200.00).');
        BarChart chart() => tester.widget<BarChart>(find.byType(BarChart));
        expect(chart().data.barGroups.map((g) => g.barRods.single.toY), [150, 0, 0, 0, 0, 200, 30]);

        await tester.tap(inSection(i, find.text('Número de ventas')));
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(best).data, 'Día más fuerte: Lunes (2 ventas).');
        expect(chart().data.barGroups.map((g) => g.barRods.single.toY), [2, 0, 0, 0, 0, 1, 1]);

        await tester.tap(inSection(i, find.text('Ingresos')));
        await tester.pumpAndSettle();
        expect(chart().data.barGroups.map((g) => g.barRods.single.toY), [150, 0, 0, 0, 0, 200, 30]);
      });

      testWidgets('shows an empty state without sales and no picker', (tester) async {
        await h.refresh();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.weekdaySales));
        const i = BiIndicator.weekdaySales;
        expect(inSection(i, find.text('Sin datos para los filtros aplicados')), findsOneWidget);
        expect(inSection(i, find.byKey(const ValueKey('bi-chart-type-line'))), findsNothing);
      });
    });

    group('ticket promedio', () {
      Future<void> seedTickets() async {
        final p = await h.newProduct('Tote bag negra', stock: 1000);
        await h.sell(weekday(DateTime.monday, 1), p, 1, 100);
        await h.sell(weekday(DateTime.monday, 2), p, 1, 50);
        await h.sell(weekday(DateTime.saturday, 1), p, 1, 200);
        await h.refresh();
      }

      testWidgets('card with the average, then its trend as a line', (tester) async {
        await seedTickets();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.averageTicket));
        const i = BiIndicator.averageTicket;

        // (100 + 50 + 200) / 3 = 116.666...
        expect(tester.widget<Text>(find.descendant(of: inSection(i, find.byKey(const ValueKey('bi-ticket-average'))), matching: find.text('Bs. 116.67'))).data, 'Bs. 116.67');
        expect(inSection(i, find.text('Bs. 350.00')), findsOneWidget);
        expect(inSection(i, find.text('3')), findsOneWidget);
        expect(find.byType(LineChart), findsNothing);

        await pickType(tester, i, BiChartType.line);
        expect(find.byType(LineChart), findsOneWidget);
        expect(
          tester.widget<Text>(inSection(i, find.byKey(const ValueKey('bi-ticket-summary')))).data,
          'Promedio del periodo: Bs. 116.67 (3 ventas).',
        );
        expect(inSection(i, find.text('Por venta · vista diaria')), findsOneWidget);
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        // One point per day with sales: ticket 50, 100 and 200.
        expect(chart.data.lineBarsData.single.spots.map((s) => s.y), [50, 100, 200]);
        expect(config().chartTypeFor(i), BiChartType.line);
        await pickType(tester, i, BiChartType.cards);
        expect(inSection(i, find.byKey(const ValueKey('bi-ticket-average'))), findsOneWidget);
      });

      testWidgets('without sales: empty state, no picker', (tester) async {
        await h.refresh();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.averageTicket));
        const i = BiIndicator.averageTicket;
        expect(inSection(i, find.text('Sin datos para los filtros aplicados')), findsOneWidget);
        expect(inSection(i, find.byKey(const ValueKey('bi-chart-type-line'))), findsNothing);
      });
    });

    group('impacto de los descuentos', () {
      testWidgets('card with amount, % of gross sales, and the line trend', (tester) async {
        final p = await h.newProduct('Tote bag negra', stock: 1000);
        await h.sell(day(-3), p, 1, 100, discount: 10);
        await h.sell(day(-2), p, 1, 200);
        await h.sell(day(-1), p, 2, 50, discount: 20);
        await h.refresh();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.discountImpact));
        const i = BiIndicator.discountImpact;

        // Gross 400, discounts 30 → 7.5 %, 2 of the 3 sales had a discount.
        Finder tile(String key, String text) =>
            find.descendant(of: inSection(i, find.byKey(ValueKey(key))), matching: find.text(text));
        expect(tile('bi-discount-total', 'Bs. 30.00'), findsOneWidget);
        expect(tile('bi-discount-pct', '7.5%'), findsOneWidget);
        expect(tile('bi-discount-gross', 'Bs. 400.00'), findsOneWidget);
        expect(
          tester.widget<Text>(inSection(i, find.byKey(const ValueKey('bi-discount-summary')))).data,
          '2 de 3 ventas tuvieron descuento.',
        );
        expect(find.byType(LineChart), findsNothing);

        await pickType(tester, i, BiChartType.line);
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        // Daily buckets: -3 → 10, -2 → 0, -1 → 20 (days with sales only).
        expect(chart.data.lineBarsData.single.spots.map((s) => s.y), [10, 0, 20]);
        expect(inSection(i, find.text('Descuentos dados · vista diaria')), findsOneWidget);
        expect(config().chartTypeFor(i), BiChartType.line);
      });

      testWidgets('says so when no sale had a discount', (tester) async {
        final p = await h.newProduct('Tote bag negra', stock: 1000);
        await h.sell(day(-1), p, 1, 100);
        await h.refresh();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.discountImpact));
        const i = BiIndicator.discountImpact;
        expect(inSection(i, find.text('Ninguna venta del periodo tuvo descuento.')), findsOneWidget);
        expect(inSection(i, find.text('0.0%')), findsOneWidget);
      });
    });

    group('rentabilidad por evento', () {
      Future<void> seedEvents() async {
        final p = await h.newProduct('Tote bag negra', stock: 1000);
        final arte = await h.newEvent('Feria de Arte', day(-30), day(-28));
        final lima = await h.newEvent('Feria de Lima', day(-20), day(-18));
        await h.sell(day(-3), p, 1, 300, eventId: arte);
        await h.spend(day(-4), 100, eventId: arte);
        await h.sell(day(-2), p, 1, 100, eventId: lima);
        await h.spend(day(-6), 400, eventId: lima);
        await h.spend(day(-1), 250, eventId: lima);
        await h.refresh();
      }

      testWidgets('bars: the result per event, the loss in red and to the left of zero', (tester) async {
        await seedEvents();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.eventProfit));
        const i = BiIndicator.eventProfit;

        expect(inSection(i, find.text('Feria de Arte')), findsOneWidget);
        expect(inSection(i, find.text('Feria de Lima')), findsOneWidget);
        // Arte: 300 − 100 = +200; Lima: 100 − (400 + 250) = −550.
        final gain = inSection(i, find.byKey(const ValueKey('bi-bar-value-0')));
        final loss = inSection(i, find.byKey(const ValueKey('bi-bar-value-1')));
        expect(tester.widget<Text>(gain).data, 'Bs. 200.00');
        expect(tester.widget<Text>(loss).data, 'Bs. -550.00');
        expect(textColor(tester, gain), AppColors.textPrimary);
        expect(textColor(tester, loss), AppColors.error);
        expect(barColor(tester, i, 0), chartColorAt(0));
        expect(barColor(tester, i, 1), AppColors.error);
        expect(inSection(i, find.text('Ingresos Bs. 300.00 (1 venta) · Gastos Bs. 100.00')), findsOneWidget);
        expect(inSection(i, find.text('Ingresos Bs. 100.00 (1 venta) · Gastos Bs. 650.00')), findsOneWidget);
        // The loss bar ends where the profit bar starts (the zero line).
        final lossRight = tester.getTopRight(inSection(i, find.byKey(const ValueKey('bi-bar-1')))).dx;
        final gainLeft = tester.getTopLeft(inSection(i, find.byKey(const ValueKey('bi-bar-0')))).dx;
        expect(lossRight, closeTo(gainLeft, 1.0));
        // Proportional: 550 against 200.
        final lossW = tester.getSize(inSection(i, find.byKey(const ValueKey('bi-bar-1')))).width;
        final gainW = tester.getSize(inSection(i, find.byKey(const ValueKey('bi-bar-0')))).width;
        expect(lossW / gainW, closeTo(550 / 200, 0.02));
        expect(
          inSection(i, find.textContaining('gastos generales y de materiales')),
          findsOneWidget,
        );
      });

      testWidgets('sorted list, best first, loss in red, remembered choice', (tester) async {
        await seedEvents();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.eventProfit));
        const i = BiIndicator.eventProfit;
        await pickType(tester, i, BiChartType.list);

        final first = find.byKey(const ValueKey('bi-event-profit-row-0'));
        final second = find.byKey(const ValueKey('bi-event-profit-row-1'));
        expect(find.descendant(of: first, matching: find.text('Feria de Arte')), findsOneWidget);
        expect(find.descendant(of: second, matching: find.text('Feria de Lima')), findsOneWidget);
        final gain = find.byKey(const ValueKey('bi-event-profit-value-0'));
        final loss = find.byKey(const ValueKey('bi-event-profit-value-1'));
        expect(tester.widget<Text>(gain).data, 'Bs. 200.00');
        expect(tester.widget<Text>(loss).data, 'Bs. -550.00');
        expect(textColor(tester, gain), AppColors.textPrimary);
        expect(textColor(tester, loss), AppColors.error);
        expect(config().chartTypeFor(i), BiChartType.list);
      });

      testWidgets('says so when no event has sales or purchases in the period', (tester) async {
        final p = await h.newProduct('Tote bag negra');
        await h.sell(day(-1), p, 1, 100);
        await h.refresh();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.eventProfit));
        const i = BiIndicator.eventProfit;
        expect(
          inSection(i, find.text('Ningún evento tuvo ventas ni compras vinculadas en el periodo.')),
          findsOneWidget,
        );
        expect(inSection(i, find.byKey(const ValueKey('bi-chart-type-list'))), findsNothing);
      });
    });

    group('retorno sobre el costo de producción', () {
      Future<void> seedReturns() async {
        final tote = await h.newProduct('Tote bag negra', productionCost: 40, stock: 1000);
        final stickers = await h.newProduct('Stickers', productionCost: 5, stock: 1000);
        final pines = await h.newProduct('Pines grandes', productionCost: 10, stock: 1000);
        final libro = await h.newProduct('Libro', stock: 1000); // no production cost
        await h.sell(day(-3), tote, 2, 100); // 200 vs 80  → +1.50
        await h.sell(day(-3), stickers, 10, 12); // 120 vs 50 → +1.40
        await h.sell(day(-3), pines, 5, 8); // 40 vs 50 → −0.20
        await h.sell(day(-3), libro, 1, 95); // left out
        await h.refresh();
      }

      testWidgets('bars: the sentence per product, best to worst, loss in red', (tester) async {
        await seedReturns();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.costReturn));
        const i = BiIndicator.costReturn;

        // The sentence uses non-breaking spaces after "Bs." so it never wraps
        // the amount away from its currency on a narrow phone.
        expect(inSection(i, find.text('Por cada Bs.\u00A01 de costo, la ganancia fue Bs.\u00A01.50')), findsOneWidget);
        expect(inSection(i, find.text('Por cada Bs.\u00A01 de costo, la ganancia fue Bs.\u00A01.40')), findsOneWidget);
        expect(inSection(i, find.text('Por cada Bs.\u00A01 de costo, la ganancia fue Bs.\u00A0-0.20')), findsOneWidget);
        final tops = [
          for (final n in ['Tote bag negra', 'Stickers', 'Pines grandes'])
            tester.getTopLeft(inSection(i, find.text(n))).dy,
        ];
        expect(tops[0], lessThan(tops[1]));
        expect(tops[1], lessThan(tops[2]));
        expect(inSection(i, find.textContaining('Libro')), findsNothing);
        expect(inSection(i, find.text('Ingresos Bs. 200.00 · Costo Bs. 80.00 · 2 uds.')), findsOneWidget);

        final loss = inSection(i, find.byKey(const ValueKey('bi-bar-value-2')));
        expect(tester.widget<Text>(loss).data, 'Bs. -0.20');
        expect(textColor(tester, loss), AppColors.error);
        expect(textColor(tester, inSection(i, find.byKey(const ValueKey('bi-bar-value-0')))), AppColors.textPrimary);
        expect(barColor(tester, i, 2), AppColors.error);
        expect(barColor(tester, i, 0), chartColorAt(0));
        expect(
          tester.widget<Text>(inSection(i, find.byKey(const ValueKey('bi-return-without-cost')))).data,
          '1 producto vendido no aparece: no tiene costo de producción registrado.',
        );
      });

      testWidgets('sorted list with the same figures and a red loss', (tester) async {
        await seedReturns();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.costReturn));
        const i = BiIndicator.costReturn;
        await pickType(tester, i, BiChartType.list);

        expect(
          find.descendant(of: find.byKey(const ValueKey('bi-return-row-0')), matching: find.text('Tote bag negra')),
          findsOneWidget,
        );
        expect(tester.widget<Text>(find.byKey(const ValueKey('bi-return-value-0'))).data, 'Bs. 1.50');
        expect(tester.widget<Text>(find.byKey(const ValueKey('bi-return-value-2'))).data, 'Bs. -0.20');
        expect(textColor(tester, find.byKey(const ValueKey('bi-return-value-2'))), AppColors.error);
        expect(textColor(tester, find.byKey(const ValueKey('bi-return-phrase-2'))), AppColors.error);
        expect(textColor(tester, find.byKey(const ValueKey('bi-return-value-1'))), AppColors.textPrimary);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('bi-return-phrase-0'))).data,
          'Por cada Bs.\u00A01 de costo, la ganancia fue Bs.\u00A01.50',
        );
        expect(config().chartTypeFor(i), BiChartType.list);
      });

      testWidgets('on a phone width the sentence never splits "Bs." from its amount', (tester) async {
        tester.view.physicalSize = const Size(360, 60000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await seedReturns();
        h.container.read(biConfigProvider.notifier).state = BiConfig(
          indicators: {BiIndicator.costReturn},
          chartTypes: {BiIndicator.costReturn: BiChartType.list},
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: MaterialApp(theme: lightTheme, home: const BusinessIntelligencePage()),
          ),
        );
        await tester.pumpAndSettle();
        await confirmConfig(tester);

        for (var row = 0; row < 3; row++) {
          final finder = find.byKey(ValueKey('bi-return-phrase-$row'));
          final text = tester.widget<Text>(finder).data!;
          // No ordinary space after "Bs." anywhere in the sentence.
          expect(text.contains('Bs. '), isFalse, reason: 'row $row');
          expect(RegExp('Bs\\.\u00A0').allMatches(text).length, 2, reason: 'row $row');

          // The rendered paragraph keeps each "Bs." and its amount on one line.
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          expect(paragraph.size.height, greaterThan(paragraph.text.style!.fontSize! * 1.5),
              reason: 'row $row should wrap on a 360 dp phone, or the check proves nothing');
          for (final m in RegExp('Bs\\.\u00A0').allMatches(text)) {
            // From "Bs." through the first character of the amount: if the
            // text wrapped in between, the boxes would sit on different lines.
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: m.start, extentOffset: m.end + 1),
            );
            expect(boxes, isNotEmpty);
            expect(boxes.map((b) => b.top).toSet().length, 1,
                reason: 'row $row: "Bs." wrapped away from its amount');
          }
        }
      });

      testWidgets('explains when no sold product has a production cost', (tester) async {
        final libro = await h.newProduct('Libro');
        await h.sell(day(-1), libro, 1, 95);
        await h.refresh();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.costReturn));
        const i = BiIndicator.costReturn;
        expect(
          inSection(
            i,
            find.text(
              'Los productos vendidos no tienen costo de producción registrado: '
              'agrégalo en Productos para ver su retorno.',
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('counts several products left out in the plural', (tester) async {
        final tote = await h.newProduct('Tote bag negra', productionCost: 40, stock: 1000);
        final libro = await h.newProduct('Libro', stock: 1000);
        final estuches = await h.newProduct('Estuches', stock: 1000);
        await h.sell(day(-1), tote, 1, 100);
        await h.sell(day(-1), libro, 1, 95);
        await h.sell(day(-1), estuches, 1, 55);
        await h.refresh();
        await pumpPage(tester, confirm: true, config: only(BiIndicator.costReturn));
        expect(
          find.text('2 productos vendidos no aparecen: no tienen costo de producción registrado.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('their charts only use palette colors (the red is only for losses)', (tester) async {
      final p = await h.newProduct('Tote bag negra', productionCost: 40, stock: 1000);
      await h.sell(weekday(DateTime.monday, 1), p, 1, 100, discount: 10);
      await h.sell(weekday(DateTime.saturday, 1), p, 1, 200);
      await h.refresh();
      await pumpPage(
        tester,
        confirm: true,
        config: BiConfig(
          indicators: {
            BiIndicator.weekdaySales,
            BiIndicator.averageTicket,
            BiIndicator.discountImpact,
          },
        ),
      );
      const palette = [
        AppColors.chartColor1,
        AppColors.chartColor2,
        AppColors.chartColor3,
        AppColors.chartColor4,
        AppColors.chartColor5,
      ];

      final bars = tester.widget<BarChart>(find.byType(BarChart));
      for (final g in bars.data.barGroups) {
        for (final rod in g.barRods) {
          expect(palette, contains(rod.color));
        }
      }
      for (final i in [BiIndicator.weekdaySales, BiIndicator.averageTicket, BiIndicator.discountImpact]) {
        await pickType(tester, i, BiChartType.line);
        final line = tester.widget<LineChart>(inSection(i, find.byType(LineChart)));
        for (final bar in line.data.lineBarsData) {
          expect(palette, contains(bar.color), reason: i.name);
        }
        for (final extra in line.data.extraLinesData.horizontalLines) {
          expect(palette, contains(extra.color), reason: i.name);
        }
      }
    });

    testWidgets('on a phone width every new indicator fits in every chart type and metric', (tester) async {
      tester.view.physicalSize = const Size(360, 60000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tote = await h.newProduct('Set de pines pequeños', productionCost: 20, stock: 500);
      final stickers = await h.newProduct('Stickers holográficos', productionCost: 80, stock: 500);
      final libro = await h.newProduct('Libro', stock: 500);
      final larga = await h.newEvent('Larga Noche de Museos La Paz', day(-30), day(-28));
      final lima = await h.newEvent('Feria del Libro Santa Cruz', day(-20), day(-18));
      for (var i = 0; i < 24; i++) {
        await h.sellMany(
          day(-i * 3 - 1),
          [(tote, 1 + i % 3, 120.0 + i), (stickers, 1, 99), if (i % 4 == 0) (libro, 1, 95)],
          eventId: i % 5 == 0 ? larga : (i % 7 == 0 ? lima : null),
          discount: i % 3 == 0 ? 7.5 : 0,
        );
      }
      await h.spend(day(-3), 321.5, eventId: larga);
      await h.spend(day(-5), 4000, eventId: lima);
      await h.refresh();

      h.container.read(biConfigProvider.notifier).state = BiConfig(indicators: {...added});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(theme: lightTheme, home: const BusinessIntelligencePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'configuration');
      await confirmConfig(tester);
      expect(tester.takeException(), isNull, reason: 'dashboard');

      for (final i in added) {
        for (final type in i.chartTypes) {
          await pickType(tester, i, type);
          expect(tester.takeException(), isNull, reason: '${i.name} / ${type.name}');
        }
      }
      // Weekday metric toggle in both chart types.
      for (final type in BiIndicator.weekdaySales.chartTypes) {
        await pickType(tester, BiIndicator.weekdaySales, type);
        await tester.tap(inSection(BiIndicator.weekdaySales, find.text('Número de ventas')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'weekday ${type.name} ventas');
        await tester.tap(inSection(BiIndicator.weekdaySales, find.text('Ingresos')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'weekday ${type.name} ingresos');
      }
    });
  });
}
