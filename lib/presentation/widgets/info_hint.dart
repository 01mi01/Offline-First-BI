import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_buttons.dart';
import 'focus_utils.dart';

Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  dismissKeyboard();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        title,
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        0,
        AppSpacing.s20,
        AppSpacing.s20,
      ),
      actions: [
        AppActionButton(
          label: 'Cerrar',
          kind: AppButtonKind.neutral,
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

