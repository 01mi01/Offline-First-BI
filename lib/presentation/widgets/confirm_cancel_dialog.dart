import 'package:flutter/material.dart';
import 'ios_sheet.dart';

// Confirmación antes de cancelar o desactivar un registro. Devuelve true solo
// si la persona confirma; el botón de salida se llama "Volver" por omisión.
Future<bool> confirmCancellation(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String dismissLabel = 'Volver',
}) => showIosConfirm(
  context,
  title: title,
  message: message,
  confirmLabel: confirmLabel,
  dismissLabel: dismissLabel,
);
