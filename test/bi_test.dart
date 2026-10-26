import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/bi_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/date_range_filter.dart';
import 'package:offline_first_bi/application/home_dashboard.dart';
import 'package:offline_first_bi/application/today_provider.dart';
import 'package:offline_first_bi/config/app_clock.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/bi_config.dart';
import 'package:offline_first_bi/models/bi_models.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/presentation/widgets/day_change_watcher.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'helpers/bi_harness.dart';

typedef _Range = (DateTime, DateTime);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('indicators', () {
    final h = BiHarness();
    setUp(h.setUp);
    tearDown(h.tearDown);

    DateTime day(int offset, [int hour = 12]) => h.day(offset, hour);
    final refresh = h.refresh;
    final newProduct = h.newProduct;
    final sell = h.sell;
    final spend = h.spend;
    BiReport report([ReportFilters filters = const ReportFilters()]) =>
        h.report(filters);

    test('summary excludes canceled and future-dated records', () async {
      final p = await newProduct('Tote bag negra');
      await sell(day(0), p, 2, 100);
      await sell(day(-5), p, 1, 50);
      await sell(day(3), p, 1, 999);
      await sell(day(-1), p, 1, 777);
      await spend(day(-2), 30);
      await spend(day(4), 888);
      await h.cancelSaleOf(777);
      await refresh();

      final summary = report().summary;
      expect(summary.ingresos, 250);
      expect(summary.gastos, 30);
      expect(summary.balance, 220);
    });
  });

  group('previous period', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      setAppClockForTesting();
      await db.close();
    });

    DateTime d(int y, int m, int day) => DateTime(y, m, day);

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 200));

    Future<_Range> biPrevious(DatePreset preset, DateTime today) async {
      setAppClockForTesting(() => DateTime(today.year, today.month, today.day, 15));
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final report = container.read(
        biReportProvider(
          BiQuery(
            filters: ReportFilters(
              startDate: preset.start(today),
              endDate: today,
              datePreset: preset,
            ),
          ),
        ),
      );
      final c = report.periodComparison;
      await settle();
      container.dispose();
      return (c.previousStart!, c.previousEnd!);
    }

    _Range homePrevious(DatePreset preset, DateTime today) {
      final range = HomePeriod.values.byName(preset.name).previous(today);
      return (range.start, range.end);
    }

    Future<void> expectCase(
      DateTime today,
      Map<DatePreset, _Range> expected,
    ) async {
      for (final entry in expected.entries) {
        final preset = entry.key;
        final reason = '${preset.name} on $today';
        expect(homePrevious(preset, today), entry.value, reason: reason);
        expect(await biPrevious(preset, today), entry.value, reason: reason);
      }
    }

    test('on a Monday the week compares with the previous Monday', () async {
      final today = d(2026, 10, 26);
      expect(today.weekday, DateTime.monday);
      await expectCase(today, {
        DatePreset.today: (d(2026, 10, 25), d(2026, 10, 25)),
        DatePreset.week: (d(2026, 10, 19), d(2026, 10, 19)),
        DatePreset.month: (d(2026, 9, 1), d(2026, 9, 26)),
        DatePreset.year: (d(2025, 1, 1), d(2025, 10, 26)),
      });
    });
  });

  group('midnight refresh', () {
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
  });
}
