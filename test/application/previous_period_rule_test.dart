import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/bi_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/home_dashboard.dart';
import 'package:offline_first_bi/config/app_clock.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/bi_config.dart';
import 'package:offline_first_bi/models/date_preset.dart';
import 'package:offline_first_bi/models/report_filters.dart';

typedef _Range = (DateTime, DateTime);

void main() {
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

  test('on the 1st of a month today compares with yesterday', () async {
    final today = d(2026, 11, 1);
    await expectCase(today, {
      DatePreset.today: (d(2026, 10, 31), d(2026, 10, 31)),
      DatePreset.week: (d(2026, 10, 19), d(2026, 10, 25)),
      DatePreset.month: (d(2026, 10, 1), d(2026, 10, 1)),
      DatePreset.year: (d(2025, 1, 1), d(2025, 11, 1)),
    });
  });

  test('on January 1 every preset looks at the previous year', () async {
    final today = d(2027, 1, 1);
    await expectCase(today, {
      DatePreset.today: (d(2026, 12, 31), d(2026, 12, 31)),
      DatePreset.week: (d(2026, 12, 21), d(2026, 12, 25)),
      DatePreset.month: (d(2026, 12, 1), d(2026, 12, 1)),
      DatePreset.year: (d(2026, 1, 1), d(2026, 1, 1)),
    });
  });

  test('in March after a shorter February the month is cut to its last day', () async {
    final today = d(2026, 3, 30);
    await expectCase(today, {
      DatePreset.today: (d(2026, 3, 29), d(2026, 3, 29)),
      DatePreset.week: (d(2026, 3, 23), d(2026, 3, 23)),
      DatePreset.month: (d(2026, 2, 1), d(2026, 2, 28)),
      DatePreset.year: (d(2025, 1, 1), d(2025, 3, 30)),
    });
  });

  test('a leap day maps to the last day of February of the previous year', () async {
    final today = d(2028, 2, 29);
    await expectCase(today, {
      DatePreset.today: (d(2028, 2, 28), d(2028, 2, 28)),
      DatePreset.week: (d(2028, 2, 21), d(2028, 2, 22)),
      DatePreset.month: (d(2028, 1, 1), d(2028, 1, 29)),
      DatePreset.year: (d(2027, 1, 1), d(2027, 2, 28)),
    });
  });

  test('a custom Desde/Hasta range keeps the equal-length rule', () async {
    setAppClockForTesting(() => DateTime(2026, 10, 25, 15));
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    final c = container
        .read(
          biReportProvider(
            BiQuery(
              filters: ReportFilters(
                startDate: d(2026, 10, 1),
                endDate: d(2026, 10, 10),
              ),
            ),
          ),
        )
        .periodComparison;
    await settle();
    container.dispose();
    expect((c.previousStart, c.previousEnd), (d(2026, 9, 21), d(2026, 9, 30)));
  });
}
