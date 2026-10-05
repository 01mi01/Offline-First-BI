import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/bi_provider.dart';
import 'package:offline_first_bi/application/unit_provider.dart';
import 'package:offline_first_bi/config/date_formatters.dart';
import 'package:offline_first_bi/models/bi_config.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/pages/business_intelligence_page.dart';
import 'package:offline_first_bi/presentation/widgets/bi_interaction.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import '../support/bi_drill_seed.dart';
import '../support/bi_harness.dart';

// Interactividad de los gráficos de Business Intelligence: globo de detalle al
// tocar, animación de entrada, zoom y arrastre en las líneas, detalle de las
// barras de los rankings y leyenda que oculta series. Los valores esperados
// están calculados a mano.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = BiHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  DateTime day(int offset, [int hour = 12]) => h.day(offset, hour);

  // El [weekday] de la semana que empezó hace [weeksAgo] semanas (>= 1).
  DateTime weekday(int weekday, int weeksAgo) {
    final t = h.now;
    final monday = DateTime(t.year, t.month, t.day - (t.weekday - 1), 12);
    return DateTime(
      monday.year,
      monday.month,
      monday.day - 7 * weeksAgo + (weekday - 1),
      12,
    );
  }

  Future<void> pumpDashboard(
    WidgetTester tester,
    BiConfig config, {
    Size size = const Size(900, 30000),
    bool reduceMotion = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    h.container.read(biConfigProvider.notifier).state = config;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          theme: lightTheme,
          builder: reduceMotion
              ? (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                )
              : null,
          home: const BusinessIntelligencePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Una segunda llamada en el mismo test ya encuentra el panel abierto.
    final confirm = find.byKey(const ValueKey('bi-config-confirm'));
    if (confirm.evaluate().isNotEmpty) await tester.tap(confirm);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  BiConfig only(
    BiIndicator i, {
    ReportFilters filters = const ReportFilters(),
  }) => BiConfig(filters: filters, indicators: {i});

  Finder section(BiIndicator i) => find.byKey(ValueKey('bi-section-${i.name}'));
  Finder inSection(BiIndicator i, Finder f) =>
      find.descendant(of: section(i), matching: f);

  Future<void> pickType(
    WidgetTester tester,
    BiIndicator i,
    BiChartType t,
  ) async {
    await tester.tap(
      inSection(i, find.byKey(ValueKey('bi-chart-type-${t.name}'))),
    );
    await tester.pumpAndSettle();
  }

  final tooltip = find.byKey(const ValueKey('bi-tooltip'));

  // Los textos del globo de detalle, en orden.
  // Con [of] solo los del indicador dado (varios indicadores pueden tener su
  // propio globo a la vez).
  List<String> tipTexts(WidgetTester tester, [BiIndicator? of]) => [
    for (final t in tester.widgetList<Text>(
      find.descendant(
        of: of == null ? tooltip : inSection(of, tooltip),
        matching: find.byType(Text),
      ),
    ))
      t.data!,
  ];

  // Punto del gráfico de líneas donde está el intervalo [i] (el eje de montos
  // ocupa los primeros 40 dp y el eje X ya no lo dibuja el gráfico).
  Offset linePoint(WidgetTester tester, Finder chart, double i) {
    final rect = tester.getRect(chart);
    final data = tester.widget<LineChart>(chart).data;
    final fraction = (i - data.minX) / (data.maxX - data.minX);
    return Offset(
      rect.left +
          kBiMoneyAxisReserved +
          fraction * (rect.width - kBiMoneyAxisReserved),
      rect.center.dy,
    );
  }

  // Punto sobre la barra del grupo [i] de [groups] (con el eje inferior de 24 o
  // [axis] dp), cerca de la base para caer dentro de cualquier barra.
  Offset barPoint(
    WidgetTester tester,
    Finder chart,
    int i,
    int groups, {
    double axis = 24,
  }) {
    final rect = tester.getRect(chart);
    final plot = rect.width - kBiMoneyAxisReserved;
    return Offset(
      rect.left + kBiMoneyAxisReserved + (i + 0.5) * plot / groups,
      rect.bottom - axis - 5,
    );
  }

  // ---------------------------------------------------------------------
  // Globo de detalle al tocar
  // ---------------------------------------------------------------------

  group('globo de detalle', () {
    testWidgets(
      'ranking sin detalle: tocar una barra muestra su nombre y su valor',
      (tester) async {
        final p = await h.newProduct('Tote bag', stock: 1000);
        await h.sell(
          day(0),
          p,
          3,
          100,
          priceType: 'A',
        ); // Precio A: 300 en 3 uds.
        await h.sell(
          day(-1),
          p,
          2,
          50,
          priceType: 'B',
        ); // Precio B: 100 en 2 uds.
        await h.refresh();
        await pumpDashboard(tester, only(BiIndicator.salesByPriceType));
        await pickType(tester, BiIndicator.salesByPriceType, BiChartType.bar);

        expect(tooltip, findsNothing);
        await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
        await tester.pump();
        expect(tooltip, findsOneWidget);
        expect(tipTexts(tester), ['Precio A', 'Bs. 300.00', '3 uds.']);

        // Tocar otra barra cambia el globo.
        await tester.tap(find.byKey(const ValueKey('bi-ranking-row-1')));
        await tester.pump();
        expect(tipTexts(tester), ['Precio B', 'Bs. 100.00', '2 uds.']);

        // Y se cierra solo a los pocos segundos.
        await tester.pump(const Duration(seconds: 5));
        expect(tooltip, findsNothing);
      },
    );

    testWidgets(
      'ranking con detalle: el globo sale al mantener presionada la barra',
      (tester) async {
        final s = await DrillSeed.create(h);
        await pumpDashboard(
          tester,
          only(BiIndicator.salesByProduct, filters: s.filters),
        );

        await tester.longPress(find.byKey(const ValueKey('bi-ranking-row-0')));
        await tester.pump();
        expect(tipTexts(tester), ['Anillo', 'Bs. 195.00', '4 uds.']);
        // Tocarla abre el detalle, no el globo.
        await tester.pump(const Duration(seconds: 5));
        await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('bi-drill-title')), findsOneWidget);
      },
    );

    testWidgets(
      'ranking por unidades: el globo repite lo que muestra la barra',
      (tester) async {
        final s = await DrillSeed.create(h);
        await pumpDashboard(
          tester,
          only(BiIndicator.salesByCategory, filters: s.filters),
        );
        await tester.tap(
          inSection(BiIndicator.salesByCategory, find.text('Unidades')),
        );
        await tester.pumpAndSettle();
        await tester.longPress(find.byKey(const ValueKey('bi-ranking-row-0')));
        await tester.pump();
        // Joyas: 5 uds. (la barra muestra las unidades y, debajo, el dinero).
        expect(tipTexts(tester), ['Joyas', '5 uds.', 'Bs. 265.00']);
      },
    );

    testWidgets(
      'barras con pérdidas: el globo da el valor exacto, también el negativo',
      (tester) async {
        final s = await DrillSeed.create(h);
        // Un segundo evento con más gastos que ingresos.
        final feria2 = await h.newEvent('Feria perdida', day(-3), day(-2));
        await h.sell(day(-3), s.cuadro, 1, 40, eventId: feria2);
        await h.spend(day(-3), 100, eventId: feria2);
        await h.refresh();
        await pumpDashboard(
          tester,
          only(BiIndicator.eventProfit, filters: s.filters),
        );

        await tester.tap(find.byKey(const ValueKey('bi-signed-row-0')));
        await tester.pump();
        expect(tipTexts(tester), [
          'Feria',
          'Bs. 219.50',
          'Ingresos Bs. 290.00 (3 ventas) · Gastos Bs. 70.50',
        ]);
        await tester.tap(find.byKey(const ValueKey('bi-signed-row-1')));
        await tester.pump();
        // 40 de ingresos - 100 de gastos.
        expect(tipTexts(tester), [
          'Feria perdida',
          'Bs. -60.00',
          'Ingresos Bs. 40.00 (1 venta) · Gastos Bs. 100.00',
        ]);
      },
    );

    testWidgets(
      'pastel: tocar una rebanada muestra nombre, monto y porcentaje',
      (tester) async {
        final s = await DrillSeed.create(h);
        await pumpDashboard(
          tester,
          only(BiIndicator.salesByProduct, filters: s.filters),
        );
        await pickType(tester, BiIndicator.salesByProduct, BiChartType.pie);

        // Anillo 195, Cuadro 120, Collar 70: total 385. Las rebanadas empiezan a
        // las 3 en punto y siguen las agujas del reloj: Anillo de 0° a 182.3°,
        // Cuadro hasta 294.5° y Collar hasta 360°.
        final pie = find.byType(PieChart);
        final center = tester.getCenter(pie);
        Offset at(double degrees) =>
            center + Offset.fromDirection(degrees * math.pi / 180, 65);

        await tester.tapAt(at(30));
        await tester.pump();
        expect(tipTexts(tester), ['Anillo', 'Bs. 195.00', '50.6%']);
        // La rebanada tocada se resalta.
        var radii = tester
            .widget<PieChart>(pie)
            .data
            .sections
            .map((e) => e.radius);
        expect(radii, [56, 50, 50]);

        await tester.tapAt(at(240));
        await tester.pump();
        expect(tipTexts(tester), ['Cuadro', 'Bs. 120.00', '31.2%']);

        await tester.tapAt(at(330));
        await tester.pump();
        expect(tipTexts(tester), ['Collar', 'Bs. 70.00', '18.2%']);
        radii = tester.widget<PieChart>(pie).data.sections.map((e) => e.radius);
        expect(radii, [50, 50, 56]);

        // Tocar el hueco del centro cierra el globo.
        await tester.tapAt(center);
        await tester.pump();
        expect(tooltip, findsNothing);
        expect(
          tester.widget<PieChart>(pie).data.sections.map((e) => e.radius),
          [50, 50, 50],
        );
      },
    );

    testWidgets('pastel por unidades: el globo da las unidades', (
      tester,
    ) async {
      final s = await DrillSeed.create(h);
      await pumpDashboard(
        tester,
        only(BiIndicator.salesByProduct, filters: s.filters),
      );
      await pickType(tester, BiIndicator.salesByProduct, BiChartType.pie);
      await tester.tap(
        inSection(BiIndicator.salesByProduct, find.text('Unidades')),
      );
      await tester.pumpAndSettle();

      // Unidades: Anillo 4, Cuadro 3, Collar 1 (total 8): 50.0 %, 37.5 %, 12.5 %.
      final center = tester.getCenter(find.byType(PieChart));
      await tester.tapAt(center + Offset.fromDirection(30 * math.pi / 180, 65));
      await tester.pump();
      expect(tipTexts(tester), ['Anillo', '4 uds.', '50.0%']);
    });

    testWidgets(
      'líneas: tocar un intervalo muestra la fecha y el valor de cada serie',
      (tester) async {
        final p = await h.newProduct('Tote bag', stock: 1000);
        await h.sell(day(-1), p, 1, 100);
        await h.sell(day(-3), p, 1, 50);
        await h.spend(day(-2), 30);
        await h.refresh();
        await pumpDashboard(
          tester,
          only(
            BiIndicator.timeSeries,
            filters: ReportFilters(startDate: day(-13), endDate: day(0)),
          ),
        );

        final chart = find.byType(LineChart);
        // 14 intervalos diarios: el día -1 es el 12, el -2 el 11, el -3 el 10.
        await tester.tapAt(linePoint(tester, chart, 12));
        await tester.pump();
        expect(tipTexts(tester), [
          formatDate(day(-1)),
          'Ingresos: Bs. 100.00',
          'Gastos: Bs. 0.00',
        ]);
        // El punto tocado se marca en cada serie.
        var bars = tester.widget<LineChart>(chart).data.lineBarsData;
        expect(
          [for (final b in bars) b.showingIndicators],
          [
            [12],
            [12],
          ],
        );

        await tester.tapAt(linePoint(tester, chart, 11));
        await tester.pump();
        expect(tipTexts(tester), [
          formatDate(day(-2)),
          'Ingresos: Bs. 0.00',
          'Gastos: Bs. 30.00',
        ]);

        await tester.tapAt(linePoint(tester, chart, 10));
        await tester.pump();
        expect(tipTexts(tester), [
          formatDate(day(-3)),
          'Ingresos: Bs. 50.00',
          'Gastos: Bs. 0.00',
        ]);
        bars = tester.widget<LineChart>(chart).data.lineBarsData;
        expect(
          [for (final b in bars) b.showingIndicators],
          [
            [10],
            [10],
          ],
        );
      },
    );

    testWidgets(
      'barras de tiempo: tocar un intervalo muestra los valores de ambas series',
      (tester) async {
        final p = await h.newProduct('Tote bag', stock: 1000);
        await h.sell(day(-1), p, 1, 100);
        await h.spend(day(-1), 40);
        await h.refresh();
        await pumpDashboard(
          tester,
          only(
            BiIndicator.timeSeries,
            filters: ReportFilters(startDate: day(-13), endDate: day(0)),
          ),
        );
        await pickType(tester, BiIndicator.timeSeries, BiChartType.bar);

        final chart = find.byType(BarChart);
        await tester.tapAt(barPoint(tester, chart, 12, 14));
        await tester.pump();
        expect(tipTexts(tester), [
          formatDate(day(-1)),
          'Ingresos: Bs. 100.00',
          'Gastos: Bs. 40.00',
        ]);
      },
    );

    testWidgets('proyección: el globo distingue lo real de la tendencia', (
      tester,
    ) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
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
      await pumpDashboard(tester, only(BiIndicator.salesProjection));

      final chart = find.byType(LineChart);
      // El primer intervalo (hace 16 semanas): lo real vale 300 y aún no hay
      // tendencia.
      await tester.tapAt(linePoint(tester, chart, 0));
      await tester.pump();
      final texts = tipTexts(tester);
      expect(texts.first, startsWith('Semana del '));
      expect(texts.skip(1), ['Ingresos: Bs. 300.00']);

      // Un intervalo proyectado (el último): solo la proyección.
      final last = tester.widget<LineChart>(chart).data.maxX;
      await tester.tapAt(linePoint(tester, chart, last - 0.05));
      await tester.pump();
      expect(tipTexts(tester).skip(1).single, startsWith('Proyección: Bs. '));
    });

    testWidgets(
      'días de la semana: el globo da el día y el valor de la métrica elegida',
      (tester) async {
        final p = await h.newProduct('Tote bag', stock: 1000);
        await h.sell(weekday(DateTime.monday, 1), p, 1, 100);
        await h.sell(weekday(DateTime.monday, 2), p, 1, 20);
        await h.sell(weekday(DateTime.saturday, 1), p, 1, 200);
        await h.refresh();
        await pumpDashboard(tester, only(BiIndicator.weekdaySales));

        final chart = find.byType(BarChart);
        // Lunes: 120 en 2 ventas; sábado: 200 en 1.
        await tester.tapAt(barPoint(tester, chart, 0, 7));
        await tester.pump();
        expect(tipTexts(tester), ['Lunes', 'Bs. 120.00']);
        await tester.tapAt(barPoint(tester, chart, 5, 7));
        await tester.pump();
        expect(tipTexts(tester), ['Sábado', 'Bs. 200.00']);

        await tester.tap(
          inSection(BiIndicator.weekdaySales, find.text('Número de ventas')),
        );
        await tester.pumpAndSettle();
        expect(tooltip, findsNothing); // cambiar de métrica cierra el globo
        await tester.tapAt(barPoint(tester, chart, 0, 7));
        await tester.pump();
        expect(tipTexts(tester), ['Lunes', '2 ventas']);

        // En líneas también.
        await pickType(tester, BiIndicator.weekdaySales, BiChartType.line);
        await tester.tapAt(linePoint(tester, find.byType(LineChart), 5));
        await tester.pump();
        expect(tipTexts(tester), ['Sábado', '1 venta']);
      },
    );

    testWidgets(
      'ticket promedio y descuentos en líneas: el globo da el valor y el detalle',
      (tester) async {
        final p = await h.newProduct('Tote bag', stock: 1000);
        await h.sell(day(-1), p, 1, 100, discount: 20); // neto 80
        await h.sell(day(-1), p, 1, 60); // neto 60
        await h.refresh();
        final filters = ReportFilters(startDate: day(-13), endDate: day(0));
        await pumpDashboard(
          tester,
          BiConfig(
            filters: filters,
            indicators: {BiIndicator.averageTicket, BiIndicator.discountImpact},
          ),
        );
        await pickType(tester, BiIndicator.averageTicket, BiChartType.line);
        await pickType(tester, BiIndicator.discountImpact, BiChartType.line);

        // Ticket del día -1: (80 + 60) / 2 = 70, 2 ventas.
        final ticket = inSection(
          BiIndicator.averageTicket,
          find.byType(LineChart),
        );
        await tester.tapAt(linePoint(tester, ticket, 12));
        await tester.pump();
        expect(tipTexts(tester, BiIndicator.averageTicket), [
          formatDate(day(-1)),
          'Ticket promedio: Bs. 70.00',
          '2 ventas',
        ]);

        // Descuentos del día -1: 20 sobre 160 brutos = 12.5 %.
        final discounts = inSection(
          BiIndicator.discountImpact,
          find.byType(LineChart),
        );
        await tester.tapAt(linePoint(tester, discounts, 12));
        await tester.pump();
        expect(tipTexts(tester, BiIndicator.discountImpact), [
          formatDate(day(-1)),
          'Descuentos: Bs. 20.00',
          '12.5% de las ventas brutas',
        ]);
      },
    );

    testWidgets('comparación entre periodos: el globo da actual y anterior', (
      tester,
    ) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
      await h.sell(day(-1), p, 3, 100); // periodo actual: 300
      await h.sell(day(-8), p, 1, 100); // periodo anterior: 100
      await h.spend(day(-9), 40);
      await h.refresh();
      await pumpDashboard(
        tester,
        only(
          BiIndicator.periodComparison,
          filters: ReportFilters(startDate: day(-6), endDate: day(0)),
        ),
      );
      await pickType(tester, BiIndicator.periodComparison, BiChartType.bar);

      final chart = find.byType(BarChart);
      // Grupos: Ingresos, Gastos, Balance (con el eje inferior de 28 dp).
      await tester.tapAt(barPoint(tester, chart, 0, 3, axis: 28));
      await tester.pump();
      expect(tipTexts(tester), [
        'Ingresos',
        'Actual: Bs. 300.00',
        'Anterior: Bs. 100.00',
      ]);
      await tester.tapAt(barPoint(tester, chart, 1, 3, axis: 28));
      await tester.pump();
      expect(tipTexts(tester), [
        'Gastos',
        'Actual: Bs. 0.00',
        'Anterior: Bs. 40.00',
      ]);
    });

    testWidgets(
      'radar: tocar un vértice da el producto, el eje y su valor real',
      (tester) async {
        final a = await h.newProduct('Estuches', productionCost: 10, stock: 10);
        final b = await h.newProduct('Libro', productionCost: 20, stock: 10);
        await h.sell(day(0), a, 4, 50); // 200, 4 uds.
        await h.sell(day(0), b, 1, 100); // 100, 1 ud.
        await h.refresh();
        await pumpDashboard(tester, only(BiIndicator.productRadar));

        // Valores normalizados (0 a 1) de cada eje: Ingresos, Margen, Unidades,
        // Rotación.
        //   Estuches: 200/200 = 1, (200-40)/200 = 0.8, 4/4 = 1, 4/(4+6) = 0.4
        //   Libro:    100/200 = 0.5, (100-20)/100 = 0.8, 1/4 = 0.25, 1/(1+9) = 0.1
        final chart = find.byType(RadarChart);
        final rect = tester.getRect(chart);
        final radius = math.min(rect.width, rect.height) / 2 * 0.8;
        Offset vertex(int axis, double value) =>
            rect.center +
            Offset.fromDirection(
              math.pi / 2 * axis - math.pi / 2,
              radius * value,
            );
        Future<void> tapVertex(int axis, double value) async {
          await tester.tapAt(vertex(axis, value));
          await tester.pump();
        }

        // La punta de Ingresos y la de Unidades es donde está el mejor
        // producto, justo donde el conjunto invisible que fija la escala
        // también tiene su vértice: tiene que ganar el producto.
        await tapVertex(0, 1);
        expect(tipTexts(tester), ['Estuches', 'Ingresos: Bs. 200.00']);
        await tapVertex(2, 1);
        expect(tipTexts(tester), ['Estuches', 'Unidades: 4 uds.']);
        await tapVertex(3, 0.4);
        // Rotación: 4 / (4 + 6 de stock, ya sin lo vendido) = 40 %.
        expect(tipTexts(tester), ['Estuches', 'Rotación: 40.0%']);
        await tapVertex(2, 0.25);
        expect(tipTexts(tester), ['Libro', 'Unidades: 1 uds.']);
        await tapVertex(3, 0.1);
        expect(tipTexts(tester), ['Libro', 'Rotación: 10.0%']);
        // Dos productos con el mismo vértice (margen 80 %): el que se dibuja
        // encima, que es el último.
        await tapVertex(1, 0.8);
        expect(tipTexts(tester), ['Libro', 'Margen: 80.0%']);

        // Una punta sin ningún producto no abre globo y cierra el anterior.
        await tapVertex(3, 1);
        expect(tooltip, findsNothing);
        // Tocar donde no hay nada tampoco.
        await tapVertex(0, 1);
        expect(tooltip, findsOneWidget);
        await tester.tapAt(vertex(1, 0.3));
        await tester.pump();
        expect(tooltip, findsNothing);

        // Con un producto oculto ya no se puede tocar su vértice.
        await tester.tap(find.byKey(const ValueKey('bi-radar-legend-0')));
        await tester.pumpAndSettle();
        await tapVertex(0, 1);
        expect(tooltip, findsNothing);
        await tapVertex(0, 0.5);
        expect(tipTexts(tester), ['Libro', 'Ingresos: Bs. 100.00']);
      },
    );

    testWidgets('la marca del punto tocado desaparece con el globo', (
      tester,
    ) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
      await h.sell(day(-1), p, 1, 100);
      await h.sell(day(-3), p, 1, 50);
      await h.refresh();
      await pumpDashboard(
        tester,
        BiConfig(
          filters: ReportFilters(startDate: day(-13), endDate: day(0)),
          indicators: {
            BiIndicator.timeSeries,
            BiIndicator.weekdaySales,
            BiIndicator.salesByProduct,
          },
        ),
      );
      List<List<int>> markers() => [
        for (final b
            in tester
                .widget<LineChart>(
                  inSection(BiIndicator.timeSeries, find.byType(LineChart)),
                )
                .data
                .lineBarsData)
          b.showingIndicators,
      ];

      // Líneas: el punto del intervalo 12 queda marcado mientras dura el globo.
      final line = inSection(BiIndicator.timeSeries, find.byType(LineChart));
      await tester.tapAt(linePoint(tester, line, 12));
      await tester.pump();
      expect(markers(), [
        [12],
        [12],
      ]);
      await tester.pump(const Duration(seconds: 5));
      expect(tooltip, findsNothing);
      expect(markers(), [<int>[], <int>[]]);

      // Barras de los días de la semana: la barra tocada deja de atenuar a las
      // demás cuando el globo se va.
      final weekday = inSection(
        BiIndicator.weekdaySales,
        find.byType(BarChart),
      );
      List<Color?> colors() => [
        for (final g in tester.widget<BarChart>(weekday).data.barGroups)
          g.barRods.single.color,
      ];
      await tester.ensureVisible(weekday);
      await tester.pump();
      await tester.tapAt(barPoint(tester, weekday, 2, 7));
      await tester.pump();
      expect(colors().toSet().length, greaterThan(1));
      await tester.pump(const Duration(seconds: 5));
      expect(colors().toSet(), {chartColorAt(0)});

      // Y al cambiar de barras a líneas no queda ninguna marca colgada.
      await tester.tapAt(barPoint(tester, weekday, 2, 7));
      await tester.pump();
      await pickType(tester, BiIndicator.weekdaySales, BiChartType.line);
      final weekdayLine = tester.widget<LineChart>(
        inSection(BiIndicator.weekdaySales, find.byType(LineChart)),
      );
      expect(weekdayLine.data.lineBarsData.single.showingIndicators, isEmpty);
      expect(tooltip, findsNothing);
    });

    testWidgets(
      'la rebanada resaltada del pastel vuelve a su tamaño con el globo',
      (tester) async {
        final s = await DrillSeed.create(h);
        await pumpDashboard(
          tester,
          only(BiIndicator.salesByProduct, filters: s.filters),
        );
        await pickType(tester, BiIndicator.salesByProduct, BiChartType.pie);
        final pie = find.byType(PieChart);
        await tester.tapAt(
          tester.getCenter(pie) + Offset.fromDirection(30 * math.pi / 180, 65),
        );
        await tester.pump();
        expect(
          tester.widget<PieChart>(pie).data.sections.map((e) => e.radius),
          [56, 50, 50],
        );
        await tester.pump(const Duration(seconds: 5));
        expect(tooltip, findsNothing);
        expect(
          tester.widget<PieChart>(pie).data.sections.map((e) => e.radius),
          [50, 50, 50],
        );
      },
    );

    testWidgets('mover o acercar el gráfico quita la marca y el globo', (
      tester,
    ) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
      for (var k = 1; k <= 12; k++) {
        await h.sell(day(-k), p, 1, 10.0 * k);
      }
      await h.refresh();
      await pumpDashboard(
        tester,
        only(
          BiIndicator.timeSeries,
          filters: ReportFilters(startDate: day(-13), endDate: day(0)),
        ),
      );
      final line = find.byType(LineChart);
      await tester.tapAt(linePoint(tester, line, 6));
      await tester.pump();
      expect(tooltip, findsOneWidget);
      expect(
        tester
            .widget<LineChart>(line)
            .data
            .lineBarsData
            .first
            .showingIndicators,
        [6],
      );

      final center = tester.getCenter(line);
      final a = await tester.startGesture(
        center + const Offset(-30, 0),
        pointer: 1,
      );
      final b = await tester.startGesture(
        center + const Offset(30, 0),
        pointer: 2,
      );
      for (var i = 0; i < 6; i++) {
        await a.moveBy(const Offset(-10, 0));
        await b.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pump();
      expect(tooltip, findsNothing);
      for (final bar in tester.widget<LineChart>(line).data.lineBarsData) {
        expect(bar.showingIndicators, isEmpty);
      }
    });

    testWidgets('un globo sin cantidad no deja una línea vacía', (
      tester,
    ) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
      await h.sell(day(-1), p, 2, 100); // ingresos 200
      final mat = await h.newMaterial('Hilo');
      await h.buyMaterial(day(-1), mat, 10, 5); // materiales 50
      await h.refresh();
      await pumpDashboard(tester, only(BiIndicator.materialCostRatio));
      await pickType(tester, BiIndicator.materialCostRatio, BiChartType.bar);
      await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
      await tester.pump();
      // Esta barra no tiene cantidad: solo el nombre y el monto.
      expect(tipTexts(tester), ['Ingresos por ventas', 'Bs. 200.00']);
      await tester.tap(find.byKey(const ValueKey('bi-ranking-row-1')));
      await tester.pump();
      expect(tipTexts(tester), ['Compras de materiales', 'Bs. 50.00']);
    });

    testWidgets('el globo no se sale del gráfico en una pantalla de 360 dp', (
      tester,
    ) async {
      final s = await DrillSeed.create(h);
      await pumpDashboard(
        tester,
        only(BiIndicator.salesByProduct, filters: s.filters),
        size: const Size(360, 3000),
      );
      await tester.longPress(find.byKey(const ValueKey('bi-ranking-row-0')));
      await tester.pump();
      final rect = tester.getRect(tooltip);
      final layer = tester.getRect(find.byType(BiTooltipLayer).first);
      expect(rect.left, greaterThanOrEqualTo(layer.left));
      expect(rect.right, lessThanOrEqualTo(layer.right));
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------
  // Animación de entrada
  // ---------------------------------------------------------------------

  group('animación de entrada', () {
    double barFactor(WidgetTester tester, int i) => tester
        .widget<FractionallySizedBox>(
          find.ancestor(
            of: find.byKey(ValueKey('bi-bar-$i')),
            matching: find.byType(FractionallySizedBox),
          ),
        )
        .widthFactor!;

    testWidgets('las barras crecen en unos 700 ms hasta su largo final', (
      tester,
    ) async {
      final s = await DrillSeed.create(h);
      await pumpDashboard(
        tester,
        only(BiIndicator.salesByProduct, filters: s.filters),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 1));
      // Al empezar, la barra mayor casi no se ve.
      expect(barFactor(tester, 0), lessThan(0.1));

      await tester.pump(const Duration(milliseconds: 250));
      final mid = barFactor(tester, 0);
      expect(mid, greaterThan(0.1));
      expect(mid, lessThan(1.0));

      await tester.pump(const Duration(milliseconds: 550));
      // 800 ms después terminó: la barra mayor ocupa todo el ancho.
      expect(barFactor(tester, 0), 1.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets(
      'las barras de tiempo crecen desde cero y terminan en su valor',
      (tester) async {
        final p = await h.newProduct('Tote bag', stock: 1000);
        await h.sell(day(-1), p, 1, 100);
        await h.refresh();
        await pumpDashboard(
          tester,
          only(
            BiIndicator.timeSeries,
            filters: ReportFilters(startDate: day(-13), endDate: day(0)),
          ),
        );
        await pickType(tester, BiIndicator.timeSeries, BiChartType.bar);
        // Cambiar el tipo de gráfico vuelve a reproducir la animación: justo
        // después las barras casi no se ven; al terminar valen lo que valen.
        await tester.tap(
          inSection(
            BiIndicator.timeSeries,
            find.byKey(const ValueKey('bi-chart-type-line')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          inSection(
            BiIndicator.timeSeries,
            find.byKey(const ValueKey('bi-chart-type-bar')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        double toY() => tester
            .widget<BarChart>(find.byType(BarChart))
            .data
            .barGroups[12]
            .barRods[0]
            .toY;
        expect(toY(), lessThan(10));
        await tester.pump(const Duration(milliseconds: 300));
        expect(toY(), allOf(greaterThan(10), lessThan(100)));
        await tester.pump(const Duration(milliseconds: 600));
        expect(toY(), 100);
      },
    );

    testWidgets(
      'las líneas se dibujan de izquierda a derecha y el pastel se barre',
      (tester) async {
        final s = await DrillSeed.create(h);
        await pumpDashboard(
          tester,
          BiConfig(
            filters: s.filters,
            indicators: {BiIndicator.timeSeries, BiIndicator.salesByProduct},
          ),
        );
        await pickType(tester, BiIndicator.salesByProduct, BiChartType.pie);
        // Cambia a barras y vuelve a líneas: la animación corre de nuevo.
        await pickType(tester, BiIndicator.timeSeries, BiChartType.bar);
        await tester.tap(
          inSection(
            BiIndicator.timeSeries,
            find.byKey(const ValueKey('bi-chart-type-line')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.descendant(
            of: section(BiIndicator.timeSeries),
            matching: find.byType(ClipRect),
          ),
          findsWidgets,
        );
        final revealed = tester.getRect(
          find.descendant(
            of: section(BiIndicator.timeSeries),
            matching: find.byType(LineChart),
          ),
        );
        final clip = tester.renderObject<RenderBox>(
          find
              .descendant(
                of: section(BiIndicator.timeSeries),
                matching: find.ancestor(
                  of: find.byType(LineChart),
                  matching: find.byType(ClipRect),
                ),
              )
              .first,
        );
        expect(clip.size.width, closeTo(revealed.width, 1));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: section(BiIndicator.timeSeries),
            matching: find.ancestor(
              of: find.byType(LineChart),
              matching: find.byType(ClipRect),
            ),
          ),
          findsNothing,
        );

        // El pastel: mientras corre hay un recorte en abanico; después ninguno.
        await tester.tap(
          inSection(
            BiIndicator.salesByProduct,
            find.byKey(const ValueKey('bi-chart-type-bar')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          inSection(
            BiIndicator.salesByProduct,
            find.byKey(const ValueKey('bi-chart-type-pie')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.descendant(
            of: section(BiIndicator.salesByProduct),
            matching: find.byType(ClipPath),
          ),
          findsWidgets,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: section(BiIndicator.salesByProduct),
            matching: find.ancestor(
              of: find.byType(PieChart),
              matching: find.byType(ClipPath),
            ),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('cambiar el tipo de gráfico vuelve a reproducirla', (
      tester,
    ) async {
      final s = await DrillSeed.create(h);
      await pumpDashboard(
        tester,
        only(BiIndicator.salesByProduct, filters: s.filters),
      );
      expect(barFactor(tester, 0), 1.0);
      await pickType(tester, BiIndicator.salesByProduct, BiChartType.pie);
      await tester.tap(
        inSection(
          BiIndicator.salesByProduct,
          find.byKey(const ValueKey('bi-chart-type-bar')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(barFactor(tester, 0), lessThan(0.1));
      await tester.pumpAndSettle();
      expect(barFactor(tester, 0), 1.0);
    });

    testWidgets(
      'el radar, los días de la semana y las barras agrupadas también entran animados',
      (tester) async {
        final s = await DrillSeed.create(h);
        await pumpDashboard(
          tester,
          BiConfig(
            filters: s.filters,
            indicators: {
              BiIndicator.productRadar,
              BiIndicator.weekdaySales,
              BiIndicator.periodComparison,
            },
          ),
          settle: false,
        );
        await tester.pump(const Duration(milliseconds: 1));

        // Radar: Anillo es el de más ingresos (ingresos normalizados = 1).
        double radarRevenue() => tester
            .widget<RadarChart>(find.byType(RadarChart))
            .data
            .dataSets[1]
            .dataEntries
            .first
            .value;
        expect(radarRevenue(), lessThan(0.1));

        // Días de la semana: la barra mayor empieza casi en cero.
        double tallestWeekday() {
          final chart = tester.widget<BarChart>(
            inSection(BiIndicator.weekdaySales, find.byType(BarChart)),
          );
          return [
            for (final g in chart.data.barGroups) g.barRods.single.toY,
          ].reduce(math.max);
        }

        final startWeekday = tallestWeekday();

        await tester.pump(const Duration(milliseconds: 900));
        expect(radarRevenue(), 1.0);
        final endWeekday = tallestWeekday();
        expect(endWeekday, greaterThan(0));
        expect(startWeekday, lessThan(endWeekday * 0.1));

        // Barras agrupadas: al elegirlas arrancan desde cero.
        await tester.tap(
          inSection(
            BiIndicator.periodComparison,
            find.byKey(const ValueKey('bi-chart-type-bar')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        double firstRod() => tester
            .widget<BarChart>(
              inSection(BiIndicator.periodComparison, find.byType(BarChart)),
            )
            .data
            .barGroups
            .first
            .barRods
            .first
            .toY;
        expect(firstRod(), lessThan(10));
        await tester.pump(const Duration(milliseconds: 900));
        // Ingresos del periodo actual: 195 + 70 + 120 = 385.
        expect(firstRod(), 385);
      },
    );

    testWidgets('con "reducir animaciones" todo aparece de inmediato', (
      tester,
    ) async {
      final s = await DrillSeed.create(h);
      await pumpDashboard(
        tester,
        BiConfig(
          filters: s.filters,
          indicators: {BiIndicator.salesByProduct, BiIndicator.timeSeries},
        ),
        reduceMotion: true,
        settle: false,
      );
      // Un solo cuadro después de entrar al panel ya está todo completo.
      expect(barFactor(tester, 0), 1.0);
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        find.descendant(
          of: section(BiIndicator.timeSeries),
          matching: find.byType(LineChart),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: section(BiIndicator.timeSeries),
          matching: find.ancestor(
            of: find.byType(LineChart),
            matching: find.byType(ClipRect),
          ),
        ),
        findsNothing,
      );
      // También al cambiar de tipo de gráfico.
      await tester.tap(
        inSection(
          BiIndicator.salesByProduct,
          find.byKey(const ValueKey('bi-chart-type-pie')),
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: section(BiIndicator.salesByProduct),
          matching: find.ancestor(
            of: find.byType(PieChart),
            matching: find.byType(ClipPath),
          ),
        ),
        findsNothing,
      );
    });
  });

  // ---------------------------------------------------------------------
  // Zoom y arrastre en las líneas
  // ---------------------------------------------------------------------

  group('zoom y arrastre', () {
    Future<void> pumpSeries(WidgetTester tester) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
      for (var k = 1; k <= 12; k++) {
        await h.sell(day(-k), p, 1, 10.0 * k);
      }
      await h.refresh();
      await pumpDashboard(
        tester,
        only(
          BiIndicator.timeSeries,
          filters: ReportFilters(startDate: day(-13), endDate: day(0)),
        ),
      );
    }

    LineChart lineChart(WidgetTester tester) =>
        tester.widget<LineChart>(find.byType(LineChart));

    Future<void> pinch(
      WidgetTester tester, {
      required double from,
      required double to,
    }) async {
      final center = tester.getCenter(find.byType(LineChart));
      final a = await tester.startGesture(
        center + Offset(-from / 2, 0),
        pointer: 1,
      );
      final b = await tester.startGesture(
        center + Offset(from / 2, 0),
        pointer: 2,
      );
      final steps = 6;
      for (var i = 1; i <= steps; i++) {
        final d = (to - from) / 2 / steps;
        await a.moveBy(Offset(-d, 0));
        await b.moveBy(Offset(d, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pump();
    }

    testWidgets(
      'empieza con todo el periodo, con una pista y sin botón de restablecer',
      (tester) async {
        await pumpSeries(tester);
        expect(lineChart(tester).data.minX, 0);
        expect(lineChart(tester).data.maxX, 13);
        expect(find.byKey(const ValueKey('bi-zoom-hint')), findsOneWidget);
        expect(find.byKey(const ValueKey('bi-zoom-reset')), findsNothing);
        // 14 intervalos: unas 5 etiquetas, una por cada 3.
        expect(lineChart(tester).data.clipData.any, isFalse);
      },
    );

    testWidgets(
      'pellizcar acerca, el eje de abajo sigue la ventana y se puede restablecer',
      (tester) async {
        await pumpSeries(tester);
        await pinch(tester, from: 60, to: 180);

        final data = lineChart(tester).data;
        final span = data.maxX - data.minX;
        // El triple de separación entre dedos: un tercio del ancho (13 / 3).
        expect(span, closeTo(13 / 3, 0.05));
        expect(data.minX, greaterThan(0));
        expect(data.maxX, lessThanOrEqualTo(13));
        // Lo que queda fuera de la ventana se recorta.
        expect(data.clipData.any, isTrue);
        expect(find.byKey(const ValueKey('bi-zoom-reset')), findsOneWidget);
        expect(find.byKey(const ValueKey('bi-zoom-hint')), findsNothing);

        // Las etiquetas del eje son de la parte visible, unas pocas y pegadas a
        // su intervalo: 5 intervalos visibles, una por cada intervalo.
        final labels = [
          for (final t in tester.widgetList<Text>(
            find.descendant(
              of: find.byType(BiZoomableTimeChart),
              matching: find.byType(Text),
            ),
          ))
            t.data!,
        ].where((s) => RegExp(r'^\d\d/\d\d$').hasMatch(s)).toList();
        expect(labels.length, inInclusiveRange(3, 6));
        final visibleDays = {
          for (var i = data.minX.ceil(); i <= data.maxX.floor(); i++)
            bucketLabel(day(i - 13)),
        };
        expect(
          visibleDays.containsAll(labels),
          isTrue,
          reason: '$labels vs $visibleDays',
        );

        await tester.tap(find.byKey(const ValueKey('bi-zoom-reset')));
        await tester.pump();
        expect(lineChart(tester).data.minX, 0);
        expect(lineChart(tester).data.maxX, 13);
        expect(find.byKey(const ValueKey('bi-zoom-reset')), findsNothing);
        expect(find.byKey(const ValueKey('bi-zoom-hint')), findsOneWidget);
        expect(lineChart(tester).data.clipData.any, isFalse);
      },
    );

    testWidgets('arrastrar con un dedo mueve la ventana sin cambiar su ancho', (
      tester,
    ) async {
      await pumpSeries(tester);
      // Sin zoom, arrastrar no hace nada.
      final center = tester.getCenter(find.byType(LineChart));
      await tester.dragFrom(center, const Offset(-120, 0));
      await tester.pump();
      expect(lineChart(tester).data.minX, 0);
      expect(lineChart(tester).data.maxX, 13);

      await pinch(tester, from: 60, to: 180);
      final before = lineChart(tester).data;
      final width = before.maxX - before.minX;

      // Arrastrar a la izquierda lleva la ventana hacia lo más reciente...
      await tester.dragFrom(center, const Offset(-60, 0));
      await tester.pump();
      var after = lineChart(tester).data;
      expect(after.maxX - after.minX, closeTo(width, 1e-6));
      expect(after.minX, greaterThan(before.minX));
      expect(after.maxX, lessThanOrEqualTo(13 + 1e-9));

      // ...y a la derecha, hacia lo más antiguo.
      final moved = after.minX;
      await tester.dragFrom(center, const Offset(120, 0));
      await tester.pump();
      after = lineChart(tester).data;
      expect(after.minX, lessThan(moved));
      expect(after.minX, greaterThanOrEqualTo(0));

      // Arrastrar mucho no se sale del periodo.
      await tester.dragFrom(center, const Offset(1000, 0));
      await tester.pump();
      expect(lineChart(tester).data.minX, 0);
      await tester.dragFrom(center, const Offset(-2000, 0));
      await tester.pump();
      expect(lineChart(tester).data.maxX, closeTo(13, 1e-9));
    });

    testWidgets(
      'el zoom no pasa de todo el periodo ni de unos pocos intervalos',
      (tester) async {
        await pumpSeries(tester);
        // Alejar los dedos no puede mostrar más que el periodo completo.
        await pinch(tester, from: 180, to: 60);
        expect(lineChart(tester).data.minX, 0);
        expect(lineChart(tester).data.maxX, 13);
        expect(find.byKey(const ValueKey('bi-zoom-reset')), findsNothing);
        // Acercar mucho se detiene en 2 intervalos.
        await pinch(tester, from: 20, to: 800);
        final data = lineChart(tester).data;
        expect(
          data.maxX - data.minX,
          closeTo(BiZoomableTimeChart.minVisibleSpan, 1e-6),
        );
      },
    );

    testWidgets(
      'tocar un punto con zoom da el valor correcto y mover la vista cierra el globo',
      (tester) async {
        await pumpSeries(tester);
        await pinch(tester, from: 60, to: 180);
        final data = lineChart(tester).data;
        final chart = find.byType(LineChart);
        // Un intervalo entero dentro de la ventana.
        final i = data.minX.ceil() + 1;
        await tester.tapAt(linePoint(tester, chart, i.toDouble()));
        await tester.pump();
        // El día (i - 13) tiene una venta de 10 × (13 - i) (día -k vale 10 k).
        final k = 13 - i;
        expect(tipTexts(tester), [
          formatDate(day(-k)),
          'Ingresos: Bs. ${(10.0 * k).toStringAsFixed(2)}',
          'Gastos: Bs. 0.00',
        ]);
        await tester.dragFrom(tester.getCenter(chart), const Offset(-40, 0));
        await tester.pump();
        expect(tooltip, findsNothing);
      },
    );

    testWidgets(
      'proyección, ticket y descuentos también tienen zoom y restablecer',
      (tester) async {
        final p = await h.newProduct('Tote bag', stock: 1000);
        for (var k = 1; k <= 12; k++) {
          await h.sell(day(-k), p, 1, 10.0 * k, discount: 1);
        }
        await h.refresh();
        await pumpDashboard(
          tester,
          BiConfig(
            filters: ReportFilters(startDate: day(-13), endDate: day(0)),
            indicators: {BiIndicator.averageTicket, BiIndicator.discountImpact},
          ),
        );
        for (final i in [
          BiIndicator.averageTicket,
          BiIndicator.discountImpact,
        ]) {
          await pickType(tester, i, BiChartType.line);
          final chart = inSection(i, find.byType(LineChart));
          final center = tester.getCenter(chart);
          final a = await tester.startGesture(
            center + const Offset(-30, 0),
            pointer: 1,
          );
          final b = await tester.startGesture(
            center + const Offset(30, 0),
            pointer: 2,
          );
          for (var s = 0; s < 6; s++) {
            await a.moveBy(const Offset(-10, 0));
            await b.moveBy(const Offset(10, 0));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await a.up();
          await b.up();
          await tester.pump();
          final zoomed = tester.widget<LineChart>(chart).data;
          expect(zoomed.maxX - zoomed.minX, lessThan(13), reason: i.name);
          final reset = inSection(
            i,
            find.byKey(const ValueKey('bi-zoom-reset')),
          );
          expect(reset, findsOneWidget, reason: i.name);
          await tester.tap(reset);
          await tester.pump();
          final restored = tester.widget<LineChart>(chart).data;
          expect([restored.minX, restored.maxX], [0, 13], reason: i.name);
        }

        // La proyección.
        final weekly = h.now;
        final monday = DateTime(
          weekly.year,
          weekly.month,
          weekly.day - (weekly.weekday - 1),
          12,
        );
        final q = await h.newProduct('Libro', stock: 1000);
        for (var k = 16; k >= 1; k--) {
          await h.sell(
            DateTime(monday.year, monday.month, monday.day - 7 * k + 2, 12),
            q,
            1,
            300.0 + 40 * (16 - k),
          );
        }
        await h.refresh();
        await pumpDashboard(tester, only(BiIndicator.salesProjection));
        final chart = find.byType(LineChart);
        final full = tester.widget<LineChart>(chart).data;
        final center = tester.getCenter(chart);
        final a = await tester.startGesture(
          center + const Offset(-30, 0),
          pointer: 1,
        );
        final b = await tester.startGesture(
          center + const Offset(30, 0),
          pointer: 2,
        );
        for (var s = 0; s < 6; s++) {
          await a.moveBy(const Offset(-10, 0));
          await b.moveBy(const Offset(10, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await a.up();
        await b.up();
        await tester.pump();
        expect(
          tester.widget<LineChart>(chart).data.maxX -
              tester.widget<LineChart>(chart).data.minX,
          lessThan(full.maxX),
        );
        await tester.tap(find.byKey(const ValueKey('bi-zoom-reset')));
        await tester.pump();
        expect(tester.widget<LineChart>(chart).data.minX, 0);
        expect(tester.widget<LineChart>(chart).data.maxX, full.maxX);
      },
    );

    testWidgets('un periodo corto no ofrece zoom', (tester) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
      await h.sell(day(-1), p, 1, 100);
      await h.sell(day(0), p, 1, 50);
      await h.refresh();
      await pumpDashboard(
        tester,
        only(
          BiIndicator.timeSeries,
          filters: ReportFilters(startDate: day(-2), endDate: day(0)),
        ),
      );
      // Solo 3 intervalos: no hay nada que acercar.
      expect(find.byKey(const ValueKey('bi-zoom-hint')), findsNothing);
      expect(find.byKey(const ValueKey('bi-zoom-reset')), findsNothing);
    });
  });

  // ---------------------------------------------------------------------
  // Detalle de las barras (hoja inferior)
  // ---------------------------------------------------------------------

  group('detalle de una barra', () {
    Text stat(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(ValueKey('bi-drill-stat-$key')));

    String rowText(WidgetTester tester, String key) => [
      for (final t in tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      ))
        t.data!,
    ].join(' | ');

    testWidgets(
      'producto: ingresos y unidades en el tiempo, con los filtros del panel',
      (tester) async {
        final s = await DrillSeed.create(h);
        await pumpDashboard(
          tester,
          only(BiIndicator.salesByProduct, filters: s.filters),
        );

        expect(
          find.byIcon(Icons.chevron_right),
          findsWidgets,
        ); // las barras avisan que abren algo
        await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('bi-drill-title')), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('bi-drill-title')))
              .data,
          'Anillo',
        );
        expect(stat(tester, 'revenue').data, 'Bs. 195.00');
        expect(stat(tester, 'units').data, '4 uds.');
        expect(stat(tester, 'count').data, '3');

        // Tres intervalos con movimiento, de más antiguo a más reciente.
        expect(
          rowText(tester, 'bi-drill-bucket-0'),
          '${formatDate(day(-5))} | Bs. 50.00 · 1 uds. · 1 venta',
        );
        expect(
          rowText(tester, 'bi-drill-bucket-1'),
          '${formatDate(day(-1))} | Bs. 100.00 · 2 uds. · 1 venta',
        );
        expect(
          rowText(tester, 'bi-drill-bucket-2'),
          '${formatDate(day(0))} | Bs. 45.00 · 1 uds. · 1 venta',
        );
        expect(find.byKey(const ValueKey('bi-drill-bucket-3')), findsNothing);

        // El gráfico: ingresos por día y, al alternar, unidades.
        List<double> rods() => [
          for (final g
              in tester
                  .widget<BarChart>(
                    find.descendant(
                      of: find.byKey(const ValueKey('bi-drill-over-time')),
                      matching: find.byType(BarChart),
                    ),
                  )
                  .data
                  .barGroups)
            g.barRods.single.toY,
        ];
        expect(rods().length, 14);
        expect(rods()[8], 50); // día -5
        expect(rods()[12], 100); // día -1
        expect(rods()[13], 45); // hoy
        expect(rods().where((v) => v > 0).length, 3);
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('bi-drill-over-time')),
            matching: find.text('Unidades'),
          ),
        );
        await tester.pumpAndSettle();
        expect(rods()[8], 1);
        expect(rods()[12], 2);
        expect(rods()[13], 1);

        // Cerrar vuelve al panel.
        await tester.tap(find.byKey(const ValueKey('bi-drill-close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('bi-drill-title')), findsNothing);
      },
    );

    testWidgets(
      'producto: respeta los filtros (otro producto, otro periodo) y no cuenta lo cancelado ni lo futuro',
      (tester) async {
        final s = await DrillSeed.create(h);
        // Solo el día -1: el Anillo vendió 2 uds. por Bs. 100 (y el Collar 1).
        await pumpDashboard(
          tester,
          only(
            BiIndicator.salesByProduct,
            filters: ReportFilters(startDate: day(-1)),
          ),
        );
        // Anillo (100) y Collar (70): el primero.
        await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
        await tester.pumpAndSettle();
        expect(stat(tester, 'revenue').data, 'Bs. 100.00');
        expect(stat(tester, 'units').data, '2 uds.');
        expect(stat(tester, 'count').data, '1');
        expect(find.byKey(const ValueKey('bi-drill-bucket-1')), findsNothing);
        expect(s.anillo, isNotNull);
      },
    );

    testWidgets('categoría: sus productos de mayor a menor ingreso', (
      tester,
    ) async {
      final s = await DrillSeed.create(h);
      await pumpDashboard(
        tester,
        only(BiIndicator.salesByCategory, filters: s.filters),
      );
      // Joyas 265 y Arte 120.
      await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('bi-drill-title'))).data,
        'Joyas',
      );
      expect(stat(tester, 'revenue').data, 'Bs. 265.00');
      expect(stat(tester, 'units').data, '5 uds.');
      expect(stat(tester, 'count').data, '2');
      // 195 / 265 = 73.6 %, 70 / 265 = 26.4 %.
      expect(
        rowText(tester, 'bi-drill-product-0'),
        '1 | Anillo | Bs. 195.00 | 4 uds. · 73.6% de la categoría',
      );
      expect(
        rowText(tester, 'bi-drill-product-1'),
        '2 | Collar | Bs. 70.00 | 1 uds. · 26.4% de la categoría',
      );
      expect(find.byKey(const ValueKey('bi-drill-product-2')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('bi-drill-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bi-ranking-row-1')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('bi-drill-title'))).data,
        'Arte',
      );
      expect(stat(tester, 'revenue').data, 'Bs. 120.00');
      expect(
        rowText(tester, 'bi-drill-product-0'),
        '1 | Cuadro | Bs. 120.00 | 3 uds. · 100.0% de la categoría',
      );
    });

    testWidgets('evento: ventas y gastos vinculados, resumidos', (
      tester,
    ) async {
      final s = await DrillSeed.create(h);
      await pumpDashboard(
        tester,
        only(BiIndicator.salesByEvent, filters: s.filters),
      );
      await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('bi-drill-title'))).data,
        'Feria',
      );
      expect(stat(tester, 'income').data, 'Bs. 290.00');
      expect(find.text('Ingresos (3 ventas)'), findsOneWidget);
      expect(stat(tester, 'expenses').data, 'Bs. 70.50');
      expect(find.text('Gastos (2 compras)'), findsOneWidget);
      expect(stat(tester, 'profit').data, 'Bs. 219.50');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('bi-drill-expense-split')))
            .data,
        'Gastos generales Bs. 40.50 · Compras de materiales Bs. 30.00',
      );
      // Ventas: la D (día -5), la A y la B (día -1, ya sin su descuento).
      expect(
        rowText(tester, 'bi-drill-sale-0'),
        'Sin nombre | ${formatDate(day(-5))} | Bs. 120.00',
      );
      expect(find.byKey(const ValueKey('bi-drill-sale-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('bi-drill-sale-3')), findsNothing);
      // Gastos: los materiales (día -3) y el general (día -2).
      expect(
        rowText(tester, 'bi-drill-expense-0'),
        'Hilo | ${formatDate(day(-3))} · Materiales | Bs. 30.00',
      );
      expect(
        rowText(tester, 'bi-drill-expense-1'),
        'Participación en feria | ${formatDate(day(-2))} · Gasto general | Bs. 40.50',
      );
      expect(find.byKey(const ValueKey('bi-drill-expense-2')), findsNothing);
    });

    testWidgets('evento con pérdida: el resultado sale en rojo', (
      tester,
    ) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
      final feria = await h.newEvent('Feria cara', day(-2), day(-1));
      await h.sell(day(-1), p, 1, 50, eventId: feria);
      await h.spend(day(-2), 120, eventId: feria);
      await h.refresh();
      await pumpDashboard(tester, only(BiIndicator.salesByEvent));
      await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
      await tester.pumpAndSettle();
      expect(stat(tester, 'profit').data, 'Bs. -70.00');
      expect(stat(tester, 'profit').style?.color, AppColors.error);
      expect(find.text('Ingresos (1 venta)'), findsOneWidget);
      expect(find.text('Gastos (1 compra)'), findsOneWidget);
    });

    testWidgets('material: sus compras en el tiempo', (tester) async {
      final s = await DrillSeed.create(h);
      final unit = h.container.read(unitProvider).units.first.name;
      await pumpDashboard(
        tester,
        only(BiIndicator.purchasesByMaterial, filters: s.filters),
      );
      // Hilo 50 y Cuerda 20.
      await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('bi-drill-title'))).data,
        'Hilo',
      );
      expect(stat(tester, 'spend').data, 'Bs. 50.00');
      expect(stat(tester, 'quantity').data, '15 $unit');
      expect(stat(tester, 'count').data, '2');
      expect(
        rowText(tester, 'bi-drill-bucket-0'),
        '${formatDate(day(-8))} | Bs. 20.00 · 5 $unit · 1 compra',
      );
      expect(
        rowText(tester, 'bi-drill-bucket-1'),
        '${formatDate(day(-3))} | Bs. 30.00 · 10 $unit · 1 compra',
      );
      expect(find.byKey(const ValueKey('bi-drill-bucket-2')), findsNothing);

      List<double> rods() => [
        for (final g
            in tester
                .widget<BarChart>(
                  find.descendant(
                    of: find.byKey(const ValueKey('bi-drill-over-time')),
                    matching: find.byType(BarChart),
                  ),
                )
                .data
                .barGroups)
          g.barRods.single.toY,
      ];
      expect(rods()[5], 20); // día -8
      expect(rods()[10], 30); // día -3
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('bi-drill-over-time')),
          matching: find.text('Cantidad'),
        ),
      );
      await tester.pumpAndSettle();
      expect(rods()[5], 5);
      expect(rods()[10], 10);
    });

    testWidgets('en pastel no se abre el detalle: solo hay globos', (
      tester,
    ) async {
      final s = await DrillSeed.create(h);
      await pumpDashboard(
        tester,
        only(BiIndicator.salesByProduct, filters: s.filters),
      );
      await pickType(tester, BiIndicator.salesByProduct, BiChartType.pie);
      final center = tester.getCenter(find.byType(PieChart));
      await tester.tapAt(center + Offset.fromDirection(30 * math.pi / 180, 65));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('bi-drill-title')), findsNothing);
    });

    testWidgets(
      'los rankings sin detalle (Precio A/B) no abren hoja ni muestran la flecha',
      (tester) async {
        final p = await h.newProduct('Tote bag', stock: 1000);
        await h.sell(day(0), p, 1, 100);
        await h.refresh();
        await pumpDashboard(tester, only(BiIndicator.salesByPriceType));
        await pickType(tester, BiIndicator.salesByPriceType, BiChartType.bar);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
        await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('bi-drill-title')), findsNothing);
      },
    );

    testWidgets('en 360 dp la hoja no se desborda y desplaza su contenido', (
      tester,
    ) async {
      final s = await DrillSeed.create(h);
      // Muchas ventas y gastos del evento para que el contenido no quepa.
      for (var i = 0; i < 12; i++) {
        await h.sell(day(-6 + i % 6), s.collar, 1, 80.0 + i, eventId: s.feria);
        await h.spend(day(-6 + i % 6), 10.0 + i, eventId: s.feria);
      }
      await h.refresh();
      await pumpDashboard(
        tester,
        only(BiIndicator.salesByEvent, filters: s.filters),
        size: const Size(360, 640),
      );
      await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final list = find.byKey(const ValueKey('bi-drill-list'));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      // La hoja cabe en la pantalla.
      final sheet = tester.getRect(list);
      expect(sheet.left, greaterThanOrEqualTo(0));
      expect(sheet.right, lessThanOrEqualTo(360));
      expect(sheet.bottom, lessThanOrEqualTo(640));

      // Al desplazarse hasta el final aparece el último gasto (14 en total).
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('bi-drill-expense-13')),
        200,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(const ValueKey('bi-drill-expense-13')), findsOneWidget);
      expect(find.byKey(const ValueKey('bi-drill-expense-14')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'en 360 dp caben todos los detalles, también con nombres largos',
      (tester) async {
        final cat = await h.newCategory(
          'Categoría con un nombre larguísimo para probar el recorte',
        );
        final prod = await h.newProduct(
          'Set de pines pequeños con un nombre muy largo',
          categoryId: cat,
        );
        final mat = await h.newMaterial(
          'Base metálica pequeña para pines de colección',
        );
        final feria = await h.newEvent(
          'Larga Noche de Museos La Paz 2026',
          day(-5),
          day(-1),
        );
        for (var i = 0; i < 6; i++) {
          await h.sell(day(-i), prod, 2 + i, 123.45, eventId: feria);
          await h.buyMaterial(day(-i), mat, 3.5 + i, 7.25, eventId: feria);
        }
        await h.refresh();
        for (final entry in [
          BiIndicator.salesByProduct,
          BiIndicator.salesByCategory,
          BiIndicator.salesByEvent,
          BiIndicator.purchasesByMaterial,
        ]) {
          await pumpDashboard(tester, only(entry), size: const Size(360, 800));
          await tester.tap(find.byKey(const ValueKey('bi-ranking-row-0')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('bi-drill-title')),
            findsOneWidget,
            reason: entry.name,
          );
          expect(tester.takeException(), isNull, reason: entry.name);
          await tester.tap(find.byKey(const ValueKey('bi-drill-close')));
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      'el detalle sigue las mismas cifras que la barra tocada (todas las barras)',
      (tester) async {
        final s = await DrillSeed.create(h);
        await pumpDashboard(
          tester,
          only(BiIndicator.salesByProduct, filters: s.filters),
        );
        // Anillo 195, Cuadro 120, Collar 70.
        for (final (i, revenue) in [
          (0, 'Bs. 195.00'),
          (1, 'Bs. 120.00'),
          (2, 'Bs. 70.00'),
        ]) {
          await tester.tap(find.byKey(ValueKey('bi-ranking-row-$i')));
          await tester.pumpAndSettle();
          expect(stat(tester, 'revenue').data, revenue, reason: 'fila $i');
          await tester.tap(find.byKey(const ValueKey('bi-drill-close')));
          await tester.pumpAndSettle();
        }
      },
    );
  });

  // ---------------------------------------------------------------------
  // Leyenda que oculta series
  // ---------------------------------------------------------------------

  group('leyenda', () {
    Future<void> pumpTimeSeries(
      WidgetTester tester, {
      bool asBars = false,
    }) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
      await h.sell(day(-1), p, 1, 100);
      await h.sell(day(-3), p, 1, 50);
      await h.spend(day(-2), 400);
      await h.refresh();
      await pumpDashboard(
        tester,
        only(
          BiIndicator.timeSeries,
          filters: ReportFilters(startDate: day(-13), endDate: day(0)),
        ),
      );
      if (asBars) {
        await pickType(tester, BiIndicator.timeSeries, BiChartType.bar);
      }
    }

    Finder legend(String prefix, int i) => find.byKey(ValueKey('$prefix-$i'));

    testWidgets(
      'líneas: tocar un elemento oculta o muestra su serie, y siempre queda una',
      (tester) async {
        await pumpTimeSeries(tester);
        LineChart chart() => tester.widget<LineChart>(find.byType(LineChart));
        expect(chart().data.lineBarsData.length, 2);
        final fullMaxY = chart().data.maxY;
        expect(fullMaxY, closeTo(400 * 1.15, 1e-9));

        // Ocultar Gastos: queda Ingresos, y el eje se ajusta a lo que se ve.
        await tester.tap(legend('bi-legend-timeseries', 1));
        await tester.pumpAndSettle();
        expect(chart().data.lineBarsData.length, 1);
        expect(chart().data.lineBarsData.single.color, chartColorAt(0));
        expect(chart().data.maxY, closeTo(100 * 1.15, 1e-9));

        // Ocultar también Ingresos no se permite: debe quedar una serie.
        await tester.tap(legend('bi-legend-timeseries', 0));
        await tester.pumpAndSettle();
        expect(chart().data.lineBarsData.length, 1);
        expect(chart().data.lineBarsData.single.color, chartColorAt(0));

        // Mostrar Gastos de nuevo.
        await tester.tap(legend('bi-legend-timeseries', 1));
        await tester.pumpAndSettle();
        expect(chart().data.lineBarsData.length, 2);
        expect(chart().data.lineBarsData.last.dashArray, isNotNull);
        expect(chart().data.maxY, closeTo(fullMaxY, 1e-9));

        // Ahora al revés: ocultar Ingresos deja solo Gastos (punteada).
        await tester.tap(legend('bi-legend-timeseries', 0));
        await tester.pumpAndSettle();
        expect(chart().data.lineBarsData.length, 1);
        expect(chart().data.lineBarsData.single.color, chartColorAt(1));
        await tester.tap(
          legend('bi-legend-timeseries', 1),
        ); // la última: no se oculta
        await tester.pumpAndSettle();
        expect(chart().data.lineBarsData.length, 1);
      },
    );

    testWidgets('el globo solo muestra las series visibles', (tester) async {
      await pumpTimeSeries(tester);
      await tester.tap(legend('bi-legend-timeseries', 1));
      await tester.pumpAndSettle();
      await tester.tapAt(linePoint(tester, find.byType(LineChart), 12));
      await tester.pump();
      expect(tipTexts(tester), [formatDate(day(-1)), 'Ingresos: Bs. 100.00']);
    });

    testWidgets(
      'barras: cada grupo pasa de dos barras a una y el color no cambia',
      (tester) async {
        await pumpTimeSeries(tester, asBars: true);
        BarChart chart() => tester.widget<BarChart>(find.byType(BarChart));
        expect(chart().data.barGroups.first.barRods.length, 2);

        await tester.tap(legend('bi-legend-timeseries', 0)); // oculta Ingresos
        await tester.pumpAndSettle();
        expect(chart().data.barGroups.first.barRods.length, 1);
        expect(
          chart().data.barGroups.first.barRods.single.color,
          chartColorAt(1),
        );
        expect(chart().data.maxY, closeTo(400 * 1.15, 1e-9));

        await tester.tap(
          legend('bi-legend-timeseries', 1),
        ); // no puede ocultar la última
        await tester.pumpAndSettle();
        expect(chart().data.barGroups.first.barRods.length, 1);

        await tester.tap(legend('bi-legend-timeseries', 0));
        await tester.pumpAndSettle();
        expect(chart().data.barGroups.first.barRods.length, 2);
      },
    );

    testWidgets('la leyenda dice qué está oculto sin depender solo del color', (
      tester,
    ) async {
      await pumpTimeSeries(tester);
      Text label(int i) => tester.widget<Text>(
        find.descendant(
          of: legend('bi-legend-timeseries', i),
          matching: find.byType(Text),
        ),
      );
      expect(label(1).style?.decoration, isNot(TextDecoration.lineThrough));
      await tester.tap(legend('bi-legend-timeseries', 1));
      await tester.pumpAndSettle();
      expect(label(1).style?.decoration, TextDecoration.lineThrough);
      expect(label(0).style?.decoration, isNot(TextDecoration.lineThrough));
      // Es un botón con estado, para los lectores de pantalla.
      final semantics = tester.getSemantics(legend('bi-legend-timeseries', 1));
      expect(semantics.label, contains('Gastos'));
    });

    testWidgets('proyección: oculta lo real o la tendencia, nunca las dos', (
      tester,
    ) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
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
      await pumpDashboard(tester, only(BiIndicator.salesProjection));
      LineChart chart() => tester.widget<LineChart>(find.byType(LineChart));
      expect(chart().data.lineBarsData.length, 2);

      await tester.tap(legend('bi-legend-projection', 0)); // oculta lo real
      await tester.pumpAndSettle();
      expect(chart().data.lineBarsData.length, 1);
      expect(chart().data.lineBarsData.single.dashArray, isNotNull);

      await tester.tap(
        legend('bi-legend-projection', 1),
      ); // la última: se queda
      await tester.pumpAndSettle();
      expect(chart().data.lineBarsData.length, 1);

      await tester.tap(legend('bi-legend-projection', 0));
      await tester.pumpAndSettle();
      expect(chart().data.lineBarsData.length, 2);
      await tester.tap(
        legend('bi-legend-projection', 1),
      ); // oculta la tendencia
      await tester.pumpAndSettle();
      expect(chart().data.lineBarsData.length, 1);
      expect(chart().data.lineBarsData.single.dashArray, isNull);
      // El texto de la proyección no depende de la leyenda.
      expect(
        find.byKey(const ValueKey('bi-projection-summary')),
        findsOneWidget,
      );
    });

    testWidgets(
      'barras agrupadas (periodo actual / anterior y evento / regular)',
      (tester) async {
        final p = await h.newProduct('Tote bag', stock: 1000);
        await h.sell(day(-1), p, 3, 100);
        await h.sell(day(-8), p, 1, 100);
        await h.refresh();
        await pumpDashboard(
          tester,
          only(
            BiIndicator.periodComparison,
            filters: ReportFilters(startDate: day(-6), endDate: day(0)),
          ),
        );
        await pickType(tester, BiIndicator.periodComparison, BiChartType.bar);
        BarChart chart() => tester.widget<BarChart>(find.byType(BarChart));
        expect(chart().data.barGroups.first.barRods.length, 2);
        await tester.tap(legend('bi-legend-grouped', 1)); // oculta "Anterior"
        await tester.pumpAndSettle();
        expect(chart().data.barGroups.first.barRods.length, 1);
        expect(chart().data.barGroups.first.barRods.single.toY, 300);
        expect(
          chart().data.barGroups.first.barRods.single.color,
          chartColorAt(0),
        );
        await tester.tap(legend('bi-legend-grouped', 0)); // la última: se queda
        await tester.pumpAndSettle();
        expect(chart().data.barGroups.first.barRods.length, 1);
        await tester.tap(legend('bi-legend-grouped', 1));
        await tester.pumpAndSettle();
        expect(chart().data.barGroups.first.barRods.length, 2);
        // Y el globo solo lleva las series visibles.
        await tester.tap(
          legend('bi-legend-grouped', 0),
        ); // ahora oculta "Actual"
        await tester.pumpAndSettle();
        await tester.tapAt(
          barPoint(tester, find.byType(BarChart), 0, 3, axis: 28),
        );
        await tester.pump();
        expect(tipTexts(tester), ['Ingresos', 'Anterior: Bs. 100.00']);
      },
    );

    testWidgets(
      'el eje de montos no encima el mínimo negativo con la marca de al lado',
      (tester) async {
        final p = await h.newProduct('Tote bag', stock: 1000);
        await h.sell(day(-1), p, 1, 100); // ingresos 100
        await h.spend(day(-2), 300); // gastos 300: balance -200
        await h.refresh();
        await pumpDashboard(
          tester,
          only(
            BiIndicator.periodComparison,
            filters: ReportFilters(startDate: day(-6), endDate: day(0)),
          ),
        );
        await pickType(tester, BiIndicator.periodComparison, BiChartType.bar);
        final axis = inSection(
          BiIndicator.periodComparison,
          find.byType(BarChart),
        );
        // El eje llega a -200 × 1.15 = -230, que no es una marca: su etiqueta
        // se encimaría con la de -200, así que no se dibuja.
        expect(tester.widget<BarChart>(axis).data.minY, closeTo(-230, 1e-9));
        expect(
          find.descendant(of: axis, matching: find.text('-230')),
          findsNothing,
        );
        expect(
          find.descendant(of: axis, matching: find.text('-200')),
          findsOneWidget,
        );
        // Oculta una serie: el eje se recalcula y sigue sin etiquetas pegadas.
        await tester.tap(find.byKey(const ValueKey('bi-legend-grouped-1')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final labels = [
          for (final t in tester.widgetList<Text>(
            find.descendant(of: axis, matching: find.byType(Text)),
          ))
            t.data!,
        ];
        expect(labels.toSet().length, labels.length, reason: '$labels');
      },
    );

    testWidgets('evento frente a días regulares', (tester) async {
      final p = await h.newProduct('Tote bag', stock: 1000);
      await h.newEvent('Feria de Arte', day(-3), day(-2));
      await h.sell(day(-3), p, 1, 300);
      await h.sell(day(-2), p, 1, 300);
      await h.sell(day(0), p, 1, 100);
      await h.sell(day(-1), p, 1, 100);
      await h.sell(day(-4), p, 1, 100);
      await h.refresh();
      await pumpDashboard(
        tester,
        only(
          BiIndicator.eventComparison,
          filters: ReportFilters(startDate: day(-4), endDate: day(0)),
        ),
      );
      await pickType(tester, BiIndicator.eventComparison, BiChartType.bar);
      BarChart chart() => tester.widget<BarChart>(find.byType(BarChart));
      expect(chart().data.barGroups.first.barRods.length, 2);
      await tester.tap(legend('bi-legend-grouped', 0));
      await tester.pumpAndSettle();
      expect(chart().data.barGroups.first.barRods.length, 1);
      // Por día de los días regulares: 300 / 3 = 100.
      expect(chart().data.barGroups.first.barRods.single.toY, 100);
    });

    testWidgets('radar: tocar un producto de la leyenda lo oculta del radar', (
      tester,
    ) async {
      final ids = [
        for (final n in ['Estuches', 'Libro', 'Miniaturas'])
          await h.newProduct(n, productionCost: 1),
      ];
      for (final id in ids) {
        await h.sell(day(0), id, 1, 50);
      }
      await h.refresh();
      await pumpDashboard(tester, only(BiIndicator.productRadar));
      RadarChart chart() => tester.widget<RadarChart>(find.byType(RadarChart));
      // Conjunto de escala + 3 productos.
      expect(chart().data.dataSets.length, 4);

      await tester.tap(find.byKey(const ValueKey('bi-radar-legend-1')));
      await tester.pumpAndSettle();
      expect(chart().data.dataSets.length, 3);
      // Los demás conservan su color (el primero y el tercero).
      expect(chart().data.dataSets[1].borderColor, chartColorAt(0));
      expect(chart().data.dataSets[2].borderColor, chartColorAt(2));

      await tester.tap(find.byKey(const ValueKey('bi-radar-legend-0')));
      await tester.pumpAndSettle();
      expect(chart().data.dataSets.length, 2);
      // Queda un producto: no se puede ocultar.
      await tester.tap(find.byKey(const ValueKey('bi-radar-legend-2')));
      await tester.pumpAndSettle();
      expect(chart().data.dataSets.length, 2);

      await tester.tap(find.byKey(const ValueKey('bi-radar-legend-1')));
      await tester.pumpAndSettle();
      expect(chart().data.dataSets.length, 3);
    });

    test('toggleSeries: oculta, muestra y nunca deja todas ocultas', () {
      expect(toggleSeries({}, 1, 2), {1});
      expect(toggleSeries({1}, 0, 2), {1}); // la última visible no se oculta
      expect(toggleSeries({1}, 1, 2), <int>{});
      expect(
        toggleSeries({}, 0, 1),
        <int>{},
      ); // una sola serie: nada que ocultar
      expect(toggleSeries({0}, 2, 4), {0, 2});
      expect(toggleSeries({0, 2}, 3, 4), {0, 2, 3}); // queda visible la 1
      expect(toggleSeries({0, 2, 3}, 1, 4), {0, 2, 3}); // la última: se queda
    });
  });

  // ---------------------------------------------------------------------
  // Lo que ya existía sigue intacto
  // ---------------------------------------------------------------------

  group('sin interacción', () {
    testWidgets(
      'los selectores, los iconos de información y la paleta siguen igual',
      (tester) async {
        final s = await DrillSeed.create(h);
        await pumpDashboard(
          tester,
          BiConfig(filters: s.filters, indicators: {...BiIndicator.values}),
        );
        for (final i in BiIndicator.values) {
          expect(
            find.byKey(ValueKey('bi-info-${i.title}')),
            findsOneWidget,
            reason: i.name,
          );
          for (final type
              in i.hasChartPicker ? i.chartTypes : <BiChartType>[]) {
            expect(
              inSection(i, find.byKey(ValueKey('bi-chart-type-${type.name}'))),
              findsOneWidget,
              reason: '${i.name} / ${type.name}',
            );
          }
        }
        // Sin tocar nada no hay globos ni hojas.
        expect(tooltip, findsNothing);
        expect(find.byKey(const ValueKey('bi-drill-title')), findsNothing);
        // Y los gráficos terminaron de dibujarse.
        expect(tester.hasRunningAnimations, isFalse);
        const palette = [
          AppColors.chartColor1,
          AppColors.chartColor2,
          AppColors.chartColor3,
          AppColors.chartColor4,
          AppColors.chartColor5,
        ];
        final line = tester.widget<LineChart>(
          inSection(BiIndicator.timeSeries, find.byType(LineChart)),
        );
        for (final bar in line.data.lineBarsData) {
          expect(palette, contains(bar.color));
        }
      },
    );
  });
}

// La etiqueta del eje de un día (dd/mm) para comparar con lo que dibuja el eje.
String bucketLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
