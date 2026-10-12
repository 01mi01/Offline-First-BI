import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';
import 'form_style.dart';

// Hoja inferior de la app (formularios y detalles): esquinas redondeadas
// arriba con el radio estándar y sin asa. Con [heightFactor] ocupa esa fracción
// de la pantalla; sin él, lo que mida su contenido. Los campos de texto de su
// interior toman el aspecto común de los formularios.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: AppColors.background,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppMetrics.sheetRadius),
      ),
    ),
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final inset = media.viewInsets.bottom;
      final child = AppFormTheme(child: builder(ctx));
      if (heightFactor == null) {
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: child,
        );
      }
      final height = math.min(
        media.size.height * heightFactor,
        media.size.height - inset - media.padding.top,
      );
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(height: height, child: child),
      );
    },
  );
}

// Ancho de cada lado de la barra: cabe "Cancelar" en una línea.
const double _barSlotWidth = 112;

// Estructura de una hoja: barra con acción a la izquierda, título al centro y
// acción a la derecha, y el contenido debajo.
class AppSheetScaffold extends StatelessWidget {
  final String title;
  final String? leadingLabel;
  final VoidCallback? onLeading;
  final String? trailingLabel;
  final VoidCallback? onTrailing;
  final Widget child;
  final bool expand;

  const AppSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.leadingLabel,
    this.onLeading,
    this.trailingLabel,
    this.onTrailing,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = expand ? Expanded(child: child) : Flexible(child: child);
    // Sin acciones en la barra, el título usa casi todo el ancho.
    final slot = leadingLabel == null && trailingLabel == null
        ? AppSpacing.s16
        : _barSlotWidth;
    return Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        SizedBox(
          height: AppMetrics.minTap + AppSpacing.s8,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: Row(
              children: [
                SizedBox(
                  width: slot,
                  child: leadingLabel == null
                      ? null
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: _BarButton(
                            label: leadingLabel!,
                            onTap:
                                onLeading ?? () => Navigator.maybePop(context),
                          ),
                        ),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.navTitle(context),
                  ),
                ),
                SizedBox(
                  width: slot,
                  child: trailingLabel == null
                      ? null
                      : Align(
                          alignment: Alignment.centerRight,
                          child: _BarButton(
                            label: trailingLabel!,
                            bold: true,
                            onTap:
                                onTrailing ?? () => Navigator.maybePop(context),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        body,
      ],
    );
  }
}

class _BarButton extends StatelessWidget {
  final String label;
  final bool bold;
  final VoidCallback onTap;

  const _BarButton({
    required this.label,
    required this.onTap,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppMetrics.minTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: AppText.link(context).copyWith(
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Hoja de un formulario sencillo (crear o editar un registro): título arriba,
// campos que se desplazan y, al final del contenido, los botones. [children]
// van dentro de un [Form] con [formKey].
class FormSheet extends StatelessWidget {
  final String title;
  final GlobalKey<FormState>? formKey;
  final List<Widget> children;

  const FormSheet({
    super.key,
    required this.title,
    required this.children,
    this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: title,
      expand: false,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s8,
            AppSpacing.s16,
            AppSpacing.s24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
