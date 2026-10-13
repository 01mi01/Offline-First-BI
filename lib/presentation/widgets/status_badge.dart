import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Pastilla de estado de un registro: "Activo"/"Inactivo" (o su forma femenina) y
// "Cancelada"/"Cancelado". Un solo widget para todas las listas, detalles y
// formularios, con el aspecto de la pastilla de Inicio: activo en verde sobre
// verde suave; inactivo y cancelado en rojo sobre rojo suave. Los colores de
// texto oscuros (error/successDark) cumplen el contraste mínimo sobre su fondo.
// El tipo de una compra usa la misma pastilla: "Material" en verde y "Gasto" en
// azul acero sobre azul suave.
class StatusBadge extends StatelessWidget {
  final String label;
  final bool positive;
  // Colores propios (el tipo "Gasto"): sustituyen a los de [positive].
  final Color? _text;
  final Color? _background;

  const StatusBadge({super.key, required this.label, required this.positive})
    : _text = null,
      _background = null;

  // Tipo de una compra: "Material" (verde, como Activo) o "Gasto" (azul).
  const StatusBadge.purchaseType({super.key, required bool isMaterial})
    : label = isMaterial ? 'Material' : 'Gasto',
      positive = isMaterial,
      _text = isMaterial ? null : AppColors.blue,
      _background = isMaterial ? null : AppColors.blueSoft;

  // Activo / Activa
  const StatusBadge.active({super.key, this.label = 'Activo'})
    : positive = true,
      _text = null,
      _background = null;

  // Inactivo / Inactiva
  const StatusBadge.inactive({super.key, this.label = 'Inactivo'})
    : positive = false,
      _text = null,
      _background = null;

  // Según el estado de un registro; [activeLabel]/[inactiveLabel] permiten el
  // género ("Activa"/"Inactiva").
  StatusBadge.forState({
    super.key,
    required bool isActive,
    String activeLabel = 'Activo',
    String inactiveLabel = 'Inactivo',
  }) : label = isActive ? activeLabel : inactiveLabel,
       positive = isActive,
       _text = null,
       _background = null;

  // "Cancelada" / "Cancelado"
  const StatusBadge.canceled({super.key, this.label = 'Cancelada'})
    : positive = false,
      _text = null,
      _background = null;

  // Color del texto y del fondo (público para poder comprobar el contraste).
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
        borderRadius: BorderRadius.circular(50),
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
