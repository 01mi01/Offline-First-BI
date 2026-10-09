import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../application/search_filter.dart';
import '../../config/date_formatters.dart';
import '../../theme/app_theme.dart';
import 'focus_utils.dart';
import 'ios_controls.dart';
import 'ios_group.dart';
import 'ios_style.dart';
import 'searchable_picker.dart' show PickerOption;
import 'transaction_date_field.dart';

// Hoja inferior con esquinas redondeadas arriba, sobre fondo gris agrupado.
// Con [heightFactor] ocupa esa fracción de la pantalla; sin él, lo que mida su
// contenido.
Future<T?> showIosSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppIos.sheetRadius),
      ),
    ),
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final inset = media.viewInsets.bottom;
      final child = builder(ctx);
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

// Estructura de una hoja: asa, barra con acción a la izquierda, título al
// centro y acción a la derecha, y el contenido debajo.
class IosSheetScaffold extends StatelessWidget {
  final String title;
  final String? leadingLabel;
  final VoidCallback? onLeading;
  final String? trailingLabel;
  final VoidCallback? onTrailing;
  final Widget child;
  final bool expand;

  const IosSheetScaffold({
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
    return Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.s8),
        Container(
          width: AppIos.grabberWidth,
          height: AppIos.grabberHeight,
          decoration: BoxDecoration(
            color: AppColors.iosSeparator,
            borderRadius: BorderRadius.circular(AppIos.grabberHeight),
          ),
        ),
        SizedBox(
          height: AppIos.navBarHeight + AppSpacing.s4,
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: leadingLabel == null
                    ? null
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: _BarButton(
                          label: leadingLabel!,
                          onTap: onLeading ?? () => Navigator.maybePop(context),
                        ),
                      ),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IosText.navTitle(context),
                ),
              ),
              SizedBox(
                width: 96,
                child: trailingLabel == null
                    ? null
                    : Align(
                        alignment: Alignment.centerRight,
                        child: _BarButton(
                          label: trailingLabel!,
                          bold: true,
                          onTap: onTrailing ?? () => Navigator.maybePop(context),
                        ),
                      ),
              ),
            ],
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
        constraints: const BoxConstraints(minHeight: AppIos.minTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: IosText.link(context).copyWith(
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Fila de formulario que abre un selector con búsqueda en una hoja inferior.
// Con la búsqueda vacía solo se lista la opción predeterminada (valor nulo).
class IosPickerRow<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<PickerOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String searchHint;
  final Widget? action;

  const IosPickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.searchHint = 'Buscar',
    this.action,
  });

  String get _valueLabel {
    for (final option in options) {
      if (option.value == value) return option.selectedLabel ?? option.label;
    }
    return '';
  }

  Future<void> _open(BuildContext context) async {
    dismissKeyboard();
    final chosen = await showIosSheet<PickerOption<T>>(
      context,
      heightFactor: 0.7,
      builder: (_) => _IosPickerSheet<T>(
        title: label,
        searchHint: searchHint,
        options: options,
        value: value,
      ),
    );
    if (chosen != null) onChanged(chosen.value);
  }

  @override
  Widget build(BuildContext context) {
    return IosRow(
      title: label,
      onTap: () => _open(context),
      chevron: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              _valueLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IosText.rowTitle(context, color: AppColors.textSecondary),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _IosPickerSheet<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<PickerOption<T>> options;
  final T? value;

  const _IosPickerSheet({
    required this.title,
    required this.searchHint,
    required this.options,
    required this.value,
  });

  @override
  State<_IosPickerSheet<T>> createState() => _IosPickerSheetState<T>();
}

class _IosPickerSheetState<T> extends State<_IosPickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.trim().isNotEmpty;
    final visible = hasQuery
        ? filterByQuery<PickerOption<T>>(
            widget.options,
            _query,
            (o) => '${o.label} ${o.subtitle ?? ''}',
          )
        : widget.options.where((o) => o.value == null).toList();

    return IosSheetScaffold(
      title: widget.title,
      trailingLabel: 'Listo',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              0,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            child: IosSearchBar(
              hintText: widget.searchHint,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              children: [
                if (visible.isNotEmpty)
                  IosSection(
                    children: [
                      for (final option in visible)
                        IosRow(
                          title: option.label,
                          subtitle: option.subtitle == null
                              ? null
                              : Text(
                                  option.subtitle!,
                                  style: IosText.rowSubtitle(context),
                                ),
                          trailing: option.value == widget.value
                              ? const Icon(
                                  Icons.check,
                                  size: 22,
                                  color: AppColors.primaryDark,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, option),
                        ),
                    ],
                  ),
                if (!hasQuery)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Center(
                      child: Text(
                        'Escribe para buscar',
                        key: const ValueKey('picker-type-to-search'),
                        style: IosText.rowSubtitle(context),
                      ),
                    ),
                  )
                else if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Center(
                      child: Text(
                        'Sin resultados',
                        style: IosText.rowSubtitle(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Fila de formulario con una fecha, que abre el selector de fecha de ventas y
// compras (sin límite: pasada, hoy o futura).
class IosDateRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const IosDateRow({
    super.key,
    required this.date,
    required this.onChanged,
    this.label = 'Fecha',
  });

  Future<void> _pick(BuildContext context) async {
    dismissKeyboard();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: transactionFirstDate,
      lastDate: transactionLastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primaryDark)),
        child: child!,
      ),
    );
    if (picked != null) onChanged(withDayOf(picked, date));
  }

  @override
  Widget build(BuildContext context) {
    return IosRow(
      title: label,
      chevron: true,
      onTap: () => _pick(context),
      trailing: Text(
        formatDate(date),
        style: IosText.rowTitle(context, color: AppColors.textSecondary),
      ),
    );
  }
}

// Confirmación estilo iOS: centrada y redondeada, con las acciones apiladas
// separadas por líneas finas. La acción que se confirma va en rosa.
Future<bool> showIosConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String dismissLabel = 'Volver',
}) async {
  final result = await _showIosAlert<bool>(
    context,
    title: title,
    message: message,
    actions: (ctx) => [
      _DialogAction(
        label: confirmLabel,
        color: AppColors.error,
        bold: true,
        onTap: () => Navigator.pop(ctx, true),
      ),
      _DialogAction(
        label: dismissLabel,
        color: AppColors.primaryDark,
        onTap: () => Navigator.pop(ctx, false),
      ),
    ],
  );
  return result == true;
}

