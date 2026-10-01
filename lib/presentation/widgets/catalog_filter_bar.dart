import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
  final IconData icon;
  final String label;
  final bool active;
  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const FilterMenuChip({
    super.key,
    required this.icon,
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
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.s6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s8),
            chips[i],
          ],
        ],
      ),
    );
  }
}
