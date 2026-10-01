import 'package:flutter/material.dart';
import '../../application/search_filter.dart';
import '../../theme/app_theme.dart';
import 'focus_utils.dart';

// Opción de un [SearchablePickerField]. [value] puede ser null para la opción
// predeterminada ("Sin nombre", "Sin proveedor"...).
class PickerOption<T> {
  final T? value;
  final String label;
  final String? subtitle;

  const PickerOption(this.value, this.label, {this.subtitle});
}

// Resultado de la hoja: envuelve el valor para distinguir "se eligió la opción
// nula" de "se cerró sin elegir".
class _PickerChoice<T> {
  final T? value;
  const _PickerChoice(this.value);
}

// Selector de un registro existente con búsqueda: parece el campo desplegable
// de siempre, pero al tocarlo abre una hoja con un buscador (se filtra al
// escribir) y la lista de opciones. Pensado para listas largas, donde
// desplazarse por un desplegable corriente es impracticable.
class SearchablePickerField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<PickerOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String searchHint;

  const SearchablePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.searchHint = 'Buscar',
  });

  String get _selectedLabel {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return '';
  }

  Future<void> _open(BuildContext context) async {
    dismissKeyboard();
    final choice = await showModalBottomSheet<_PickerChoice<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PickerSheet<T>(
        title: label,
        searchHint: searchHint,
        options: options,
        selected: value,
      ),
    );
    if (choice != null) onChanged(choice.value);
  }

  @override
  Widget build(BuildContext context) {
    final text = _selectedLabel;
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () => _open(context),
      child: InputDecorator(
        isEmpty: text.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.textSecondary,
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PickerSheet<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<PickerOption<T>> options;
  final T? selected;

  const _PickerSheet({
    required this.title,
    required this.searchHint,
    required this.options,
    required this.selected,
  });

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = filterByQuery<PickerOption<T>>(
      widget.options,
      _query,
      (o) => o.label,
    );
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s16,
        right: AppSpacing.s16,
        top: AppSpacing.s20,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              isDense: true,
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Flexible(
            child: visible.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s24,
                    ),
                    child: Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final option = visible[index];
                      final isSelected = option.value == widget.selected;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          option.label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: option.subtitle == null
                            ? null
                            : Text(
                                option.subtitle!,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.pop(
                          context,
                          _PickerChoice<T>(option.value),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
