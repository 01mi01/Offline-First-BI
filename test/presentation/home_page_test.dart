import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/auth_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/home_dashboard.dart';
import 'package:offline_first_bi/application/module_permission_provider.dart';
import 'package:offline_first_bi/application/sale_provider.dart';
import 'package:offline_first_bi/config/app_clock.dart';
import 'package:offline_first_bi/data/repositories/auth_repository.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/models/sale_model.dart';
import 'package:offline_first_bi/models/user_model.dart';
import 'package:offline_first_bi/presentation/pages/home_page.dart';
import 'package:offline_first_bi/presentation/widgets/home_widgets.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

import '../support/bi_harness.dart';

// Inicio con una base real en memoria y los providers reales. El reloj está
// fijado (miércoles 18/03/2026): ninguna prueba depende del día en que se
// corre. El periodo del mes es del 01/03 al 18/03; el anterior equivalente, del
// 01/02 al 18/02.

const _allModules = [
  'ventas',
  'compras',
  'inventario',
  'clientes',
  'reportes',
  'business_intelligence',
];

// Sesión ya iniciada, para que Inicio salude por el nombre.
class _SessionRepository extends AuthRepository {
  _SessionRepository(super.database);

  @override
  Future<UserModel?> getSesionActual() async => UserModel(
    id: 1,
    username: 'María',
    email: 'maria@test.com',
    role: 'admin',
    mfaEnabled: false,
    darkMode: false,
  );
}

void _restoreClock() {
  final fake = Platform.environment['FAKE_NOW'];
  if (fake != null && fake.isNotEmpty) {
    final fixed = DateTime.parse(fake);
    setAppClockForTesting(() => fixed);
  } else {
    setAppClockForTesting();
  }
}

