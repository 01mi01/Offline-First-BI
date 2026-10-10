import 'package:flutter/material.dart';
import '../../application/date_range_filter.dart';
import '../../application/status_filter.dart';
import '../../config/date_formatters.dart';
import '../../theme/app_theme.dart';
import 'app_controls.dart';
import 'date_range_filter_bar.dart' show pickFilterDate, showDateRangeError;
import 'focus_utils.dart';

class FilterOption<T> {
  final T value;
  final String label;

  const FilterOption(this.value, this.label);
}

List<FilterOption<StatusFilter>> statusFilterOptions({bool feminine = false}) =>
    [
      for (final f in StatusFilter.values)
        FilterOption(f, statusFilterLabel(f, feminine: feminine)),
    ];

String statusFilterLabel(StatusFilter f, {bool feminine = false}) => switch (f) {
  StatusFilter.all => feminine ? 'Todas' : 'Todos',
  StatusFilter.active => feminine ? 'Activas' : 'Activos',
  StatusFilter.inactive => feminine ? 'Inactivas' : 'Inactivos',
};

// Un filtro del panel. Los cambios se aplican al momento.
abstract class FilterField {
  Object? get current;
  Object? get defaultValue;
  bool get fullWidth => false;

  // Texto del valor aplicado cuando difiere del valor por defecto.
  String? get summary;

  Widget build(BuildContext context);

  void apply(Object? value);
}

bool _isActive(FilterField field) => field.current != field.defaultValue;

class FilterDropdown<T> extends FilterField {
  final String label;
  final List<FilterOption<T>> options;
  @override
  final T current;
  @override
  final T defaultValue;
  final ValueChanged<T> onApply;
  final bool wide;

  FilterDropdown({
    required this.label,
    required this.options,
    required this.current,
    required this.defaultValue,
    required this.onApply,
    this.wide = false,
  });

  @override
  bool get fullWidth => wide;

  String _labelOf(T value) => options
      .firstWhere(
        (o) => o.value == value,
        orElse: () => options.first,
      )
      .label;

  @override
  String? get summary => _labelOf(current);

  @override
  void apply(Object? value) => onApply(value as T);

