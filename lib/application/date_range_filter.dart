import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_clock.dart';
import '../models/date_preset.dart';

export '../models/date_preset.dart';

const futureDateMessage = 'La fecha no puede ser posterior a hoy';
const rangeOrderMessage = 'La fecha "Hasta" no puede ser anterior a "Desde"';

final DateTime filterFirstDate = DateTime(2020);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isFutureDated(DateTime date, {DateTime? now}) =>
    dateOnly(date).isAfter(dateOnly(now ?? appNow()));

String? validateDateRange({DateTime? from, DateTime? to, DateTime? now}) {
  final today = dateOnly(now ?? appNow());
  if (from != null && dateOnly(from).isAfter(today)) return futureDateMessage;
  if (to != null && dateOnly(to).isAfter(today)) return futureDateMessage;
  if (from != null && to != null && dateOnly(to).isBefore(dateOnly(from))) {
    return rangeOrderMessage;
  }
  return null;
}

class DateRangeFilter {
  final DateTime? from;
  final DateTime? to;
  final DatePreset? preset;

  const DateRangeFilter({this.from, this.to, this.preset});

  factory DateRangeFilter.forPreset(DatePreset preset, {DateTime? now}) {
    final today = dateOnly(now ?? appNow());
    return DateRangeFilter(
      from: preset.start(today),
      to: today,
      preset: preset,
    );
  }

  bool get isActive => from != null || to != null;

  DateTime? get effectiveTo => to ?? from;

  DateRangeFilter withFrom(DateTime? value) =>
      DateRangeFilter(from: value == null ? null : dateOnly(value), to: to);

  DateRangeFilter withTo(DateTime? value) =>
      DateRangeFilter(from: from, to: value == null ? null : dateOnly(value));

  bool matches(DateTime date) => overlaps(date, date);

  bool overlaps(DateTime start, DateTime? end) {
    final s = dateOnly(start);
    final e = dateOnly(end ?? start);
    if (from != null && e.isBefore(dateOnly(from!))) return false;
    final last = effectiveTo;
    if (last != null && s.isAfter(dateOnly(last))) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is DateRangeFilter &&
      other.from == from &&
      other.to == to &&
      other.preset == preset;

  @override
  int get hashCode => Object.hash(from, to, preset);
}

enum RecordTimeFilter {
  current,
  all;

  bool includes(DateTime date) =>
      this == RecordTimeFilter.all || !isFutureDated(date);
}

final saleDateFilterProvider = StateProvider.autoDispose<DateRangeFilter>(
  (ref) => const DateRangeFilter(),
);
final purchaseDateFilterProvider = StateProvider.autoDispose<DateRangeFilter>(
  (ref) => const DateRangeFilter(),
);
final saleTimeFilterProvider = StateProvider.autoDispose<RecordTimeFilter>(
  (ref) => RecordTimeFilter.current,
);
final purchaseTimeFilterProvider = StateProvider.autoDispose<RecordTimeFilter>(
  (ref) => RecordTimeFilter.current,
);
final eventDateFilterProvider = StateProvider.autoDispose<DateRangeFilter>(
  (ref) => const DateRangeFilter(),
);
