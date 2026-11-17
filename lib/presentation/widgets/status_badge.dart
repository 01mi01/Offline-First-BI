import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final bool positive;
  final bool _expense;

  const StatusBadge.purchaseType({super.key, required bool isMaterial})
    : label = isMaterial ? 'Material' : 'Gasto',
      positive = isMaterial,
      _expense = !isMaterial;

  const StatusBadge.forState({
    super.key,
    required bool isActive,
    String activeLabel = 'Activo',
    String inactiveLabel = 'Inactivo',
  }) : label = isActive ? activeLabel : inactiveLabel,
       positive = isActive,
       _expense = false;

  const StatusBadge.canceled({super.key, this.label = 'Cancelada'})
    : positive = false,
      _expense = false;

  static Color textColor(bool positive) =>
      positive ? AppColors.successDark : AppColors.error;

  static Color backgroundColor(bool positive) =>
      positive ? AppColors.successSoft : AppColors.errorSoft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: _expense ? AppColors.blueSoft : backgroundColor(positive),
        borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: _expense ? AppColors.blue : textColor(positive),
        ),
      ),
    );
  }
}
