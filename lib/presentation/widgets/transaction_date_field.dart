import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'focus_utils.dart';

// Fecha de una venta o una compra. A diferencia de los filtros y reportes, aquí
// NO hay límite: se puede registrar algo pasado (se anota tarde) o futuro (se
// deja preparado). Las fechas elegibles van de 2000 a 2100.
final DateTime transactionFirstDate = DateTime(2000);
final DateTime transactionLastDate = DateTime(2100);

// La fecha elegida conserva la hora del registro: solo cambia el día.
DateTime withDayOf(DateTime picked, DateTime base) => DateTime(
  picked.year,
  picked.month,
  picked.day,
  base.hour,
  base.minute,
  base.second,
);

// Abre el selector de fecha de una venta o compra y devuelve la fecha elegida
// (con la hora de [current]), o null si se cierra sin elegir.
Future<DateTime?> pickTransactionDate(
  BuildContext context,
  DateTime current,
) async {
  dismissKeyboard();
  final picked = await showDatePicker(
    context: context,
    initialDate: current,
    firstDate: transactionFirstDate,
    lastDate: transactionLastDate,
    builder: (ctx, child) => Theme(
      data: Theme.of(
        ctx,
      ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.cyanDark)),
      child: child!,
    ),
  );
  return picked == null ? null : withDayOf(picked, current);
}
