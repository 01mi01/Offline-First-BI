import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/bi_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/date_range_filter.dart';
import 'package:offline_first_bi/application/today_provider.dart';
import 'package:offline_first_bi/config/app_clock.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/bi_config.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/reports_page.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/presentation/widgets/day_change_watcher.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'filter_helpers.dart';

void main() {
  late AppDatabase db;
  late DateTime current;

  setUp(() async {
    current = DateTime(2026, 10, 25, 23, 59, 30);
    setAppClockForTesting(() => current);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final client = await db.into(db.clients).insert(
      ClientsCompanion.insert(name: 'Clienta Futura'),
    );
    await db.into(db.sales).insert(
      SalesCompanion.insert(
        clientId: Value(client),
        totalAmount: 10,
        finalAmount: 10,
        date: DateTime(2026, 10, 26, 12),
      ),
    );
  });

  tearDown(() async {
    setAppClockForTesting();
    await db.close();
  });

  Future<ProviderContainer> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: lightTheme,
          builder: (context, child) => DayChangeWatcher(child: child!),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  void goToBackground(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  void returnToForeground(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  Finder notesField() => find.byWidgetPredicate(
    (w) =>
        w is TextField && w.decoration?.hintText == 'Observaciones opcionales',
  );

  Future<void> openFormAndType(WidgetTester tester) async {
    showSaleForm(tester.element(find.byType(SalesListBody)));
    await tester.pumpAndSettle();
    await tester.enterText(notesField(), 'nota importante');
    await tester.pump();
  }

  void expectFormUntouched() {
    expect(find.byType(SaleDialog), findsOneWidget);
    expect(find.text('nota importante'), findsOneWidget);
  }

  testWidgets('at midnight the lists and the applied period move to the new day '
      'without touching an open form', (tester) async {
    final container = await pump(tester, const SalesListBody());
    container.read(saleDateFilterProvider.notifier).state =
        DateRangeFilter.forPreset(DatePreset.today);
    await tester.pumpAndSettle();
    expect(find.text('Clienta Futura'), findsNothing);

    await openFormAndType(tester);

    current = DateTime(2026, 10, 26, 0, 0, 5);
    await tester.pump(const Duration(seconds: 32));
    await tester.pumpAndSettle();

    final filter = container.read(saleDateFilterProvider);
    expect(filter.preset, DatePreset.today);
    expect(filter.from, DateTime(2026, 10, 26));
    expect(filter.to, DateTime(2026, 10, 26));
    expect(container.read(todayProvider), DateTime(2026, 10, 26));
    expect(find.text('Clienta Futura'), findsOneWidget);
    expectFormUntouched();
  });

  testWidgets('coming back to the foreground on another day refreshes the '
      'data and keeps the open form', (tester) async {
    current = DateTime(2026, 10, 25, 10);
    final container = await pump(tester, const SalesListBody());
    container.read(saleDateFilterProvider.notifier).state =
        DateRangeFilter.forPreset(DatePreset.week);
    await tester.pumpAndSettle();
    expect(find.text('Clienta Futura'), findsNothing);

    await openFormAndType(tester);

    goToBackground(tester);
    current = DateTime(2026, 10, 26, 8);
    returnToForeground(tester);
    await tester.pumpAndSettle();

    final filter = container.read(saleDateFilterProvider);
    expect(filter.preset, DatePreset.week);
    expect(filter.from, DateTime(2026, 10, 26));
    expect(filter.to, DateTime(2026, 10, 26));
    expect(find.text('Clienta Futura'), findsOneWidget);
    expectFormUntouched();
  });

  testWidgets('a custom range is left as it was', (tester) async {
    current = DateTime(2026, 10, 25, 10);
    final container = await pump(tester, const SalesListBody());
    final custom = DateRangeFilter(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 10),
    );
    container.read(saleDateFilterProvider.notifier).state = custom;

    goToBackground(tester);
    current = DateTime(2026, 10, 26, 8);
    returnToForeground(tester);
    await tester.pumpAndSettle();

    expect(container.read(saleDateFilterProvider), custom);
  });

  testWidgets('the BI period shortcut moves to the new day', (tester) async {
    current = DateTime(2026, 10, 25, 10);
    final container = await pump(tester, const SalesListBody());
    final subscription = container.listen(biConfigProvider, (_, _) {});
    addTearDown(subscription.close);
    container.read(biConfigProvider.notifier).state = BiConfig(
      filters: ReportFilters(
        startDate: DatePreset.month.start(DateTime(2026, 10, 25)),
        endDate: DateTime(2026, 10, 25),
        datePreset: DatePreset.month,
      ),
    );

    goToBackground(tester);
    current = DateTime(2026, 11, 1, 8);
    returnToForeground(tester);
    await tester.pumpAndSettle();

    final filters = container.read(biConfigProvider).filters;
    expect(filters.datePreset, DatePreset.month);
    expect(filters.startDate, DateTime(2026, 11, 1));
    expect(filters.endDate, DateTime(2026, 11, 1));
  });

  testWidgets('Reportes keeps the applied shortcut and moves its dates to the new day', (
    tester,
  ) async {
    current = DateTime(2026, 10, 25, 10);
    await pump(tester, const ReportsPage());
    await pickPreset(tester, 'Hoy');
    expect(find.text('Limpiar'), findsOneWidget);
    expect(find.text('25 oct 2026'), findsNWidgets(2));

    goToBackground(tester);
    current = DateTime(2026, 10, 26, 8);
    returnToForeground(tester);
    await tester.pumpAndSettle();

    expect(find.text('Limpiar'), findsOneWidget);
    expect(find.text('25 oct 2026'), findsNothing);
    expect(find.text('26 oct 2026'), findsNWidgets(2));
  });
}
