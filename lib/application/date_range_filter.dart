import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_clock.dart';

// Filtro por rango de fechas de las listas (Ventas, Compras, Eventos): atajos
// (Hoy, Esta semana, Este mes, Este año) o un rango Desde/Hasta a medida.
// Trabaja con días completos: las horas se ignoran.

// Solo para filtros y reportes: la fecha de una venta, compra o evento al
// crearlo no pasa por estas reglas.
const futureDateMessage = 'La fecha no puede ser posterior a hoy';
const rangeOrderMessage = 'La fecha "Hasta" no puede ser anterior a "Desde"';

// Primer día que ofrecen los selectores de fecha de filtros y reportes.
final DateTime filterFirstDate = DateTime(2020);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// ¿La fecha de un registro es posterior a hoy? Se compara por día: algo
// fechado hoy a cualquier hora ya cuenta como ocurrido.
bool isFutureDated(DateTime date, {DateTime? now}) =>
    dateOnly(date).isAfter(dateOnly(now ?? appNow()));

// Valida un rango Desde/Hasta. Devuelve el mensaje del primer problema o null
// si es válido: ninguna fecha puede ser posterior a hoy y Hasta no puede ser
// anterior a Desde (el mismo día en ambas sí es válido).
String? validateDateRange({DateTime? from, DateTime? to, DateTime? now}) {
  final today = dateOnly(now ?? appNow());
  if (from != null && dateOnly(from).isAfter(today)) return futureDateMessage;
  if (to != null && dateOnly(to).isAfter(today)) return futureDateMessage;
  if (from != null && to != null && dateOnly(to).isBefore(dateOnly(from))) {
    return rangeOrderMessage;
  }
  return null;
}

enum DatePreset {
  today('Hoy'),
  week('Esta semana'),
  month('Este mes'),
  year('Este año');

  final String label;
  const DatePreset(this.label);
}

class DateRangeFilter {
  final DateTime? from;
  final DateTime? to;
  // Atajo que generó el rango; null si se eligió a mano (o no hay filtro).
  final DatePreset? preset;

  const DateRangeFilter({this.from, this.to, this.preset});

  // Rango de un atajo hasta hoy: como ninguna fecha de filtro puede ser
  // posterior a hoy, "Esta semana" va del lunes a hoy, y así los demás.
  factory DateRangeFilter.forPreset(DatePreset preset, {DateTime? now}) {
    final today = dateOnly(now ?? appNow());
    final from = switch (preset) {
      DatePreset.today => today,
      DatePreset.week => DateTime(
        today.year,
        today.month,
        today.day - (today.weekday - DateTime.monday),
      ),
      DatePreset.month => DateTime(today.year, today.month),
      DatePreset.year => DateTime(today.year),
    };
    return DateRangeFilter(from: from, to: today, preset: preset);
  }

  bool get isActive => from != null || to != null;

  // Con solo "Desde" (sin "Hasta") se filtra ese único día.
  DateTime? get effectiveTo => to ?? from;

  // Cambia solo Desde / Hasta (siempre es un rango a medida, sin atajo).
  DateRangeFilter withFrom(DateTime? value) =>
      DateRangeFilter(from: value == null ? null : dateOnly(value), to: to);

  DateRangeFilter withTo(DateTime? value) =>
      DateRangeFilter(from: from, to: value == null ? null : dateOnly(value));

  // ¿Un registro con esta fecha cae dentro del rango?
  bool matches(DateTime date) => overlaps(date, date);

  // ¿Un registro que dura de [start] a [end] (o solo [start]) toca el rango?
  // Sirve para eventos de varios días.
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

// Filtro de las listas de Ventas y Compras para ocultar los registros con fecha
// futura: "actuales" (hasta hoy inclusive, por omisión) o "todas". Solo cambia
// lo que muestra la lista; se combina con los demás filtros.
enum RecordTimeFilter {
  current,
  all;

  bool includes(DateTime date, {DateTime? now}) =>
      this == RecordTimeFilter.all || !isFutureDated(date, now: now);
}

// Estado del filtro de cada pantalla. Viven mientras la pantalla está abierta.
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