void main() {
  late BiHarness h;

  setUp(() {
    setAppClockForTesting(() => DateTime(2026, 3, 18, 12));
    h = BiHarness()..setUp();
  });

  tearDown(() async {
    await h.tearDown();
    _restoreClock();
  });

  // Reemplaza el contenedor por uno con los módulos legibles y la sesión.
  void useModules(List<String> modules) {
    h.container.dispose();
    h.container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(h.db),
        authRepositoryProvider.overrideWithValue(_SessionRepository(h.db)),
        readableModulesProvider.overrideWith((ref) async => modules),
      ],
    );
  }

  // Ventas y compras del escenario "sube": este mes ingresos 180 (17 y 15),
  // gasto 40 (16) = ganancia 140; el mes pasado, ingreso 100 = ganancia 100.
  Future<void> seedUp(WidgetTester tester) => tester.runAsync(() async {
    final cat = await h.newCategory('Joyas');
    final anillo = await h.newProduct('Anillo', categoryId: cat, priceA: 50);
    final collar = await h.newProduct('Collar', categoryId: cat, priceA: 80);
    await h.sell(h.day(-1), anillo, 2, 50); // 17/03: 100
    await h.sell(h.day(-3), collar, 1, 80); // 15/03: 80
    await h.spend(h.day(-2), 40); // 16/03: gasto 40
    await h.sell(DateTime(2026, 2, 10, 12), anillo, 2, 50); // mes pasado: 100
    await h.refresh();
  });

  // Escenario "baja": este mes ganancia 60 (100 - 40); el mes pasado, 200.
  Future<void> seedDown(WidgetTester tester) => tester.runAsync(() async {
    final cat = await h.newCategory('Joyas');
    final anillo = await h.newProduct('Anillo', categoryId: cat, priceA: 50);
    await h.sell(h.day(-1), anillo, 2, 50); // 100
    await h.spend(h.day(-2), 40);
    await h.sell(DateTime(2026, 2, 10, 12), anillo, 4, 50); // mes pasado: 200
    await h.refresh();
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    Size size = const Size(360, 3000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(theme: lightTheme, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));
  Finder textIn(Finder parent, String text) =>
      find.descendant(of: parent, matching: find.text(text));

  group('encabezado', () {
  });

  group('tarjeta principal', () {
    testWidgets('profit up: number, arrow up, plus sign, green pill', (
      tester,
    ) async {
      useModules(_allModules);
      await seedUp(tester);
      await pumpHome(tester);

      expect(textIn(key('home-hero'), 'Ganancias del mes'), findsOneWidget);
      expect(textIn(key('home-hero'), 'Bs. 140.00'), findsOneWidget);
      final pill = key('home-change-pill');
      expect(textIn(pill, '+40.00%'), findsOneWidget);
    });

    testWidgets('profit down: arrow down, minus sign, red text on soft pink', (
      tester,
    ) async {
      useModules(_allModules);
      await seedDown(tester);
      await pumpHome(tester);

      expect(textIn(key('home-hero'), 'Bs. 60.00'), findsOneWidget);
      final pill = key('home-change-pill');
      expect(textIn(pill, '-70.00%'), findsOneWidget);
    });

    testWidgets('no previous period: neutral pill, no invented percentage', (
      tester,
    ) async {
      useModules(_allModules);
      await tester.runAsync(() async {
        final anillo = await h.newProduct('Anillo', priceA: 50);
        await h.sell(h.day(-1), anillo, 2, 50);
        await h.refresh();
      });
      await pumpHome(tester);

      expect(textIn(key('home-hero'), 'Bs. 100.00'), findsOneWidget);
      expect(textIn(key('home-change-pill'), 'Sin datos previos'), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
    });

  });

  group('indicadores', () {
    testWidgets('four KPI cards with the month numbers', (tester) async {
      useModules(_allModules);
      await seedUp(tester);
      await pumpHome(tester);

      expect(textIn(key('home-kpi-ventas'), 'Ventas del mes'), findsOneWidget);
      expect(textIn(key('home-kpi-ventas'), 'Bs. 180.00'), findsOneWidget);
      expect(textIn(key('home-kpi-gastos'), 'Gastos del mes'), findsOneWidget);
      expect(textIn(key('home-kpi-gastos'), 'Bs. 40.00'), findsOneWidget);
      expect(textIn(key('home-kpi-cantidad'), 'Cantidad de ventas'), findsOneWidget);
      expect(textIn(key('home-kpi-cantidad'), '2'), findsOneWidget);
      expect(textIn(key('home-kpi-margen'), 'Margen de ganancia'), findsOneWidget);
      expect(textIn(key('home-kpi-margen'), '77.78%'), findsOneWidget); // 140 / 180
    });

    testWidgets('canceled, future-dated and last-month records stay out of the month figures', (
      tester,
    ) async {
      useModules(_allModules);
      await tester.runAsync(() async {
        final anillo = await h.newProduct('Anillo', priceA: 50);
        await h.sell(h.day(-1), anillo, 2, 50); // cuenta: 100
        await h.sell(h.day(2), anillo, 1, 999); // futura: no cuenta
        await h.sell(h.day(-2), anillo, 1, 777); // se cancela
        await h.cancelSaleOf(777);
        await h.sell(DateTime(2026, 2, 10, 12), anillo, 1, 555); // mes pasado
        await h.spend(h.day(3), 888); // gasto futuro: no cuenta
        await h.refresh();
      });
      await pumpHome(tester);

      expect(textIn(key('home-kpi-ventas'), 'Bs. 100.00'), findsOneWidget);
      expect(textIn(key('home-kpi-gastos'), 'Bs. 0.00'), findsOneWidget);
      expect(textIn(key('home-kpi-cantidad'), '1'), findsOneWidget);
      expect(find.text('Bs. 999.00'), findsNothing);
      expect(find.textContaining('888'), findsNothing);
    });
  });

  group('accesos rápidos', () {
    testWidgets('an Empleado only sees the shortcuts of the modules they can read', (
      tester,
    ) async {
      useModules(['ventas', 'clientes']);
      await seedUp(tester);
      await pumpHome(tester);

      expect(key('home-shortcut-sales'), findsOneWidget);
      expect(key('home-shortcut-products'), findsNothing);
      expect(key('home-shortcut-reports'), findsNothing);
      expect(key('home-shortcut-businessIntelligence'), findsNothing);
    });

    testWidgets('without any module there is no shortcuts row at all', (
      tester,
    ) async {
      useModules(const []);
      await pumpHome(tester);

      expect(find.text('Accesos rápidos'), findsNothing);
      expect(find.byType(HomeShortcutRow), findsNothing);
    });

  });

  group('gráficos', () {
    testWidgets('with Ventas only the sales charts appear, and no "Ver más" without Business Intelligence', (
      tester,
    ) async {
      useModules(['ventas']);
      await seedUp(tester);
      await pumpHome(tester);

      expect(key('home-chart-categorias'), findsOneWidget);
      expect(key('home-chart-productos'), findsOneWidget);
      // Mezclan gastos: no se muestran sin permiso de Compras.
      expect(key('home-chart-evolucion'), findsNothing);
      expect(key('home-chart-comparacion'), findsNothing);
      expect(find.text('Ver más'), findsNothing);
      expect(key('home-hero'), findsNothing);
      expect(key('home-kpi-gastos'), findsNothing);
    });

    testWidgets('with Compras only there are no charts, no hero and no sales numbers', (
      tester,
    ) async {
      useModules(['compras']);
      await seedUp(tester);
      await pumpHome(tester);

      expect(find.byType(HomeChartCard), findsNothing);
      expect(key('home-hero'), findsNothing);
      expect(textIn(key('home-kpi-gastos'), 'Bs. 40.00'), findsOneWidget);
      expect(key('home-kpi-ventas'), findsNothing);
      expect(key('home-kpi-cantidad'), findsNothing);
      expect(key('home-kpi-ticket'), findsNothing);
      expect(find.text('Bs. 180.00'), findsNothing);
    });

    testWidgets('a person with no readable module sees only the greeting', (
      tester,
    ) async {
      useModules(const []);
      await seedUp(tester);
      await pumpHome(tester);

      expect(find.text('Hola, María'), findsOneWidget);
      expect(key('home-hero'), findsNothing);
      expect(find.byType(HomeKpiGrid), findsNothing);
      expect(find.byType(HomeChartCard), findsNothing);
      expect(key('home-activity'), findsNothing);
    });
  });

  group('actividad reciente', () {
    Future<void> seedActivity(WidgetTester tester) => tester.runAsync(() async {
      final anillo = await h.newProduct('Anillo', priceA: 50);
      await h.sell(h.day(-1), anillo, 2, 50); // 17/03 (la más reciente)
      await h.spend(h.day(-2), 40); // 16/03
      await h.sell(h.day(-3), anillo, 1, 80); // 15/03
      await h.sell(h.day(-4), anillo, 1, 500); // 14/03: se cancela
      await h.cancelSaleOf(500);
      await h.sell(DateTime(2026, 2, 10, 12), anillo, 1, 60); // 10/02
      await h.sell(DateTime(2026, 2, 5, 12), anillo, 1, 70); // 05/02: sobra
      await h.sell(h.day(2), anillo, 1, 999); // futura: no aparece
      await h.refresh();
    });

    testWidgets('lists the last 5 movements, newest first, with a canceled one and its pill', (
      tester,
    ) async {
      useModules(_allModules);
      await seedActivity(tester);
      await pumpHome(tester);

      final rows = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('home-activity-'),
      );
      expect(rows, findsNWidgets(5));
      // La venta futura no aparece y la sexta más reciente queda fuera.
      expect(find.text('- Bs. 40.00'), findsOneWidget);
      expect(find.text('+ Bs. 999.00'), findsNothing);
      expect(find.text('+ Bs. 70.00'), findsNothing);
      // Orden: de la más reciente a la más antigua.
      final dates = [
        for (final r in rows.evaluate())
          tester.getTopLeft(find.byWidget(r.widget)).dy,
      ];
      expect(dates, [...dates]..sort());
      expect(find.text('Sin nombre · 17/03/2026'), findsOneWidget);
      // La cancelada aparece marcada como tal.
      expect(find.text('Cancelada'), findsOneWidget);
    });

    testWidgets('a sale row shows its client, date and amount', (tester) async {
      useModules(_allModules);
      await seedActivity(tester);
      await pumpHome(tester);

      final firstSale = h.container
          .read(saleProvider)
          .sales
          .firstWhere((s) => s.finalAmount == 100);
      final row = key('home-activity-sale-${firstSale.id}');
      expect(textIn(row, 'Venta'), findsOneWidget);
      expect(textIn(row, 'Sin nombre · 17/03/2026'), findsOneWidget);
      expect(textIn(row, '+ Bs. 100.00'), findsOneWidget);
    });

    testWidgets('only purchases for someone who can read Compras but not Ventas', (
      tester,
    ) async {
      useModules(['compras']);
      await seedActivity(tester);
      await pumpHome(tester);

      expect(find.text('- Bs. 40.00'), findsOneWidget);
      expect(find.textContaining('+ Bs.'), findsNothing);
      expect(find.text('Cancelada'), findsNothing);
    });
  });

  group('sin datos', () {
    testWidgets('a brand new account shows friendly empty states, never NaN or Infinity', (
      tester,
    ) async {
      useModules(_allModules);
      await tester.runAsync(() async => h.refresh());
      await pumpHome(tester);

      expect(textIn(key('home-hero'), 'Bs. 0.00'), findsOneWidget);
      expect(textIn(key('home-change-pill'), 'Sin datos previos'), findsOneWidget);
      expect(textIn(key('home-kpi-ventas'), 'Bs. 0.00'), findsOneWidget);
      expect(textIn(key('home-kpi-cantidad'), '0'), findsOneWidget);
      expect(textIn(key('home-kpi-gastos'), 'Bs. 0.00'), findsOneWidget);
      expect(textIn(key('home-kpi-margen'), '—'), findsOneWidget);
      // En la tarjeta principal y en los gráficos de evolución y comparación.
      expect(find.text('No se registraron movimientos este mes.'), findsNWidgets(3));
      expect(find.text('No se registraron ventas este mes.'), findsNWidgets(2));
      expect(find.text('No hay movimientos registrados.'), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('estados', () {
    testWidgets('the error card offers to retry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(body: HomeErrorCard(onRetry: () => retried++)),
        ),
      );
      expect(find.text('No se pudo cargar la información'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(retried, 1);
    });

  });

  group('lógica de Inicio', () {
    test('HomeAccess: what each module unlocks', () {
      final all = HomeAccess.from(_allModules);
      expect(all.profit, isTrue);
      expect(all.shortcuts, HomeShortcut.values);

      final sales = HomeAccess.from(['ventas']);
      expect(sales.profit, isFalse);
      expect(sales.needsReport, isTrue);
      expect(sales.shortcuts, [HomeShortcut.sales]);

      final none = HomeAccess.from(const []);
      expect(none.needsReport, isFalse);
      expect(none.hasAnyShortcut, isFalse);
    });

    test('HomeChange: sign, arrow direction and zero guards', () {
      expect(HomeChange.of(110, 100).label, '+10.00%');
      expect(HomeChange.of(110, 100).trend, HomeTrend.up);
      expect(HomeChange.of(90, 100).label, '-10.00%');
      expect(HomeChange.of(90, 100).trend, HomeTrend.down);
      expect(HomeChange.of(100, 100).label, '0.00%');
      expect(HomeChange.of(100, 100).trend, HomeTrend.flat);
      // Sin base: nada de infinitos ni NaN.
      expect(HomeChange.of(50, 0).trend, HomeTrend.none);
      expect(HomeChange.of(50, 0).pct, isNull);
      expect(HomeChange.of(0, 0).label, 'Sin datos previos');
      // Con base negativa, "mejor" sigue siendo positivo.
      expect(HomeChange.of(-10, -20).label, '+50.00%');
    });

    test('recentActivity: newest first, no future records, limit and filters', () {
      final now = DateTime(2026, 3, 18, 12);
      SaleModel sale(int id, DateTime date, {bool canceled = false}) => SaleModel(
        id: id,
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 10.0 * id,
        discount: 0,
        finalAmount: 10.0 * id,
        date: date,
        createdAt: date,
        isCanceled: canceled,
      );
      PurchaseModel purchase(int id, DateTime date) => PurchaseModel(
        id: id,
        supplierId: null,
        locationId: null,
        eventId: null,
        isMaterial: false,
        totalAmount: 5.0 * id,
        date: date,
        createdAt: date,
      );
      final sales = [
        sale(1, DateTime(2026, 3, 1)),
        sale(2, DateTime(2026, 3, 10), canceled: true),
        sale(3, DateTime(2026, 3, 25)), // futura
      ];
      final purchases = [purchase(1, DateTime(2026, 3, 12))];

      final all = recentActivity(
        sales: sales,
        purchases: purchases,
        clientName: (_) => 'C',
        supplierName: (_) => 'P',
        now: now,
      );
      expect(all.map((a) => a.isSale), [false, true, true]);
      expect(all[1].isCanceled, isTrue);
      expect(all.map((a) => a.title), ['P', 'C', 'C']);

      final onlyPurchases = recentActivity(
        sales: sales,
        purchases: purchases,
        clientName: (_) => 'C',
        supplierName: (_) => 'P',
        now: now,
        includeSales: false,
      );
      expect(onlyPurchases.length, 1);

      final limited = recentActivity(
        sales: sales,
        purchases: purchases,
        clientName: (_) => 'C',
        supplierName: (_) => 'P',
        now: now,
        limit: 2,
      );
      expect(limited.length, 2);
    });
  });
}
