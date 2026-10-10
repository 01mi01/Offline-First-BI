import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_buttons.dart';
import 'focus_utils.dart';

// Confirmación antes de cancelar o desactivar un registro. Devuelve true solo
// si la persona confirma; el botón de salida se llama "Volver" por omisión.
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
      title: Text(
        title,
        textAlign: TextAlign.center,
      ),
      content: message == null
          ? null
          : Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        0,
        AppSpacing.s20,
        AppSpacing.s20,
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppActionButton(
              label: confirmLabel,
              kind: AppButtonKind.destructive,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: AppButtons.stackGap),
            AppActionButton(
              label: dismissLabel,
              kind: AppButtonKind.neutral,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ],
    ),
  );
  return confirm == true;
}