// Aviso informativo estilo iOS con un solo botón.
Future<void> showIosInfo(
  BuildContext context, {
  required String title,
  required String message,
  String actionLabel = 'Entendido',
}) {
  return _showIosAlert<void>(
    context,
    title: title,
    message: message,
    actions: (ctx) => [
      _DialogAction(
        label: actionLabel,
        color: AppColors.primaryDark,
        bold: true,
        onTap: () => Navigator.pop(ctx),
      ),
    ],
  );
}

Future<T?> _showIosAlert<T>(
  BuildContext context, {
  required String title,
  required String? message,
  required List<Widget> Function(BuildContext ctx) actions,
}) {
  dismissKeyboard();
  return showDialog<T>(
    context: context,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.4),
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppIos.groupRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s20,
                AppSpacing.s20,
                AppSpacing.s16,
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: IosText.navTitle(ctx),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: IosText.footnote(ctx).copyWith(height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ),
          for (final action in actions(ctx)) ...[
            const Divider(height: 1, color: AppColors.iosSeparator),
            action,
          ],
        ],
      ),
    ),
  );
}

class _DialogAction extends StatelessWidget {
  final String label;
  final Color color;
  final bool bold;
  final VoidCallback onTap;

  const _DialogAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: AppIos.minTap,
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: IosText.rowTitle(context, color: color).copyWith(
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
