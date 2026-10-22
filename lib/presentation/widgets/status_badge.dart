import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final bool positive;
  final Color? _text;
  final Color? _background;

  const StatusBadge.purchaseType({super.key, required bool isMaterial})
    : label = isMaterial ? 'Material' : 'Gasto',
      positive = isMaterial,
      _text = isMaterial ? null : AppColors.blue,
      _background = isMaterial ? null : AppColors.blueSoft;

  const StatusBadge.forState({
    super.key,
    required bool isActive,
    String activeLabel = 'Activo',
    String inactiveLabel = 'Inactivo',
  }) : label = isActive ? activeLabel : inactiveLabel,
       positive = isActive,
       _text = null,
       _background = null;

  const StatusBadge.canceled({super.key, this.label = 'Cancelada'})
    : positive = false,
      _text = null,
      _background = null;

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
        color: _background ?? backgroundColor(positive),
        borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: _text ?? textColor(positive),
        ),
      ),
    );
  }
}
