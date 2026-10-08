import 'dart:async';

import 'package:flutter/material.dart';
import '../../application/status_filter.dart';
import '../../theme/app_theme.dart';
import 'focus_utils.dart';

// Piezas reutilizables para buscar y filtrar las vistas de lista y de catálogo
// (Productos, Categorías).

// Campo de búsqueda redondeado, con botón para borrar el texto.
class CatalogSearchField extends StatefulWidget {
  final String initialText;
  final String hintText;
  final ValueChanged<String> onChanged;

  const CatalogSearchField({
    super.key,
    required this.initialText,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends State<CatalogSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (value) {
        setState(() {}); // muestra u oculta el botón de borrar
        widget.onChanged(value);
      },
      textInputAction: TextInputAction.search,
      // Sin margen extra: si el campo ya está a la vista, escribir no lo
      // desplaza (ver RevealOnFocus).
      scrollPadding: EdgeInsets.zero,
      decoration: InputDecoration(
        hintText: widget.hintText,
        isDense: true,
        prefixIcon: const Icon(
          Icons.search,
          color: AppColors.textSecondary,
          size: 20,
        ),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(
                  Icons.close,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
      ),
    );
  }
}

class FilterOption<T> {
  final T value;
  final String label;

  const FilterOption(this.value, this.label);
}

// Chip que abre un menú con las opciones de un filtro. Se resalta cuando el
// filtro no está en su valor por defecto ([active]).
class FilterMenuChip<T> extends StatelessWidget {
  // Sin icono si es null.
  final IconData? icon;
  final String label;
  // Ancho máximo del texto; si no cabe se recorta con puntos suspensivos.
  final double maxLabelWidth;
  final bool active;
  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const FilterMenuChip({
    super.key,
    this.icon,
    this.maxLabelWidth = 160,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return PopupMenuButton<int>(
      tooltip: label,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (index) => onSelected(options[index].value),
      itemBuilder: (context) => [
        for (var i = 0; i < options.length; i++)
          CheckedPopupMenuItem<int>(
            value: i,
            checked: options[i].value == selected,
            child: Text(options[i].label),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.s6),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Icon(Icons.arrow_drop_down, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

// Fila de chips de filtro que se desplaza en horizontal si no caben.
class FilterChipRow extends StatelessWidget {
  final List<Widget> chips;

  const FilterChipRow({super.key, required this.chips});

  // Alineados a la derecha, igual que el chip de estado de las demás listas;
  // si no caben en una línea pasan a la siguiente.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: chips,
        ),
      ),
    );
  }
}

// Envuelve un buscador con resultados debajo (p. ej. el de productos dentro del
// formulario de venta): al enfocarlo, lleva el buscador al borde de arriba del
// área que se desplaza, para que lo escrito quede por encima del teclado y los
// resultados se vean debajo. Solo actúa al enfocar y cuando el teclado termina
// de abrirse; escribir no vuelve a mover la pantalla.
class RevealOnFocus extends StatefulWidget {
  final Widget child;

  const RevealOnFocus({super.key, required this.child});

  @override
  State<RevealOnFocus> createState() => _RevealOnFocusState();
}

class _RevealOnFocusState extends State<RevealOnFocus>
    with WidgetsBindingObserver {
  bool _focused = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _reveal();

  // Se espera un instante para que el propio campo de texto (que también se
  // desplaza para mostrar el cursor) termine primero y no se pisen.
  void _reveal() {
    if (!_focused) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_focused) return;
      revealFieldAtTop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        _focused = hasFocus;
        _reveal();
      },
      child: widget.child,
    );
  }
}

// Cabecera común de las listas: los filtros arriba, alineados a la derecha
// (pasan a otra línea si no caben), y debajo el buscador a todo el ancho con,
// si hay, un botón a su derecha (p. ej. el toggle lista/catálogo). Productos,
// Categorías, Clientes, Proveedores, Eventos y Ubicaciones la comparten, así
// que filtros, buscador y botones quedan en las mismas posiciones.
class CatalogListHeader extends StatelessWidget {
  final List<Widget> chips;
  final Widget search;
  final Widget? trailing;
  // Se muestra entre los filtros y el buscador (p. ej. el filtro por fechas).
  final Widget? between;

  const CatalogListHeader({
    super.key,
    required this.chips,
    required this.search,
    this.trailing,
    this.between,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s12),
            child: FilterChipRow(chips: chips),
          ),
        ?between,
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s16,
            chips.isEmpty && between == null ? AppSpacing.s12 : AppSpacing.s8,
            AppSpacing.s16,
            AppSpacing.s8,
          ),
          child: Row(
            children: [
              Expanded(child: search),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.s8),
                trailing!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Chip del filtro por estado (Activos / Inactivos / Todos). [feminine] da las
// etiquetas en femenino (Activas / Inactivas / Todas) para listas como
// "Ubicaciones".
class StatusFilterChip extends StatelessWidget {
  final StatusFilter value;
  final ValueChanged<StatusFilter> onChanged;
  final bool feminine;

  const StatusFilterChip({
    super.key,
    required this.value,
    required this.onChanged,
    this.feminine = false,
  });

  String _label(StatusFilter f) => switch (f) {
    StatusFilter.all => feminine ? 'Todas' : 'Todos',
    StatusFilter.active => feminine ? 'Activas' : 'Activos',
    StatusFilter.inactive => feminine ? 'Inactivas' : 'Inactivos',
  };

  @override
  Widget build(BuildContext context) {
    return FilterMenuChip<StatusFilter>(
      label: _label(value),
      active: value != StatusFilter.all,
      selected: value,
      options: [
        for (final f in StatusFilter.values) FilterOption(f, _label(f)),
      ],
      onSelected: onChanged,
    );
  }
}
