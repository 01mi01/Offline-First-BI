import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';
import 'form_style.dart';

// Hoja inferior de la app (formularios y detalles): esquinas redondeadas
// arriba con el radio estándar, sin asa y siempre con un margen libre bajo la
// barra de estado del teléfono. Con [heightFactor] ocupa esa fracción de la
// pantalla; sin él, lo que mida su contenido. Los campos de texto de su
// interior toman el aspecto común de los formularios.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
}) {
  final media = MediaQuery.of(context);
  // Alto máximo: la pantalla menos la barra de estado y el margen de arriba.
  final maxHeight = media.size.height - media.padding.top - AppMetrics.sheetTopGap;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: AppColors.background,
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(maxHeight: maxHeight),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppMetrics.sheetRadius),
      ),
    ),
    builder: (ctx) {
      final inset = MediaQuery.of(ctx).viewInsets.bottom;
      final child = AppFormTheme(child: builder(ctx));
      if (heightFactor == null) {
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: child,
        );
      }
      final height = math.min(
        media.size.height * heightFactor,
        maxHeight - inset,
      );
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(height: height, child: child),
      );
    },
  );
}

// Estructura de una hoja: título arriba, el contenido que se desplaza y, fijos
// abajo, los botones de [actions]. Los botones nunca flotan sobre el contenido:
// este termina donde empiezan ellos y respetan la barra inferior del teléfono.
class AppSheetScaffold extends StatelessWidget {
  final String title;
  final Key? titleKey;
  final Widget child;
  final Widget? actions;
  final bool expand;

  const AppSheetScaffold({
    super.key,
    required this.title,
    this.titleKey,
    required this.child,
    this.actions,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = expand ? Expanded(child: child) : Flexible(child: child);
    return Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        SizedBox(
          height: AppMetrics.minTap + AppSpacing.s8,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.s8,
              left: AppSpacing.s16,
              right: AppSpacing.s16,
            ),
            child: Center(
              child: Text(
                title,
                key: titleKey,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.navTitle(context),
              ),
            ),
          ),
        ),
        body,
        if (actions != null) SheetActionBar(child: actions!),
      ],
    );
  }
}

// Franja fija de botones al pie de una hoja: línea fina arriba y espacio para
// la barra inferior del teléfono.
class SheetActionBar extends StatelessWidget {
  final Widget child;

  const SheetActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.separator)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s16,
          AppSpacing.s16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: child,
      ),
    );
  }
}

// Hoja de un formulario sencillo (crear o editar un registro): título arriba y,
// debajo, los campos y, como último elemento del mismo contenido, los botones de
// [actions]: se llega a ellos desplazándose. [children] van dentro de un [Form]
// con [formKey].
class FormSheet extends StatelessWidget {
  final String title;
  final GlobalKey<FormState>? formKey;
  final List<Widget> children;
  final Widget? actions;

  const FormSheet({
    super.key,
    required this.title,
    required this.children,
    this.formKey,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: title,
      expand: false,
      child: Form(
        key: formKey,
        child: FormScroll(
          children: [
            ...children,
            if (actions != null) ...[
              const SizedBox(height: AppSpacing.s24),
              actions!,
            ],
          ],
        ),
      ),
    );
  }
}

// Contenido que se desplaza de un formulario: los botones del final llevan
// espacio de sobra debajo, por encima de la barra del sistema.
class FormScroll extends StatelessWidget {
  final List<Widget> children;

  const FormScroll({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s32 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
