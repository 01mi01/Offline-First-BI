import 'package:flutter/material.dart';
import '../../application/date_range_filter.dart';
import '../../theme/app_theme.dart';
import 'focus_utils.dart';
import '../../config/app_clock.dart';

Future<DateTime?> pickFilterDate(
  BuildContext context, {
  DateTime? initial,
}) {
  dismissKeyboard();
  final today = dateOnly(appNow());
  var start = dateOnly(initial ?? today);
  if (start.isAfter(today)) start = today;
  if (start.isBefore(filterFirstDate)) start = filterFirstDate;
  return showAppDatePicker(
    context,
    initialDate: start,
    firstDate: filterFirstDate,
    lastDate: today,
  );
}

final DatePickerThemeData _appDatePickerTheme = DatePickerThemeData(
  backgroundColor: AppColors.surface,
  surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
  ),
  cancelButtonStyle: TextButton.styleFrom(
    backgroundColor: AppColors.neutralButton,
    foregroundColor: AppColors.textPrimary,
    minimumSize: const Size(AppExtent.e96, AppButtons.height),
    textStyle: const TextStyle(fontSize: AppMetrics.buttonTextSize, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppButtons.radius),
    ),
  ),
  confirmButtonStyle: TextButton.styleFrom(
    backgroundColor: AppColors.cyanDark,
    foregroundColor: AppColors.onDark,
    minimumSize: const Size(AppExtent.e96, AppButtons.height),
    textStyle: const TextStyle(fontSize: AppMetrics.buttonTextSize, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppButtons.radius),
    ),
  ),
);

Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: ColorScheme.light(primary: AppColors.cyanDark),
        datePickerTheme: _appDatePickerTheme,
      ),
      child: child!,
    ),
  );
}

void showDateRangeError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

