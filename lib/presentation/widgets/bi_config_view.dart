import 'package:flutter/material.dart';
import '../../models/bi_config.dart';
import '../../theme/app_theme.dart';
import 'bi_charts.dart';
import 'report_filters_widget.dart';

// Paso de configuración de Business Intelligence: periodo y filtros (los
// mismos de Reportes, con sus atajos de fecha) y los indicadores que se
// quieren ver. Solo al confirmar se muestra el panel.
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
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          // Se construye completo (no perezoso): el botón del final siempre
          // existe aunque aún no se haya llegado a él al desplazar.
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    AppSpacing.s16,
                    AppSpacing.s16,
                    AppSpacing.s12,
                  ),
                  child: Text(
                    'Elige el periodo y los indicadores que quieres ver. '
                    'Puedes cambiar esta configuración cuando quieras.',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ReportFiltersWidget(
                  filters: config.filters,
                  onChanged: (f) => onChanged(config.copyWith(filters: f)),
                  activeTab: 0,
                  combined: true,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    AppSpacing.s20,
                    AppSpacing.s16,
                    AppSpacing.s4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Indicadores',
                          style: textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
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
                for (final group in BiGroup.values) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16,
                      AppSpacing.s12,
                      AppSpacing.s16,
                      AppSpacing.s4,
                    ),
                    child: Text(
                      group.label,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final indicator in BiIndicator.values.where(
                    (i) => i.group == group,
                  ))
                    _IndicatorTile(
                      indicator: indicator,
                      selected: config.indicators.contains(indicator),
                      onChanged: (v) => _toggle(indicator, v),
                    ),
                ],
                // Al final del contenido que se desplaza, no fijo en pantalla.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    AppSpacing.s12,
                    AppSpacing.s16,
                    AppSpacing.s12,
                  ),
                  child: SafeArea(
                    top: false,
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  final BiIndicator indicator;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _IndicatorTile({
    required this.indicator,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: ValueKey('bi-indicator-${indicator.name}'),
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              activeColor: AppColors.primary,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    indicator.title,
                    style: textTheme.displaySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    indicator.description,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('bi-config-info-${indicator.name}'),
              tooltip: 'Información',
              icon: const Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.primary,
              ),
              onPressed: () => showBiInfo(context, indicator.title, indicator.info),
            ),
          ],
        ),
      ),
    );
  }
}
