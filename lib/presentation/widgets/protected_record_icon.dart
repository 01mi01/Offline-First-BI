import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Indicador de un registro predeterminado del sistema: reemplaza al botón de
// editar, porque no se puede editar ni desactivar. [message] es el texto de
// [DefaultRecords] que corresponde a cada entidad (categoría, cliente...).
class ProtectedRecordIcon extends StatelessWidget {
  final String message;

  const ProtectedRecordIcon({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Tooltip(
        message: message,
        triggerMode: TooltipTriggerMode.tap,
        child: const Icon(
          Icons.lock_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}
