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

// Lleva un campo con resultados debajo al borde de arriba del área que se
// desplaza, con un pequeño margen: lo escrito queda por encima del teclado y los
// resultados se ven debajo. El margen deja entera la etiqueta del campo, que
// flota sobre su borde superior y sobresale de su caja; sin él, quedaba cortada
// bajo el encabezado. Si el campo ya está en su sitio no se mueve nada, así que
// los cambios del teclado no lo hacen saltar.
Future<void> revealFieldAtTop(
  BuildContext context, {
  double margin = AppSpacing.s16,
}) async {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached) return;

  double? topIn(ScrollableState scrollable) {
    final viewport = scrollable.context.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached || !box.attached) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: viewport).dy;
  }

  final nearest = Scrollable.maybeOf(context);
  final top = nearest == null ? null : topIn(nearest);
  if (top != null && (top - margin).abs() < 1) return;

  const duration = Duration(milliseconds: 200);
  await Scrollable.ensureVisible(
    context,
    alignment: 0,
    duration: duration,
    curve: Curves.easeOut,
  );

  // Lo anterior deja el campo pegado al borde: se sube el margen en cada área
  // que se desplaza por encima de él.
  if (!context.mounted) return;
  ScrollableState? scrollable = Scrollable.maybeOf(context);
  while (scrollable != null) {
    // ignore: use_build_context_synchronously
    final outer = scrollable.context.findAncestorStateOfType<ScrollableState>();
    final current = topIn(scrollable);
    if (current != null && current < margin) {
      final position = scrollable.position;
      final target = (position.pixels - (margin - current)).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (target != position.pixels) {
        await position.animateTo(
          target,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
        if (!context.mounted || !scrollable.mounted) return;
      }
    }
    scrollable = outer;
  }
}
