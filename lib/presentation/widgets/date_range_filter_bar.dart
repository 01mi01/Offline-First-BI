import 'package:flutter/material.dart';
import '../../application/date_range_filter.dart';
import '../../config/date_formatters.dart';
import '../../theme/app_theme.dart';
import 'focus_utils.dart';
import '../../config/app_clock.dart';

// Selector de fecha de los filtros y reportes: hoy es la última fecha que se
// puede elegir. No se usa para la fecha de una venta, compra o evento.
Future<DateTime?> pickFilterDate(
  BuildContext context, {
  DateTime? initial,
  DateTime? now,
}) {
  dismissKeyboard();
  final today = dateOnly(now ?? appNow());
  var start = dateOnly(initial ?? today);
  if (start.isAfter(today)) start = today;
  if (start.isBefore(filterFirstDate)) start = filterFirstDate;
  return showDatePicker(
    context: context,
    initialDate: start,
    firstDate: filterFirstDate,
    lastDate: today,
    builder: (ctx, child) => Theme(
      data: Theme.of(
        ctx,
      ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primaryDark)),
      child: child!,
    ),
  );
}

// Muestra el motivo por el que se rechazó un rango de fechas.
void showDateRangeError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

// Chip de una fecha Desde / Hasta, con una X para borrarla.
class DateFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const DateFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryDark.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: active ? AppColors.primaryDark : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: active ? AppColors.primaryDark : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: AppSpacing.s4),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: active ? AppColors.primaryDark : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Filtro por fechas de una lista: atajos (Hoy, Esta semana, Este mes, Este
// año) y un rango a medida Desde/Hasta. Rechaza con un aviso un Hasta anterior
// a Desde o una fecha posterior a hoy.
class DateRangeFilterBar extends StatelessWidget {
  final DateRangeFilter value;
  final ValueChanged<DateRangeFilter> onChanged;

  const DateRangeFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, {required bool isFrom}) async {
    final picked = await pickFilterDate(
      context,
      initial: isFrom ? value.from : value.to,
    );
    if (picked == null || !context.mounted) return;
    final next = isFrom ? value.withFrom(picked) : value.withTo(picked);
    final error = validateDateRange(from: next.from, to: next.to);
    if (error != null) {
      showDateRangeError(context, error);
      return;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DatePresetChips(
            selected: value.preset,
            // Volver a tocar el atajo activo quita el filtro.
            onSelected: (preset) => onChanged(
              preset == null
                  ? const DateRangeFilter()
                  : DateRangeFilter.forPreset(preset),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: DateFilterChip(
                  label: value.from != null
                      ? 'Desde: ${formatDate(value.from!)}'
                      : 'Desde',
                  active: value.from != null,
                  onTap: () => _pick(context, isFrom: true),
                  onClear: value.from != null
                      ? () => onChanged(value.withFrom(null))
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: DateFilterChip(
                  label: value.to != null
                      ? 'Hasta: ${formatDate(value.to!)}'
                      : 'Hasta',
                  active: value.to != null,
                  onTap: () => _pick(context, isFrom: false),
                  onClear: value.to != null
                      ? () => onChanged(value.withTo(null))
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Atajos de fecha (Hoy, Esta semana, Este mes, Este año). Tocar el atajo ya
// seleccionado lo quita: [onSelected] recibe null.
class DatePresetChips extends StatelessWidget {
  final DatePreset? selected;
  final ValueChanged<DatePreset?> onSelected;

  const DatePresetChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        for (final preset in DatePreset.values)
          _PresetChip(
            preset: preset,
            selected: selected == preset,
            onTap: () => onSelected(selected == preset ? null : preset),
          ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final DatePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryDark.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
          ),
        ),
        child: Text(
          preset.label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
