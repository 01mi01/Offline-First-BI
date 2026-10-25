import 'package:flutter/material.dart';
import '../../application/date_range_filter.dart';
import '../../application/status_filter.dart';
import '../../config/date_formatters.dart';
import '../../theme/app_theme.dart';
import 'app_controls.dart';
import 'date_pickers.dart' show pickFilterDate, showDateRangeError;
import 'focus_utils.dart';
import 'searchable_picker.dart';

class FilterOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  const FilterOption(this.value, this.label, {this.icon, this.iconColor});
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

abstract class FilterField {
  Object? get current;
  Object? get defaultValue;
  bool get fullWidth => false;

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
  final String? placeholder;

  FilterDropdown({
    required this.label,
    required this.options,
    required this.current,
    required this.defaultValue,
    required this.onApply,
    this.placeholder,
  });

  String _labelOf(T value) {
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return placeholder ?? options.first.label;
  }

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
            if (options[i].icon != null)
              PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Icon(options[i].icon, size: 22, color: options[i].iconColor),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(child: Text(options[i].label)),
                  ],
                ),
              )
            else
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

class FilterPicker extends FilterField {
  final String label;
  final String searchHint;
  final String allLabel;
  final List<PickerOption<int>> options;
  @override
  final int? current;
  final ValueChanged<int?> onApply;

  FilterPicker({
    required this.label,
    required this.searchHint,
    required this.allLabel,
    required this.options,
    required this.current,
    required this.onApply,
  });

  @override
  Object? get defaultValue => null;

  @override
  bool get fullWidth => true;

  @override
  String? get summary {
    for (final o in options) {
      if (o.value == current) return o.selectedLabel ?? o.label;
    }
    return null;
  }

  @override
  void apply(Object? value) => onApply(value as int?);

  @override
  Widget build(BuildContext context) {
    return _Labeled(
      label: label,
      child: SearchablePickerField<int>(
        key: ValueKey('filter-search-$label'),
        label: label,
        showLabel: false,
        searchStyle: true,
        searchHint: searchHint,
        value: current,
        options: [PickerOption<int>(null, allLabel), ...options],
        onChanged: onApply,
      ),
    );
  }
}

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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                PresetPill(
                  label: preset.label,
                  selected: current.preset == preset,
                  onTap: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onApply(
                      current.preset == preset
                          ? const DateRangeFilter()
                          : DateRangeFilter.forPreset(preset),
                    );
                  },
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
                onClear: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onApply(current.withFrom(null));
                },
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _DateBox(
                label: 'Hasta',
                date: current.to,
                onPicked: (d) => _set(context, to: d),
                onClear: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onApply(current.withTo(null));
                },
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

class PresetPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PresetPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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

class FilterButton extends StatelessWidget {
  final int count;
  final bool open;
  final VoidCallback onTap;
  final bool wide;

  const FilterButton({
    super.key,
    required this.count,
    required this.open,
    required this.onTap,
    this.wide = false,
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
          width: wide ? double.infinity : AppMetrics.controlHeight,
          height: AppMetrics.controlHeight,
          decoration: BoxDecoration(
            color: AppColors.track,
            borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (wide)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 22,
                      color: highlighted
                          ? AppColors.cyanDark
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      'Filtros',
                      style: filterValueStyle(context, active: highlighted),
                    ),
                  ],
                )
              else
                Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: highlighted
                      ? AppColors.cyanDark
                      : AppColors.textSecondary,
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

class FilterPanel extends StatelessWidget {
  final List<FilterField> fields;
  final bool open;

  const FilterPanel({super.key, required this.fields, required this.open});

  List<List<FilterField>> get _rows {
    final rows = <List<FilterField>>[];
    var pending = <FilterField>[];
    void flush() {
      if (pending.isNotEmpty) rows.add(pending);
      pending = <FilterField>[];
    }

    for (final f in fields) {
      if (f.fullWidth) {
        flush();
        rows.add([f]);
      } else {
        pending.add(f);
        if (pending.length == 2) flush();
      }
    }
    flush();
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.s12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var j = 0; j < rows[i].length; j++) ...[
                          if (j > 0) const SizedBox(width: AppSpacing.s8),
                          Expanded(child: rows[i][j].build(context)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class FilterArea extends StatefulWidget {
  final Widget? search;
  final List<FilterField> fields;
  final bool alwaysOpen;
  final VoidCallback? onClear;

  const FilterArea({
    super.key,
    required this.fields,
    this.search,
    this.alwaysOpen = false,
    this.onClear,
  });

  @override
  State<FilterArea> createState() => _FilterAreaState();
}

class _FilterAreaState extends State<FilterArea> {
  late bool _open = widget.alwaysOpen;

  void _clear() {
    if (widget.onClear != null) {
      widget.onClear!();
      return;
    }
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
    final search = widget.search;
    final button = FilterButton(
      count: count,
      open: _open,
      onTap: _toggle,
      wide: search == null,
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.alwaysOpen || search != null)
            Padding(
              padding: margin,
              child: search == null
                  ? button
                  : Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: AppSpacing.s8),
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
