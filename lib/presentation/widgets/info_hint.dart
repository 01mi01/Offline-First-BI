import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'ios_sheet.dart';

// Explicación breve de un campo que puede confundir.
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) => showIosInfo(context, title: title, message: message);

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
