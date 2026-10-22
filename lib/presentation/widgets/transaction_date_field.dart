import 'package:flutter/material.dart';
import 'date_pickers.dart';
import 'focus_utils.dart';

final DateTime transactionFirstDate = DateTime(2000);
final DateTime transactionLastDate = DateTime(2100);

DateTime withDayOf(DateTime picked, DateTime base) => DateTime(
  picked.year,
  picked.month,
  picked.day,
  base.hour,
  base.minute,
  base.second,
);

Future<DateTime?> pickTransactionDate(
  BuildContext context,
  DateTime current,
) async {
  dismissKeyboard();
  final picked = await showAppDatePicker(
    context,
    initialDate: current,
    firstDate: transactionFirstDate,
    lastDate: transactionLastDate,
  );
  return picked == null ? null : withDayOf(picked, current);
}
