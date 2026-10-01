import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/date_range_filter.dart';

// Atajos de fecha, validación de rangos Desde/Hasta y coincidencia de fechas
// de los filtros de Ventas, Compras, Eventos y Reportes.
void main() {
  // Miércoles 30 de septiembre de 2026.
  final wednesday = DateTime(2026, 9, 30, 15, 45);

  group('presets always end today (no filter date can be in the future)', () {
    test('Hoy is today..today', () {
      final r = DateRangeFilter.forPreset(DatePreset.today, now: wednesday);
      expect(r.from, DateTime(2026, 9, 30));
      expect(r.to, DateTime(2026, 9, 30));
      expect(r.preset, DatePreset.today);
    });

    test('Esta semana runs from Monday to today', () {
      final r = DateRangeFilter.forPreset(DatePreset.week, now: wednesday);
      expect(r.from, DateTime(2026, 9, 28));
      expect(r.to, DateTime(2026, 9, 30));
    });

    test('Esta semana on a Monday is just that day, on a Sunday starts 6 days back', () {
      final monday = DateRangeFilter.forPreset(
        DatePreset.week,
        now: DateTime(2026, 9, 28),
      );
      expect(monday.from, DateTime(2026, 9, 28));
      final sunday = DateRangeFilter.forPreset(
        DatePreset.week,
        now: DateTime(2026, 10, 4),
      );
      expect(sunday.from, DateTime(2026, 9, 28));
      expect(sunday.to, DateTime(2026, 10, 4));
    });

    test('the week can start in the previous month', () {
      // Jueves 1 de octubre de 2026 -> el lunes fue el 28 de septiembre.
      final r = DateRangeFilter.forPreset(
        DatePreset.week,
        now: DateTime(2026, 10, 1),
      );
      expect(r.from, DateTime(2026, 9, 28));
    });

    test('Este mes and Este año start on the 1st', () {
      final month = DateRangeFilter.forPreset(DatePreset.month, now: wednesday);
      expect(month.from, DateTime(2026, 9, 1));
      expect(month.to, DateTime(2026, 9, 30));
      final year = DateRangeFilter.forPreset(DatePreset.year, now: wednesday);
      expect(year.from, DateTime(2026, 1, 1));
      expect(year.to, DateTime(2026, 9, 30));
    });

    test('every preset is a valid range', () {
      for (final p in DatePreset.values) {
        final r = DateRangeFilter.forPreset(p, now: wednesday);
        expect(validateDateRange(from: r.from, to: r.to, now: wednesday), isNull);
      }
    });

    test('labels are the Spanish names', () {
      expect(DatePreset.values.map((p) => p.label), [
        'Hoy',
        'Esta semana',
        'Este mes',
        'Este año',
      ]);
    });
  });

  group('validateDateRange', () {
    test('no dates, one date or an ordered range are valid', () {
      expect(validateDateRange(now: wednesday), isNull);
      expect(validateDateRange(from: DateTime(2026, 9, 1), now: wednesday), isNull);
      expect(validateDateRange(to: DateTime(2026, 9, 1), now: wednesday), isNull);
      expect(
        validateDateRange(
          from: DateTime(2026, 9, 1),
          to: DateTime(2026, 9, 20),
          now: wednesday,
        ),
        isNull,
      );
    });

    test('a same-day range is valid, including Desde = Hasta = today', () {
      expect(
        validateDateRange(
          from: DateTime(2026, 9, 10),
          to: DateTime(2026, 9, 10, 23, 59),
          now: wednesday,
        ),
        isNull,
      );
      expect(
        validateDateRange(
          from: DateTime(2026, 9, 30),
          to: DateTime(2026, 9, 30),
          now: wednesday,
        ),
        isNull,
      );
    });

    test('Hasta before Desde is rejected', () {
      expect(
        validateDateRange(
          from: DateTime(2026, 9, 20),
          to: DateTime(2026, 9, 19),
          now: wednesday,
        ),
        rangeOrderMessage,
      );
    });

    test('today is the latest date: tomorrow is rejected in either field', () {
      final tomorrow = DateTime(2026, 10, 1);
      expect(validateDateRange(from: tomorrow, now: wednesday), futureDateMessage);
      expect(validateDateRange(to: tomorrow, now: wednesday), futureDateMessage);
      expect(
        validateDateRange(
          from: DateTime(2026, 9, 1),
          to: tomorrow,
          now: wednesday,
        ),
        futureDateMessage,
      );
      // La hora de hoy no cuenta como "futuro".
      expect(
        validateDateRange(to: DateTime(2026, 9, 30, 23, 59), now: wednesday),
        isNull,
      );
    });
  });

  group('matching', () {
    test('an empty filter matches everything', () {
      const r = DateRangeFilter();
      expect(r.isActive, isFalse);
      expect(r.matches(DateTime(1999)), isTrue);
    });

    test('Desde and Hasta are both inclusive whole days', () {
      final r = DateRangeFilter(
        from: DateTime(2026, 9, 10),
        to: DateTime(2026, 9, 12),
      );
      expect(r.matches(DateTime(2026, 9, 9, 23, 59)), isFalse);
      expect(r.matches(DateTime(2026, 9, 10, 0, 0)), isTrue);
      expect(r.matches(DateTime(2026, 9, 12, 23, 59)), isTrue);
      expect(r.matches(DateTime(2026, 9, 13)), isFalse);
    });

    test('only Desde or only Hasta leave the other side open', () {
      final from = DateRangeFilter(from: DateTime(2026, 9, 10));
      expect(from.matches(DateTime(2030)), isTrue);
      expect(from.matches(DateTime(2026, 9, 9)), isFalse);
      final to = DateRangeFilter(to: DateTime(2026, 9, 10));
      expect(to.matches(DateTime(2020)), isTrue);
      expect(to.matches(DateTime(2026, 9, 11)), isFalse);
    });

    test('a multi-day event matches when any of its days is in range', () {
      final r = DateRangeFilter(
        from: DateTime(2026, 9, 10),
        to: DateTime(2026, 9, 12),
      );
      // Termina dentro / empieza dentro / abarca el rango / fuera.
      expect(r.overlaps(DateTime(2026, 9, 5), DateTime(2026, 9, 10)), isTrue);
      expect(r.overlaps(DateTime(2026, 9, 12), DateTime(2026, 9, 20)), isTrue);
      expect(r.overlaps(DateTime(2026, 9, 1), DateTime(2026, 9, 30)), isTrue);
      expect(r.overlaps(DateTime(2026, 9, 1), DateTime(2026, 9, 9)), isFalse);
      expect(r.overlaps(DateTime(2026, 9, 13), null), isFalse);
      // Sin fecha de fin cuenta solo su día de inicio.
      expect(r.overlaps(DateTime(2026, 9, 11), null), isTrue);
    });

    test('picking Desde / Hasta by hand drops the preset', () {
      final preset = DateRangeFilter.forPreset(DatePreset.month, now: wednesday);
      expect(preset.preset, DatePreset.month);
      final custom = preset.withFrom(DateTime(2026, 9, 5, 18));
      expect(custom.preset, isNull);
      expect(custom.from, DateTime(2026, 9, 5));
      expect(custom.to, DateTime(2026, 9, 30));
      expect(custom.withTo(null).to, isNull);
    });
  });

  test('each list keeps its own filter, empty by default', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(saleDateFilterProvider).isActive, isFalse);
    expect(c.read(purchaseDateFilterProvider).isActive, isFalse);
    expect(c.read(eventDateFilterProvider).isActive, isFalse);
    c.read(saleDateFilterProvider.notifier).state = DateRangeFilter.forPreset(
      DatePreset.today,
    );
    expect(c.read(purchaseDateFilterProvider).isActive, isFalse);
    expect(c.read(eventDateFilterProvider).isActive, isFalse);
  });
}
