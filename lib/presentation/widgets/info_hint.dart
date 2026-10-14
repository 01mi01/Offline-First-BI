import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'focus_utils.dart';

// Explicación breve de un campo que puede confundir.
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
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