  @override
  Widget build(BuildContext context) {
    final active = current != defaultValue;
    return _Labeled(
      label: label,
      child: LayoutBuilder(
        builder: (context, constraints) => PopupMenuButton<int>(
        tooltip: label,
        position: PopupMenuPosition.under,
        constraints: BoxConstraints(
          minWidth: constraints.maxWidth,
          maxWidth: constraints.maxWidth,
          maxHeight: AppMetrics.menuMaxHeight,
        ),
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
        ),
        onSelected: (i) => onApply(options[i].value),
        itemBuilder: (context) => [
          for (var i = 0; i < options.length; i++)
            CheckedPopupMenuItem<int>(
              value: i,
              checked: options[i].value == current,
              child: Text(options[i].label),
            ),
        ],
        child: Container(
          height: AppMetrics.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.track,
            borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _labelOf(current),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: filterValueStyle(context, active: active),
                ),
              ),
              Icon(
                Icons.unfold_more_rounded,
                size: 18,
                color: active ? AppColors.cyanDark : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// Atajos de periodo y fechas Desde / Hasta.
class FilterDates extends FilterField {
  @override
  final DateRangeFilter current;
  final ValueChanged<DateRangeFilter> onApply;

  FilterDates({required this.current, required this.onApply});

  @override
  bool get fullWidth => true;

  @override
  Object? get defaultValue => const DateRangeFilter();

  @override
  String? get summary {
    final preset = current.preset;
    if (preset != null) return preset.label;
    final from = current.from;
    final to = current.to;
    if (from != null && to != null) {
      return '${formatDateShort(from)} - ${formatDateShort(to)}';
    }
    if (from != null) return 'Desde ${formatDateShort(from)}';
    if (to != null) return 'Hasta ${formatDateShort(to)}';
    return null;
  }

  @override
  void apply(Object? value) => onApply(value as DateRangeFilter);

  void _set(
    BuildContext context, {
    DateTime? from,
    DateTime? to,
  }) {
    final next = from != null ? current.withFrom(from) : current.withTo(to);
    final error = validateDateRange(from: next.from, to: next.to);
    if (error != null) {
      showDateRangeError(context, error);
      return;
    }
    onApply(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Labeled(
          label: 'Período',
          child: Wrap(
            spacing: AppSpacing.s6,
            runSpacing: 0,
            children: [
              for (final preset in DatePreset.values)
                _PresetPill(
                  label: preset.label,
                  selected: current.preset == preset,
                  onTap: () => onApply(
                    current.preset == preset
                        ? const DateRangeFilter()
                        : DateRangeFilter.forPreset(preset),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(
              child: _DateBox(
                label: 'Desde',
                date: current.from,
                onPicked: (d) => _set(context, from: d),
                onClear: () => onApply(current.withFrom(null)),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _DateBox(
                label: 'Hasta',
                date: current.to,
                onPicked: (d) => _set(context, to: d),
                onClear: () => onApply(current.withTo(null)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;

  const _Labeled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s6),
          child: Text(label, style: filterLabelStyle(context)),
        ),
        child,
      ],
    );
  }
}

class _PresetPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppMetrics.minTap),
        child: Center(
          widthFactor: 1,
          child: Container(
            height: AppMetrics.presetHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.track,
              borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: filterValueStyle(context, active: selected),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback onClear;

  const _DateBox({
    required this.label,
    required this.date,
    required this.onPicked,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final active = date != null;
    return _Labeled(
      label: label,
      child: InkWell(
        onTap: () async {
          final picked = await pickFilterDate(context, initial: date);
          if (picked != null && context.mounted) onPicked(picked);
        },
        borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
        child: Container(
          height: AppMetrics.segmentedHeight,
          padding: const EdgeInsets.only(left: AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.track,
            borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: active ? AppColors.cyanDark : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    active ? formatDateShort(date!) : 'Seleccionar',
                    maxLines: 1,
                    softWrap: false,
                    style: active
                        ? filterValueStyle(context, active: true)
                        : filterNameStyle(context),
                  ),
                ),
              ),
              if (active)
                IconButton(
                  tooltip: 'Quitar $label',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: AppColors.chevron,
                  ),
                  onPressed: onClear,
                )
              else
                const SizedBox(width: AppSpacing.s12),
            ],
          ),
        ),
      ),
    );
  }
}

// Botón cuadrado de filtros, con una insignia con la cantidad de filtros
// distintos de su valor por defecto.
class FilterButton extends StatelessWidget {
  final int count;
  final bool open;
  final VoidCallback onTap;

  const FilterButton({
    super.key,
    required this.count,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = open || count > 0;
    return Semantics(
      button: true,
      label: 'Filtros',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
        child: Container(
          width: AppMetrics.controlHeight,
          height: AppMetrics.controlHeight,
          decoration: BoxDecoration(
            color: AppColors.track,
            borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 22,
                color: highlighted ? AppColors.cyanDark : AppColors.textSecondary,
              ),
              if (count > 0)
                Positioned(
                  top: AppSpacing.s4,
                  right: AppSpacing.s4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cyanDark,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$count',
                      style: filterValueStyle(context).copyWith(
                        color: AppColors.onDark,
                        fontSize: AppMetrics.filterLabelSize,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Resumen de los filtros activos con un enlace para limpiarlos.
class FilterSummary extends StatelessWidget {
  final String text;
  final VoidCallback onClear;

  const FilterSummary({super.key, required this.text, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: filterLabelStyle(context),
          ),
        ),
        InkWell(
          onTap: onClear,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppMetrics.minTap,
              minWidth: AppMetrics.minTap,
            ),
            child: Center(
              child: Text(
                'Limpiar',
                style: filterValueStyle(
                  context,
                  active: true,
                ).copyWith(fontSize: AppMetrics.filterLabelSize),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Panel desplegable con todos los filtros de la pantalla.
class FilterPanel extends StatelessWidget {
  final List<FilterField> fields;
  final bool open;

  const FilterPanel({super.key, required this.fields, required this.open});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: open
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final half = (constraints.maxWidth - AppSpacing.s8) / 2;
                  final lone = fields.where((f) => !f.fullWidth).length == 1;
                  return Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s12,
                    children: [
                      for (final f in fields)
                        SizedBox(
                          width: f.fullWidth || lone
                              ? constraints.maxWidth
                              : half,
                          child: f.build(context),
                        ),
                    ],
                  );
                },
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

// Zona de búsqueda y filtros de una lista: el buscador, el botón de filtros
// siempre al extremo derecho, el resumen de lo activo y el panel desplegable.
class FilterArea extends StatefulWidget {
  final Widget? search;
  final List<FilterField> fields;

  const FilterArea({super.key, required this.fields, this.search});

  @override
  State<FilterArea> createState() => _FilterAreaState();
}

class _FilterAreaState extends State<FilterArea> {
  bool _open = false;

  void _clear() {
    for (final f in widget.fields) {
      f.apply(f.defaultValue);
    }
  }

  void _toggle() {
    dismissKeyboard();
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.fields;
    final count = fields.where(_isActive).length;
    final summary = [
      for (final f in fields)
        if (_isActive(f) && f.summary != null) f.summary!,
    ].join(' · ');
    const margin = EdgeInsets.symmetric(horizontal: AppSpacing.s16);
    final button = FilterButton(count: count, open: _open, onTap: _toggle);
    final search = widget.search;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: margin,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (search != null) Expanded(child: search),
                if (search != null) const SizedBox(width: AppSpacing.s8),
                button,
              ],
            ),
          ),
          if (count > 0)
            Padding(
              padding: margin,
              child: FilterSummary(text: summary, onClear: _clear),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              0,
            ),
            child: FilterPanel(fields: fields, open: _open),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
      ),
    );
  }
}
