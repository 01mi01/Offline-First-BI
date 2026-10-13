import 'dart:async';

import 'package:flutter/material.dart';
import '../../application/search_filter.dart';
import '../../theme/app_theme.dart';
import 'form_style.dart';
import 'form_widgets.dart';
import 'focus_utils.dart';
import 'app_controls.dart';
import 'app_style.dart';
import 'empty_state.dart';

// Opción de un [SearchablePickerField]. [value] puede ser null para la opción
// predeterminada ("Sin nombre", "Sin proveedor"...).
class PickerOption<T> {
  final T? value;
  final String label;
  final String? subtitle;
  // Texto que muestra el campo ya elegida la opción (por defecto, [label]).
  final String? selectedLabel;

  const PickerOption(this.value, this.label, {this.subtitle, this.selectedLabel});
}

// Selector de un registro existente con búsqueda en línea, igual que el
// buscador de productos: se escribe directamente en el campo y los resultados
// aparecen justo debajo (sin abrir ninguna ventana). Tocar un resultado lo
// elige. Pensado para listas largas, donde desplazarse por un desplegable
// corriente es impracticable.
//
// Con el campo vacío no se lista nada (podría haber cientos de elementos): solo
// la opción predeterminada ("Sin nombre", "Sin proveedor"), para poder volver a
// ella, y la invitación a escribir.
class SearchablePickerField<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<PickerOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String searchHint;

  // Toma el foco (y abre los resultados) apenas se muestra el campo.
  final bool autofocus;

  // Se llama cuando el campo pierde el foco (se eligió algo o se tocó fuera).
  final VoidCallback? onDismissed;

  // Botón junto a la etiqueta (p. ej. "+ Agregar"): se queda en la fila de la
  // etiqueta y los resultados se abren debajo del campo.
  final Widget? labelAction;

  // Campo de búsqueda con el aspecto común de las listas (opt-in).
  final bool searchStyle;

  // Sin etiqueta encima del campo (el texto de ayuda lo describe).
  final bool showLabel;

  const SearchablePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.searchHint = 'Buscar',
    this.autofocus = false,
    this.onDismissed,
    this.labelAction,
    this.searchStyle = false,
    this.showLabel = true,
  });

  @override
  State<SearchablePickerField<T>> createState() =>
      _SearchablePickerFieldState<T>();
}

