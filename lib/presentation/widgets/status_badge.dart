import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Etiqueta de estado de un registro: "Activo"/"Inactivo" (o su forma
// femenina) y "Cancelada"/"Cancelado". Un solo widget para toda la app, con
// colores de texto oscuros (errorDark/successDark) que cumplen el contraste
// mínimo sobre su fondo tenue.
class StatusBadge extends StatelessWidget {
  final String label;
  final bool positive;

  const StatusBadge({super.key, required this.label, required this.positive});

  // Activo / Activa
  const StatusBadge.active({super.key, this.label = 'Activo'}) : positive = true;

  // Inactivo / Inactiva
  const StatusBadge.inactive({super.key, this.label = 'Inactivo'})
    : positive = false;

  // Según el estado de un registro; [activeLabel]/[inactiveLabel] permiten el
  // género ("Activa"/"Inactiva").
  StatusBadge.forState({
    super.key,
    required bool isActive,
    String activeLabel = 'Activo',
    String inactiveLabel = 'Inactivo',
  }) : label = isActive ? activeLabel : inactiveLabel,
       positive = isActive;

  // "Cancelada" / "Cancelado"
  const StatusBadge.canceled({super.key, this.label = 'Cancelada'})
    : positive = false;

  // Color del texto y del fondo (público para poder comprobar el contraste).
  static Color textColor(bool positive) =>
      positive ? AppColors.successDark : AppColors.errorDark;

  static Color backgroundColor(bool positive) =>
      (positive ? AppColors.success : AppColors.error).withOpacity(0.1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor(positive),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor(positive),
        ),
      ),
    );
  }
}
