import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Indicador de un registro predeterminado del sistema: reemplaza al botón de
// editar, porque no se puede renombrar, editar ni desactivar.
class ProtectedRecordIcon extends StatelessWidget {
  const ProtectedRecordIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.s12),
      child: Tooltip(
        message: 'Registro predeterminado: no se puede editar ni desactivar',
        triggerMode: TooltipTriggerMode.tap,
        child: Icon(
          Icons.lock_outline,
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}
