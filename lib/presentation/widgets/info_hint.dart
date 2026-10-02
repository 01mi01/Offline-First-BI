import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'focus_utils.dart';

// Explicación breve de un campo que puede confundir. Mismo estilo centrado que
// las confirmaciones, pero informativo: un solo botón "Entendido".
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  // Sin esto el teclado reaparece al cerrar el diálogo (ver focus_utils.dart).
  dismissKeyboard();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      content: Text(
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
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s14),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ),
        ),
      ],
    ),
  );
}

// Icono "i" para el final de un campo: al tocarlo explica el campo.
class InfoHintButton extends StatelessWidget {
  final String title;
  final String message;

  const InfoHintButton({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: title,
      icon: const Icon(
        Icons.info_outline,
        color: AppColors.textSecondary,
        size: 20,
      ),
      onPressed: () => showInfoDialog(context, title: title, message: message),
    );
  }
}
