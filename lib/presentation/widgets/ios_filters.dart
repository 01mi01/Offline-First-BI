import 'package:flutter/material.dart';
import '../../application/date_range_filter.dart';
import '../../config/date_formatters.dart';
import '../../theme/app_theme.dart';
import 'date_range_filter_bar.dart'
    show pickFilterDate, showDateRangeError;
import 'ios_controls.dart';
import 'ios_style.dart';

// Filtro por fechas de una lista: atajos (Hoy, Esta semana, Este mes, Este
// año) como control segmentado y, debajo, Desde y Hasta en un mismo bloque.
class IosDateRangeFilter extends StatelessWidget {
  final DateRangeFilter value;
  final ValueChanged<DateRangeFilter> onChanged;

  const IosDateRangeFilter({
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
        0,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IosSegmented<DatePreset>(
            segments: [
              for (final preset in DatePreset.values)
                IosSegment(preset, preset.label),
            ],
            selected: value.preset,
            allowDeselect: true,
            onChanged: (preset) => onChanged(
              preset == null
                  ? const DateRangeFilter()
                  : DateRangeFilter.forPreset(preset),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppIos.groupRadius),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _DateCell(
                      label: 'Desde',
                      date: value.from,
                      onTap: () => _pick(context, isFrom: true),
                      onClear: value.from == null
                          ? null
                          : () => onChanged(value.withFrom(null)),
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    indent: AppSpacing.s8,
                    endIndent: AppSpacing.s8,
                    color: AppColors.iosSeparator,
                  ),
                  Expanded(
                    child: _DateCell(
                      label: 'Hasta',
                      date: value.to,
                      onTap: () => _pick(context, isFrom: false),
                      onClear: value.to == null
                          ? null
                          : () => onChanged(value.withTo(null)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateCell({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final active = date != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppIos.minTap),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  active ? '$label: ${formatDate(date!)}' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IosText.rowSubtitle(
                    context,
                    color: active ? AppColors.primaryDark : AppColors.textSecondary,
                  ),
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Quitar $label',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.cancel,
                    size: 18,
                    color: AppColors.iosChevron,
                  ),
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
