import 'package:flutter/material.dart';
import '../../application/search_filter.dart';
import '../../theme/app_theme.dart';

// Opción de un [SearchablePickerField]. [value] puede ser null para la opción
// predeterminada ("Sin nombre", "Sin proveedor"...).
class PickerOption<T> {
  final T? value;
  final String label;
  final String? subtitle;

  const PickerOption(this.value, this.label, {this.subtitle});
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

  // Botón junto al campo (p. ej. "agregar nuevo"). Queda en la fila del campo:
  // los resultados se abren debajo de esa fila, sin mover el botón.
  final Widget? trailing;

  const SearchablePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.searchHint = 'Buscar',
    this.autofocus = false,
    this.onDismissed,
    this.trailing,
  });

  @override
  State<SearchablePickerField<T>> createState() =>
      _SearchablePickerFieldState<T>();
}

class _SearchablePickerFieldState<T> extends State<SearchablePickerField<T>>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  String get _selectedLabel {
    for (final option in widget.options) {
      if (option.value == widget.value) return option.label;
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

  // Desplaza el formulario lo justo para que el campo y sus resultados no
  // queden tapados por el teclado.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focus.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Widget _withTrailing(Widget field) {
    final trailing = widget.trailing;
    if (trailing == null) return field;
    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: AppSpacing.s8),
        trailing,
      ],
    );
  }

  void _choose(PickerOption<T> option) {
    _controller.text = option.label;
    widget.onChanged(option.value);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final query = _controller.text;
    final hasQuery = focused && query.trim().isNotEmpty;
    final visible = hasQuery
        ? filterByQuery<PickerOption<T>>(widget.options, query, (o) => o.label)
        : widget.options.where((o) => o.value == null).toList();

    // Con el teclado abierto queda poco alto: la lista se acorta para no
    // desbordar pantallas chicas.
    final media = MediaQuery.of(context);
    final maxResultsHeight = ((media.size.height - media.viewInsets.bottom) *
            0.3)
        .clamp(120.0, 200.0);

    return TextFieldTapRegion(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _withTrailing(TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            // Tocar fuera cierra los resultados (los toques dentro del campo o
            // de la lista no cuentan como "fuera").
            onTapOutside: (_) => _focus.unfocus(),
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              setState(() {});
              // La lista de resultados cambia de alto al escribir.
              _reveal();
            },
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.searchHint,
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 20,
              ),
              suffixIcon: focused && query.isNotEmpty
                  ? IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      onPressed: () {
                        _controller.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          )),
          if (focused) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              constraints: BoxConstraints(maxHeight: maxResultsHeight),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.s8),
                shrinkWrap: true,
                children: [
                  for (final option in visible) _buildTile(context, option),
                  if (!hasQuery)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Center(
                        child: Text(
                          'Escribe para buscar',
                          key: const ValueKey('picker-type-to-search'),
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
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
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      title: Text(
        option.label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: option.subtitle == null
          ? null
          : Text(
              option.subtitle!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: () => _choose(option),
    );
  }
}
