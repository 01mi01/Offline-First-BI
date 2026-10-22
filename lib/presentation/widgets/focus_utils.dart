import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';

void dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}

Future<void> revealFieldAtTop(BuildContext context) async {
  const margin = AppSpacing.s16;
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