class _SearchablePickerFieldState<T> extends State<SearchablePickerField<T>>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _revealTimer;

  String get _selectedLabel {
    for (final option in widget.options) {
      if (option.value == widget.value) return option.selectedLabel ?? option.label;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _controller.text = _selectedLabel;
    _focus.addListener(_onFocusChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(SearchablePickerField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sin foco, el campo muestra siempre lo elegido (aunque cambie desde
    // fuera o las opciones terminen de cargar).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focus.hasFocus) return;
      final label = _selectedLabel;
      if (_controller.text != label) _controller.text = label;
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  // El teclado terminó de abrirse (o cambió de alto): los resultados deben
  // seguir a la vista.
  @override
  void didChangeMetrics() => _reveal();

  void _onFocusChange() {
    if (_focus.hasFocus) {
      // Se empieza a buscar de cero: lo elegido vuelve a verse al salir.
      _controller.clear();
      setState(() {});
      _reveal();
    } else {
      _controller.text = _selectedLabel;
      setState(() {});
      widget.onDismissed?.call();
    }
  }

  // Deja el campo con sus resultados debajo a la vista, por encima del teclado.
  // Solo se hace al enfocar y cuando el teclado termina de abrirse o cambia de
  // alto; escribir o que cambie la lista de resultados no vuelve a mover la
  // pantalla (el campo está por encima de los resultados, así que su posición
  // no cambia). Se espera un instante para que el propio campo de texto (que
  // también se desplaza para mostrar el cursor) termine primero y no se pisen.
  void _reveal() {
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_focus.hasFocus) return;
      revealFieldAtTop(context);
    });
  }

  InputDecoration _decoration(
    BuildContext context,
    String? labelText,
    bool focused,
    String query,
  ) {
    final clear = focused && query.isNotEmpty
        ? IconButton(
            tooltip: 'Borrar búsqueda',
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
            onPressed: () {
              _controller.clear();
              setState(() {});
            },
          )
        : null;
    if (widget.searchStyle) {
      return appSearchDecoration(
        context,
        hintText: widget.searchHint,
        labelText: labelText,
        suffixIcon: clear,
      );
    }
    return InputDecoration(
      labelText: labelText,
      hintText: widget.searchHint,
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: AppColors.textSecondary,
        size: 20,
      ),
      suffixIcon: clear,
    );
  }

  Widget _sized(Widget field) => widget.searchStyle
      ? SizedBox(height: AppMetrics.controlHeight, child: field)
      : field;

  void _choose(PickerOption<T> option) {
    _controller.text = option.selectedLabel ?? option.label;
    widget.onChanged(option.value);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final query = _controller.text;
    final hasQuery = focused && query.trim().isNotEmpty;
    final inForm = AppFormTheme.isActive(context);
    final visible = hasQuery
        ? filterByQuery<PickerOption<T>>(
            widget.options,
            query,
            (o) => '${o.label} ${o.subtitle ?? ''}',
          )
        : widget.options.where((o) => o.value == null).toList();

    // Con el teclado abierto queda poco alto: la lista se acorta para no
    // desbordar pantallas chicas. El alto del teclado se lee de la vista (un
    // Scaffold se lo quita al MediaQuery de su contenido).
    final media = MediaQuery.of(context);
    final view = View.of(context);
    final keyboardHeight = view.viewInsets.bottom / view.devicePixelRatio;
    final maxResultsHeight = ((media.size.height - keyboardHeight) *
            0.3)
        .clamp(120.0, 200.0);

    return TextFieldTapRegion(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: widget.label,
            inset: widget.searchStyle ? 0 : AppSpacing.s4,
            hidden: !widget.showLabel,
            action: widget.labelAction,
            builder: (labelText) => _sized(TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            // Tocar fuera cierra los resultados (los toques dentro del campo o
            // de la lista no cuentan como "fuera").
            onTapOutside: (_) => _focus.unfocus(),
            textInputAction: TextInputAction.search,
            // Sin margen extra: si el campo ya está a la vista, escribir no lo
            // desplaza (la pantalla solo se mueve al enfocar).
            scrollPadding: EdgeInsets.zero,
            onChanged: (_) => setState(() {}),
            decoration: _decoration(context, labelText, focused, query),
          ))),
          if (focused) ...[
            const SizedBox(height: AppSpacing.s8),
            // Alto fijo: la lista de resultados no cambia de tamaño mientras se
            // escribe, así que lo que hay encima (el campo) no se mueve cuando
            // los resultados aparecen, aumentan o disminuyen.
            Container(
              height: maxResultsHeight,
              decoration: AppFormTheme.isActive(context)
                  ? BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(
                        AppMetrics.groupRadius,
                      ),
                      border: Border.all(color: AppColors.border),
                    )
                  : BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.s8),
                children: [
                  for (final option in visible) _buildTile(context, option),
                  if (!hasQuery)
                    inForm
                        ? const AppEmptyState.hint(
                            key: ValueKey('picker-type-to-search'),
                            icon: Icons.search_rounded,
                            text: 'Escribe para buscar.',
                            compact: true,
                          )
                        : const Padding(
                            padding: EdgeInsets.all(AppSpacing.s16),
                            child: Center(
                              child: Text(
                                'Escribe para buscar',
                                key: ValueKey('picker-type-to-search'),
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                  else if (visible.isEmpty)
                    inForm
                        ? const AppEmptyState.noMatch(compact: true)
                        : const Padding(
                            padding: EdgeInsets.all(AppSpacing.s16),
                            child: Center(
                              child: Text(
                                'Sin resultados',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, PickerOption<T> option) {
    final isSelected = option.value == widget.value;
    final inForm = AppFormTheme.isActive(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      title: Text(
        option.label,
        style: inForm
            ? AppText.rowSubtitle(
                context,
                color: AppColors.textPrimary,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              )
            : Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
      ),
      subtitle: option.subtitle == null
          ? null
          : Text(
              option.subtitle!,
              style: inForm
                  ? AppText.footnote(context)
                  : Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
            ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.cyanDark)
          : null,
      onTap: () => _choose(option),
    );
  }
}
