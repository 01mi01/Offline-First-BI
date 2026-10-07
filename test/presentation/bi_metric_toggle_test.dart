import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/bi_provider.dart';
import 'package:offline_first_bi/models/bi_config.dart';
import 'package:offline_first_bi/presentation/pages/business_intelligence_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import '../support/bi_drill_seed.dart';
import '../support/bi_harness.dart';

// El interruptor de métrica de los indicadores (Ingresos / Unidades en los
// rankings, Margen % / Ganancia, Ingresos / Número de ventas por día) guarda su
// opción en la configuración de Business Intelligence y no en el gráfico: así
// sobrevive a que el gráfico salga de pantalla y se reconstruya, y se descarta
// al empezar un panel nuevo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = BiHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  Finder section(BiIndicator i) => find.byKey(ValueKey('bi-section-${i.name}'));
  Finder inSection(BiIndicator i, Finder f) =>
      find.descendant(of: section(i), matching: f);
  Finder chip(BiIndicator i, String label) => inSection(i, find.text(label));

  // La opción de un interruptor se ve resaltada en el color primario.
  bool selected(WidgetTester tester, BiIndicator i, String label) =>
      tester.widget<Text>(chip(i, label)).style?.color == AppColors.primary;

  BiConfig config() => h.container.read(biConfigProvider);

  Future<void> pumpDashboard(WidgetTester tester, BiConfig config) async {
    // Una pantalla chica para que el panel sea largo y los gráficos lejanos
    // salgan de la lista perezosa al desplazarse.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    h.container.read(biConfigProvider.notifier).state = config;
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
    // El botón va al final del contenido que se desplaza.
    await tester.ensureVisible(find.byKey(const ValueKey('bi-config-confirm')));
    await tester.tap(find.byKey(const ValueKey('bi-config-confirm')));
    await tester.pumpAndSettle();
  }

  Finder list() => find.byType(Scrollable).first;

  // Lleva un indicador a la vista y elige su tipo de gráfico.
  Future<void> tapType(WidgetTester tester, BiIndicator i, String type) async {
    await tester.scrollUntilVisible(
      section(i),
      500,
      scrollable: list(),
      maxScrolls: 200,
    );
    final picker = inSection(i, find.byKey(ValueKey('bi-chart-type-$type')));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
  }

  // Lleva un indicador a la vista (el panel empieza arriba).
  Future<void> reveal(WidgetTester tester, BiIndicator i) => tester
      .scrollUntilVisible(section(i), 500, scrollable: list(), maxScrolls: 200);

  // Elige una opción del interruptor de un indicador, llevándola a la vista
  // primero (el panel es largo).
  Future<void> pick(WidgetTester tester, BiIndicator i, String label) async {
    await tester.scrollUntilVisible(
      section(i),
      500,
      scrollable: list(),
      maxScrolls: 200,
    );
    await tester.ensureVisible(chip(i, label));
    await tester.pumpAndSettle();
    await tester.tap(chip(i, label));
    await tester.pumpAndSettle();
  }

  // Desplaza el panel hasta que [target] esté en pantalla; [down] según esté
  // más abajo o más arriba.
  Future<void> scrollTo(
    WidgetTester tester,
    Finder target, {
    required bool down,
  }) => tester.scrollUntilVisible(
    target,
    down ? 500 : -500,
    scrollable: list(),
    maxScrolls: 200,
  );

  // Con todos los indicadores y datos en cada uno.
  Future<BiConfig> fullConfig() async {
    final s = await DrillSeed.create(h);
    return BiConfig(filters: s.filters, indicators: {...BiIndicator.values});
  }

  // Los indicadores con interruptor y la opción que no es la primera.
  const toggles = <(BiIndicator, String, String)>[
    (BiIndicator.salesByProduct, 'Ingresos', 'Unidades'),
    (BiIndicator.productMargin, 'Margen %', 'Ganancia'),
    (BiIndicator.salesByCategory, 'Ingresos', 'Unidades'),
    (BiIndicator.weekdaySales, 'Ingresos', 'Número de ventas'),
  ];

  group(
    'la opción del interruptor sobrevive a que el gráfico se reconstruya',
    () {
      testWidgets(
        'al salir de pantalla y volver, en cada indicador con interruptor',
        (tester) async {
          await pumpDashboard(tester, await fullConfig());

          for (final (indicator, first, second) in toggles) {
            await scrollTo(tester, section(indicator), down: true);
            expect(
              selected(tester, indicator, first),
              isTrue,
              reason: indicator.name,
            );
            await pick(tester, indicator, second);
            expect(
              selected(tester, indicator, second),
              isTrue,
              reason: indicator.name,
            );
            expect(
              selected(tester, indicator, first),
              isFalse,
              reason: indicator.name,
            );
            expect(config().metricFor(indicator), 1, reason: indicator.name);

            // Lejos del gráfico: el último indicador del panel. La lista perezosa
            // descarta el widget (y con él, cualquier estado propio).
            await scrollTo(tester, section(BiIndicator.noMovement), down: true);
            expect(
              section(indicator),
              findsNothing,
              reason: '${indicator.name} fuera',
            );

            // De vuelta: sigue en la segunda opción.
            await scrollTo(tester, section(indicator), down: false);
            expect(section(indicator), findsOneWidget);
            expect(
              selected(tester, indicator, second),
              isTrue,
              reason: indicator.name,
            );
            expect(
              selected(tester, indicator, first),
              isFalse,
              reason: indicator.name,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('un interruptor no mueve a los demás', (tester) async {
        await pumpDashboard(tester, await fullConfig());
        await pick(tester, BiIndicator.salesByProduct, 'Unidades');

        expect(config().metricFor(BiIndicator.salesByProduct), 1);
        expect(config().metricFor(BiIndicator.salesByCategory), 0);
        expect(config().metricFor(BiIndicator.productMargin), 0);
        await scrollTo(
          tester,
          section(BiIndicator.salesByCategory),
          down: true,
        );
        expect(
          selected(tester, BiIndicator.salesByCategory, 'Ingresos'),
          isTrue,
        );
      });

      testWidgets('cambiar de barras a pastel conserva la opción, como antes', (
        tester,
      ) async {
        await pumpDashboard(tester, await fullConfig());
        const i = BiIndicator.salesByProduct;
        await pick(tester, i, 'Unidades');
        await tapType(tester, i, 'pie');
        expect(selected(tester, i, 'Unidades'), isTrue);
        // En pastel, por unidades: la leyenda da las unidades y su porcentaje
        // (Anillo 4 de 8 = 50.0 %).
        expect(
          inSection(i, find.textContaining('4 uds.  (50.0%)')),
          findsOneWidget,
        );
        await tapType(tester, i, 'bar');
        expect(selected(tester, i, 'Unidades'), isTrue);
      });

      testWidgets('lo que muestra el gráfico sigue a la opción guardada', (
        tester,
      ) async {
        await pumpDashboard(tester, await fullConfig());
        const i = BiIndicator.salesByCategory;
        await scrollTo(tester, section(i), down: true);
        // Por ingresos: Joyas 265 (5 uds.) y Arte 120 (3 uds.).
        expect(inSection(i, find.text('Bs. 265.00')), findsWidgets);
        await pick(tester, i, 'Unidades');
        await scrollTo(tester, section(BiIndicator.noMovement), down: true);
        await scrollTo(tester, section(i), down: false);
        // Por unidades, la barra de Joyas muestra "5 uds." como valor y el
        // dinero queda debajo.
        expect(selected(tester, i, 'Unidades'), isTrue);
        final value = tester.getTopLeft(
          inSection(i, find.text('5 uds.')).first,
        );
        final detail = tester.getTopLeft(
          inSection(i, find.text('Bs. 265.00')).first,
        );
        expect(value.dy, lessThan(detail.dy));
      });
    },
  );

  group('empieza de nuevo con cada panel', () {
    testWidgets(
      'al volver a configurar y mostrar el panel, vuelve a la primera opción',
      (tester) async {
        await pumpDashboard(tester, await fullConfig());
        await pick(tester, BiIndicator.salesByProduct, 'Unidades');
        expect(config().metrics, isNotEmpty);

        // Volver a la configuración conserva lo elegido hasta que se confirma...
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('bi-configure')),
          -500,
          scrollable: list(),
          maxScrolls: 200,
        );
        await tester.tap(find.byKey(const ValueKey('bi-configure')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('bi-config-confirm')), findsOneWidget);

        // ...y al empezar un panel nuevo, todo vuelve a la opción por omisión.
        // El botón va al final del contenido que se desplaza.
        await tester.ensureVisible(find.byKey(const ValueKey('bi-config-confirm')));
        await tester.tap(find.byKey(const ValueKey('bi-config-confirm')));
        await tester.pumpAndSettle();
        expect(config().metrics, isEmpty);
        expect(config().metricFor(BiIndicator.salesByProduct), 0);
        await reveal(tester, BiIndicator.salesByProduct);
        expect(
          selected(tester, BiIndicator.salesByProduct, 'Ingresos'),
          isTrue,
        );
      },
    );

    testWidgets(
      'las demás elecciones de la configuración no se pierden al confirmar',
      (tester) async {
        await pumpDashboard(tester, await fullConfig());
        await tapType(tester, BiIndicator.salesByProduct, 'pie');
        await pick(tester, BiIndicator.salesByProduct, 'Unidades');

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('bi-configure')),
          -500,
          scrollable: list(),
          maxScrolls: 200,
        );
        await tester.tap(find.byKey(const ValueKey('bi-configure')));
        await tester.pumpAndSettle();
        // El botón va al final del contenido que se desplaza.
        await tester.ensureVisible(find.byKey(const ValueKey('bi-config-confirm')));
        await tester.tap(find.byKey(const ValueKey('bi-config-confirm')));
        await tester.pumpAndSettle();

        // El tipo de gráfico se recuerda (como siempre); la métrica, no.
        expect(
          config().chartTypeFor(BiIndicator.salesByProduct),
          BiChartType.pie,
        );
        expect(config().indicators.length, BiIndicator.values.length);
        await reveal(tester, BiIndicator.salesByProduct);
        expect(
          selected(tester, BiIndicator.salesByProduct, 'Ingresos'),
          isTrue,
        );
      },
    );
  });

  group('BiConfig', () {
    test(
      'sin elegir nada, todos los interruptores están en la primera opción',
      () {
        final c = BiConfig();
        expect(c.metrics, isEmpty);
        for (final i in BiIndicator.values) {
          expect(c.metricFor(i), 0, reason: i.name);
        }
      },
    );

    test(
      'copyWith conserva las métricas y las reemplaza o vacía si se le pide',
      () {
        final c = BiConfig(metrics: {BiIndicator.salesByProduct: 1});
        expect(
          c.copyWith(noMovementDays: 7).metricFor(BiIndicator.salesByProduct),
          1,
        );
        expect(
          c
              .copyWith(
                chartTypes: {BiIndicator.salesByProduct: BiChartType.pie},
              )
              .metricFor(BiIndicator.salesByProduct),
          1,
        );
        expect(c.copyWith(metrics: {BiIndicator.productMargin: 1}).metrics, {
          BiIndicator.productMargin: 1,
        });
        expect(c.copyWith(metrics: const {}).metrics, isEmpty);
      },
    );

    test(
      'la métrica solo cambia lo que se ve: no recalcula los indicadores',
      () {
        // La clave de los cálculos no incluye las métricas, así que elegir
        // "Unidades" no vuelve a calcular el reporte.
        expect(
          BiConfig(metrics: {BiIndicator.salesByProduct: 1}).query,
          BiConfig().query,
        );
      },
    );
  });
}
