import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'focus_utils.dart';

// Confirmación antes de cancelar un registro (venta o registro de uso). Mismo
// estilo que las confirmaciones de "Desactivar": el registro no se borra, se
// conserva como historial marcado como cancelado.
//
// Devuelve true solo si la persona confirma. Por defecto el botón de salida se
// llama "Volver", para no confundirlo con la acción "Cancelar" que se confirma;
// las confirmaciones de "Desactivar" pasan [dismissLabel] = 'Cancelar'.
//
// El [message] va centrado; si es nulo el diálogo solo muestra el título y las
// acciones (p. ej. "¿Cerrar sesión?").
Future<bool> confirmCancellation(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String dismissLabel = 'Volver',
}) async {
  // Sin esto el teclado reaparece al cerrar el diálogo (ver focus_utils.dart).
  dismissKeyboard();
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // Todo el diálogo va centrado: título, mensaje y botones.
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      content: message == null
          ? null
          : Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              0,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            // Botones apilados a todo el ancho: así el texto completo de la
            // acción ("Cancelar registro", "Cerrar sesión"...) siempre cabe,
            // sin cortarse con puntos suspensivos.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s14,
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    confirmLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.surface),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s14,
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    dismissLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  return confirm == true;
}
