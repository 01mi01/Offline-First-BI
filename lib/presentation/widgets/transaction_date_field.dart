import 'package:flutter/material.dart';
import '../../config/date_formatters.dart';
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

class TransactionDateField extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const TransactionDateField({
    super.key,
    required this.date,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    dismissKeyboard();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: transactionFirstDate,
      lastDate: transactionLastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.cyanDark)),
        child: child!,
      ),
    );
    if (picked != null) onChanged(withDayOf(picked, date));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s14,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.s12),
            Text(
              'Fecha: ${formatDate(date)}',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
