import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/auth_provider.dart';
import 'package:offline_first_bi/application/bi_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/module_permission_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/auth_repository.dart';
import 'package:offline_first_bi/models/bi_config.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/models/user_model.dart';
import 'package:offline_first_bi/presentation/pages/business_intelligence_page.dart';
import 'package:offline_first_bi/presentation/pages/home_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

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

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final confirm = find.byKey(const ValueKey('bi-config-confirm'));
  final defaultCount = BiConfig.defaultIndicators.length;

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(_SessionRepository(db)),
          readableModulesProvider.overrideWith(
            (ref) async => const [
              'ventas',
              'compras',
              'inventario',
              'clientes',
              'reportes',
              'business_intelligence',
            ],
          ),
        ],
        child: MaterialApp(theme: lightTheme, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget host() => Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusinessIntelligencePage()),
        ),
        child: const Text('Abrir BI'),
      ),
    ),
  );

  BiConfig config(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(BusinessIntelligencePage)),
  ).read(biConfigProvider);

  void change(WidgetTester tester, BiConfig Function(BiConfig) edit) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BusinessIntelligencePage)),
    );
    final notifier = container.read(biConfigProvider.notifier);
    notifier.state = edit(notifier.state);
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  void expectDefaults(WidgetTester tester) {
    expect(find.text('Ver indicadores ($defaultCount)'), findsOneWidget);
    final current = config(tester);
    expect(current.indicators, BiConfig.defaultIndicators);
    expect(current.filters, const ReportFilters());
    expect(current.chartTypes, isEmpty);
    expect(current.metrics, isEmpty);
    expect(current.radarProductIds, isEmpty);
  }

  testWidgets('the default is ten indicators and no filters', (tester) async {
    expect(defaultCount, 10);
    await pumpApp(tester, host());
    await tester.tap(find.text('Abrir BI'));
    await tester.pumpAndSettle();

    expectDefaults(tester);
  });

  testWidgets('a changed selection and filters are gone after re-entering', (
    tester,
  ) async {
    await pumpApp(tester, host());
    await tester.tap(find.text('Abrir BI'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ninguno'));
    await tester.pumpAndSettle();
    expect(find.text('Elige al menos un indicador'), findsOneWidget);
    change(
      tester,
      (c) => c.copyWith(
        indicators: {BiIndicator.summary, BiIndicator.lowStock},
        filters: const ReportFilters(productId: 1),
        chartTypes: {BiIndicator.timeSeries: BiChartType.bar},
        noMovementDays: 7,
        radarProductIds: const [1, 2],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ver indicadores (2)'), findsOneWidget);

    await leave(tester);
    expect(find.byType(BusinessIntelligencePage), findsNothing);

    await tester.tap(find.text('Abrir BI'));
    await tester.pumpAndSettle();
    expectDefaults(tester);
    expect(config(tester).noMovementDays, defaultNoMovementDays);
  });

  testWidgets('inside one visit the panel keeps the selection on going back', (
    tester,
  ) async {
    await pumpApp(tester, host());
    await tester.tap(find.text('Abrir BI'));
    await tester.pumpAndSettle();
    change(
      tester,
      (c) => c.copyWith(
        indicators: {BiIndicator.summary, BiIndicator.lowStock},
        filters: const ReportFilters(productId: 1),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirm, findsNothing);

    await leave(tester);

    expect(find.byType(BusinessIntelligencePage), findsOneWidget);
    expect(find.text('Ver indicadores (2)'), findsOneWidget);
    expect(config(tester).filters, const ReportFilters(productId: 1));

    await leave(tester);
    expect(find.byType(BusinessIntelligencePage), findsNothing);
    await tester.tap(find.text('Abrir BI'));
    await tester.pumpAndSettle();
    expectDefaults(tester);
  });

  testWidgets('entering from the Inicio shortcut also starts from defaults', (
    tester,
  ) async {
    await pumpApp(tester, const HomePage());
    await tester.tap(find.text('BI'));
    await tester.pumpAndSettle();
    expectDefaults(tester);
    change(
      tester,
      (c) => c.copyWith(
        indicators: {BiIndicator.summary},
        filters: const ReportFilters(productId: 3),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ver indicadores (1)'), findsOneWidget);

    await leave(tester);
    expect(find.byType(BusinessIntelligencePage), findsNothing);

    await tester.tap(find.text('BI'));
    await tester.pumpAndSettle();
    expectDefaults(tester);
  });
}
