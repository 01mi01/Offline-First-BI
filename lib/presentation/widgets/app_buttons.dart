import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum AppButtonKind { destructive, neutral }

// Botón de acción a todo el ancho con el mismo estilo del botón principal:
// rojo para cancelar o desactivar y gris para salir sin cambiar nada.
class AppActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final EdgeInsetsGeometry padding;

  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.kind,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ElevatedButton(
        onPressed: onPressed,
        style: kind == AppButtonKind.destructive
            ? destructiveButtonStyle
            : neutralButtonStyle,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
