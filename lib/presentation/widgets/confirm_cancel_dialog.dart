import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_buttons.dart';
import 'focus_utils.dart';

Future<bool> confirmCancellation(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Volver',
  AppButtonKind confirmKind = AppButtonKind.destructive,
}) async {
  dismissKeyboard();
  var answered = false;
  void answer(BuildContext ctx, bool value) {
    if (answered) return;
    answered = true;
    Navigator.pop(ctx, value);
  }

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
              kind: confirmKind,
              onPressed: () => answer(ctx, true),
            ),
            const SizedBox(height: AppButtons.stackGap),
            AppActionButton(
              label: cancelLabel,
              kind: AppButtonKind.neutral,
              onPressed: () => answer(ctx, false),
            ),
          ],
        ),
      ],
    ),
  );
  return confirm == true;
}

Future<bool> confirmDiscardChanges(BuildContext context) {
  return confirmCancellation(
    context,
    title: '¿Descartar los cambios?',
    message: 'Los datos escritos se perderán.',
    confirmLabel: 'Descartar',
    cancelLabel: 'Seguir editando',
  );
}
