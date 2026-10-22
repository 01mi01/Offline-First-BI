import 'package:flutter/material.dart';

class FormSheetScope extends InheritedWidget {
  final ValueNotifier<bool> dirty;

  const FormSheetScope({super.key, required this.dirty, required super.child});

  static FormSheetScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FormSheetScope>();

  @override
  bool updateShouldNotify(FormSheetScope oldWidget) => dirty != oldWidget.dirty;
}

class FormSheetRoute<T> extends ModalBottomSheetRoute<T> {
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);

  FormSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.isScrollControlled = false,
    super.useSafeArea = false,
  });

  @override
  bool get enableDrag => !dirty.value;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FormSheetScope(
      dirty: dirty,
      child: ValueListenableBuilder<bool>(
        valueListenable: dirty,
        builder: (context, _, _) =>
            super.buildPage(context, animation, secondaryAnimation),
      ),
    );
  }

  @override
  void dispose() {
    dirty.dispose();
    super.dispose();
  }
}
