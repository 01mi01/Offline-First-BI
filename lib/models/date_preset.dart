enum DatePreset {
  today('Hoy'),
  week('Esta semana'),
  month('Este mes'),
  year('Este año');

  final String label;
  const DatePreset(this.label);

  DateTime start(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return switch (this) {
      DatePreset.today => day,
      DatePreset.week => DateTime(
        day.year,
        day.month,
        day.day - (day.weekday - DateTime.monday),
      ),
      DatePreset.month => DateTime(day.year, day.month),
      DatePreset.year => DateTime(day.year),
    };
  }

  ({DateTime start, DateTime end}) previous(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    final from = start(day);
    int lastDay(int year, int month) => DateTime(year, month + 1, 0).day;
    switch (this) {
      case DatePreset.today:
        final yesterday = DateTime(day.year, day.month, day.day - 1);
        return (start: yesterday, end: yesterday);
      case DatePreset.week:
        return (
          start: DateTime(from.year, from.month, from.day - 7),
          end: DateTime(day.year, day.month, day.day - 7),
        );
      case DatePreset.month:
        final first = DateTime(day.year, day.month - 1);
        final last = lastDay(first.year, first.month);
        return (
          start: first,
          end: DateTime(first.year, first.month, day.day < last ? day.day : last),
        );
      case DatePreset.year:
        final last = lastDay(day.year - 1, day.month);
        return (
          start: DateTime(day.year - 1),
          end: DateTime(day.year - 1, day.month, day.day < last ? day.day : last),
        );
    }
  }
}
