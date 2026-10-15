import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';

// Quita el foco del campo de texto activo (y con él el teclado) antes de abrir
// un diálogo, un selector de fecha o una hoja inferior.
//
// Si no se hace, Flutter le devuelve el foco al campo que lo tenía cuando esa
// ruta se cierra, y el teclado reaparece sin que la persona haya tocado ningún
// campo. Así, el teclado solo se muestra cuando la persona enfoca un campo.
void dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}

// Deja a la vista un campo con sus resultados debajo con el menor movimiento
// posible: solo desplaza, y solo en vertical, si el bloque se sale por abajo
// (teclado) o por arriba del área visible. Si ya cabe no se mueve nada, así que
// abrir o cerrar el teclado no hace saltar el campo.
Future<void> revealFieldAtTop(
  BuildContext context, {
  double margin = AppSpacing.s16,
}) async {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached) return;

  ScrollableState? scrollable = Scrollable.maybeOf(context);
  while (scrollable != null) {
    final viewport = scrollable.context.findRenderObject();
    final outer = scrollable.context.findAncestorStateOfType<ScrollableState>();
    if (viewport is RenderBox &&
        viewport.attached &&
        box.attached &&
        scrollable.position.axis == Axis.vertical) {
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final bottom = top + box.size.height;
      final visible = viewport.size.height;
      var delta = 0.0;
      if (bottom > visible - margin) {
        delta = math.min(bottom - (visible - margin), top - margin);
      }
      if (top - delta < margin) delta = top - margin;
      if (delta.abs() >= 1) {
        final position = scrollable.position;
        final target = (position.pixels + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if (target != position.pixels) {
          await position.animateTo(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          if (!context.mounted || !scrollable.mounted) return;
        }
      }
    }
    scrollable = outer;
  }
}
