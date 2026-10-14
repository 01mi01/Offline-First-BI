import 'package:flutter/material.dart';
import '../../models/bi_config.dart';
import '../../theme/app_theme.dart';
import 'app_controls.dart';
import 'app_group.dart';
import 'app_style.dart';
import 'bi_charts.dart';
import 'report_filters_widget.dart';

class BiConfigView extends StatelessWidget {
  final BiConfig config;
  final ValueChanged<BiConfig> onChanged;
  final VoidCallback onConfirm;

  const BiConfigView({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onConfirm,
  });

  void _toggle(BiIndicator indicator, bool selected) {
    final next = {...config.indicators};
    selected ? next.add(indicator) : next.remove(indicator);
    onChanged(config.copyWith(indicators: next));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: AppSpacing.s16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Text(
              'Elige el periodo y los indicadores que quieres ver. '
              'Puedes cambiar esta configuración cuando quieras.',
              style: AppText.rowSubtitle(context),
            ),
          ),
          ReportFiltersWidget(
            filters: config.filters,
            onChanged: (f) => onChanged(config.copyWith(filters: f)),
            activeTab: 0,
            combined: true,
            alwaysOpen: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s8,
              0,
            ),
            child: Row(
              children: [
                const Expanded(child: AppSectionTitle('Indicadores')),
                TextButton(
                  key: const ValueKey('bi-select-all'),
                  onPressed: () => onChanged(
                    config.copyWith(indicators: {...BiIndicator.values}),
                  ),
                  child: const Text('Todos'),
                ),
                TextButton(
                  key: const ValueKey('bi-select-none'),
                  onPressed: () =>
                      onChanged(config.copyWith(indicators: <BiIndicator>{})),
                  child: const Text('Ninguno'),
                ),
              ],
            ),
          ),
          for (final group in BiGroup.values)
            AppSection(
              header: group.label,
              children: [
                for (final indicator in BiIndicator.values.where(
                  (i) => i.group == group,
                ))
                  _IndicatorRow(
                    indicator: indicator,
                    selected: config.indicators.contains(indicator),
                    onChanged: (v) => _toggle(indicator, v),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              0,
            ),
            child: ElevatedButton(
              key: const ValueKey('bi-config-confirm'),
              onPressed: config.indicators.isEmpty ? null : onConfirm,
              child: Text(
                config.indicators.isEmpty
                    ? 'Elige al menos un indicador'
                    : 'Ver indicadores (${config.indicators.length})',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  final BiIndicator indicator;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _IndicatorRow({
    required this.indicator,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppRow(
      key: ValueKey('bi-indicator-${indicator.name}'),
      title: indicator.title,
      subtitle: Text(indicator.description, style: AppText.footnote(context)),
      onTap: () => onChanged(!selected),
      leading: AppRoundCheck(value: selected, onChanged: onChanged),
      trailing: IconButton(
        key: ValueKey('bi-config-info-${indicator.name}'),
        tooltip: 'Información',
        icon: const Icon(
          Icons.info_outline_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        onPressed: () => showBiInfo(context, indicator.title, indicator.info),
      ),
    );
  }
}
