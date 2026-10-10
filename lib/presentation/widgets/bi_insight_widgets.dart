import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';
import '../../models/bi_config.dart';
import '../../models/bi_models.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import 'bi_charts.dart';
import 'bi_interaction.dart';

// Vistas de los indicadores de Business Intelligence que no son un ranking
// simple: resumen, comparaciones, proyección, listas de inventario y radar.
// Todos los colores de gráfico salen de chartColorAt.

TextStyle? _label(BuildContext context, {Color? color, bool bold = false}) =>
    Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color ?? AppColors.textPrimary,
      fontWeight: bold ? FontWeight.w600 : null,
    );

TextStyle? _small(BuildContext context, {Color? color}) => Theme.of(
  context,
).textTheme.labelSmall?.copyWith(color: color ?? AppColors.textSecondary);

String _dateRange(DateTime start, DateTime end) => start == end
    ? formatDate(start)
    : '${formatDate(start)} – ${formatDate(end)}';

// ---------------------------------------------------------------------------
// Resumen
// ---------------------------------------------------------------------------

// Ingresos, gastos y balance del periodo, con el estilo del resumen de
// Reportes.
class BiSummaryCards extends StatelessWidget {
  final BiSummary summary;

  const BiSummaryCards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final balanceColor = summary.balance < 0
        ? AppColors.error
        : AppColors.primaryDark;
    return BiSectionCard(
      title: BiIndicator.summary.title,
      info: BiIndicator.summary.info,
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Ingresos',
              value: formatMoney(summary.ingresos),
              valueColor: AppColors.primaryDark,
            ),
          ),
          Expanded(
            child: _SummaryTile(
              label: 'Gastos',
              value: formatMoney(summary.gastos),
              valueColor: AppColors.error,
            ),
          ),
          Expanded(
            child: _SummaryTile(
              label: 'Balance',
              value: formatMoney(summary.balance),
              valueColor: balanceColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(label, style: _small(context)),
      ],
    );
  }
}

// Barras agrupadas genéricas: [groups] en el eje X y una serie por barra de
// cada grupo (la serie i toma chartColorAt(i)). Admite valores negativos. Las
// barras crecen al aparecer, tocar un grupo muestra el valor de cada serie y la
// leyenda oculta o muestra cada serie (siempre queda una visible).
class BiGroupedBars extends StatefulWidget {
  final List<String> groups;
  final List<String> seriesNames;
  // values[serie][grupo]
  final List<List<double>> values;
  final String Function(double) format;

  const BiGroupedBars({
    required this.groups,
    required this.seriesNames,
    required this.values,
    required this.format,
  });

  @override
  State<BiGroupedBars> createState() => BiGroupedBarsState();
}

class BiGroupedBarsState extends State<BiGroupedBars> {
  Set<int> _hidden = {};
  int? _touchedGroup;
  final _tip = GlobalKey<BiTooltipLayerState>();

  List<int> get _visible => [
    for (var s = 0; s < widget.values.length; s++)
      if (!_hidden.contains(s)) s,
  ];

  void _toggle(int series) {
    _tip.currentState?.hide();
    setState(() {
      _hidden = toggleSeries(_hidden, series, widget.values.length);
      _touchedGroup = null;
    });
  }

  // Quita la marca del grupo tocado (el globo ya no está).
  void _clearMarker() {
    if (_touchedGroup != null) setState(() => _touchedGroup = null);
  }

  void _touch(FlTouchEvent event, int? group) {
    if (event is! FlTapUpEvent &&
        event is! FlLongPressStart &&
        event is! FlLongPressMoveUpdate) {
      return;
    }
    final position = event.localPosition;
    if (group == null || position == null) {
      _tip.currentState?.hide();
      if (_touchedGroup != null) setState(() => _touchedGroup = null);
      return;
    }
    setState(() => _touchedGroup = group);
    _tip.currentState?.showLocal(
      position,
      BiTip(
        title: widget.groups[group],
        lines: [
          for (final s in _visible)
            '${widget.seriesNames[s]}: ${widget.format(widget.values[s][group])}',
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    final values = widget.values;
    final visible = _visible;
    final all = [for (final s in visible) ...values[s]];
    final maxV = all.fold(0.0, math.max);
    final minV = all.fold(0.0, math.min);
    final maxY = maxV <= 0 && minV >= 0 ? 1.0 : math.max(maxV * 1.15, 0.0);
    final minY = minV < 0 ? minV * 1.15 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: BiTooltipLayer(
              key: _tip,
              onHidden: _clearMarker,
              child: BiEntrance(
                builder: (context, t) => BarChart(
                  BarChartData(
                    minY: minY,
                    maxY: maxY == 0 ? 1 : maxY,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          const FlLine(color: AppColors.border, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(sideTitles: moneyAxisTitles()),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= groups.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.s6,
                              ),
                              child: Text(groups[i], style: _small(context)),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      handleBuiltInTouches: false,
                      touchExtraThreshold: const EdgeInsets.fromLTRB(
                        6,
                        14,
                        6,
                        14,
                      ),
                      touchCallback: (event, response) =>
                          _touch(event, response?.spot?.touchedBarGroupIndex),
                    ),
                    barGroups: [
                      for (var g = 0; g < groups.length; g++)
                        BarChartGroupData(
                          x: g,
                          barsSpace: 4,
                          barRods: [
                            for (final s in visible)
                              BarChartRodData(
                                toY: values[s][g] * t,
                                color: _touchedGroup == null || _touchedGroup == g
                                    ? chartColorAt(s)
                                    : chartColorAt(s).withValues(alpha: 0.4),
                                width: 18,
                                borderRadius: BorderRadius.zero,
                              ),
                          ],
                        ),
                    ],
                  ),
                  swapAnimationDuration: t < 1
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        BiToggleLegend(
          keyPrefix: 'bi-legend-grouped',
          hidden: _hidden,
          onToggle: _toggle,
          items: [
            for (var s = 0; s < widget.seriesNames.length; s++)
              BiLegendItem(color: chartColorAt(s), label: widget.seriesNames[s]),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Comparación entre periodos
// ---------------------------------------------------------------------------

class BiPeriodComparisonSection extends StatelessWidget {
  final BiPeriodComparison comparison;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;

  const BiPeriodComparisonSection({
    super.key,
    required this.comparison,
    required this.chartType,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.periodComparison;
    return BiSectionCard(
      title: indicator.title,
      subtitle: comparison.isAvailable
          ? 'Actual: ${_dateRange(comparison.currentStart!, comparison.currentEnd!)}'
                ' · Anterior: ${_dateRange(comparison.previousStart!, comparison.previousEnd!)}'
          : indicator.description,
      info: indicator.info,
      controls: comparison.isAvailable
          ? BiControls.of(
              indicator: indicator,
              chartType: chartType,
              onChartTypeChanged: onChartTypeChanged,
            )
          : null,
      child: !comparison.isAvailable
          ? BiEmptyState(message: comparison.unavailableReason!)
          : chartType == BiChartType.bar
          ? BiGroupedBars(
              groups: const ['Ingresos', 'Gastos', 'Balance'],
              seriesNames: const ['Actual', 'Anterior'],
              values: [
                [
                  comparison.current.ingresos,
                  comparison.current.gastos,
                  comparison.current.balance,
                ],
                [
                  comparison.previous.ingresos,
                  comparison.previous.gastos,
                  comparison.previous.balance,
                ],
              ],
              format: formatMoney,
            )
          : Column(
              children: [
                _ComparisonRow(
                  keyName: 'ingresos',
                  label: 'Ingresos',
                  previous: comparison.previous.ingresos,
                  current: comparison.current.ingresos,
                  higherIsBetter: true,
                ),
                const Divider(height: AppSpacing.s24, color: AppColors.border),
                _ComparisonRow(
                  keyName: 'gastos',
                  label: 'Gastos',
                  previous: comparison.previous.gastos,
                  current: comparison.current.gastos,
                  higherIsBetter: false,
                ),
                const Divider(height: AppSpacing.s24, color: AppColors.border),
                _ComparisonRow(
                  keyName: 'balance',
                  label: 'Balance',
                  previous: comparison.previous.balance,
                  current: comparison.current.balance,
                  higherIsBetter: true,
                ),
              ],
            ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String keyName;
  final String label;
  final double previous;
  final double current;
  final bool higherIsBetter;

  const _ComparisonRow({
    required this.keyName,
    required this.label,
    required this.previous,
    required this.current,
    required this.higherIsBetter,
  });

  @override
  Widget build(BuildContext context) {
    final change = BiPeriodComparison.changePct(current, previous);
    final improved = change == null || change == 0
        ? null
        : (change > 0) == higherIsBetter;
    final color = improved == null
        ? AppColors.textSecondary
        : (improved ? AppColors.primaryDark : AppColors.error);
    final sign = change == null
        ? ''
        : (change > 0 ? '+' : (change < 0 ? '−' : ''));
    final changeText = change == null
        ? 'Sin base'
        : '$sign${formatPercent(change.abs())}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _label(context, bold: true)),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Anterior: ${formatMoney(previous)}',
                style: _small(context),
              ),
              Text(
                'Actual: ${formatMoney(current)}',
                style: _label(context, bold: true),
              ),
            ],
          ),
        ),
        Row(
          key: ValueKey('bi-change-$keyName'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (change != null && change != 0)
              Icon(
                change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: color,
              ),
            const SizedBox(width: AppSpacing.s2),
            Text(
              changeText,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Margen de ganancia por producto
// ---------------------------------------------------------------------------

class BiMarginSection extends StatelessWidget {
  final BiMarginReport report;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;
  // 0 = margen %, 1 = ganancia en monto. La guarda quien usa el widget
  // (BiConfig.metrics) para que sobreviva a que se reconstruya.
  final int metric;
  final ValueChanged<int> onMetricChanged;

  const BiMarginSection({
    super.key,
    required this.report,
    required this.chartType,
    required this.onChartTypeChanged,
    required this.metric,
    required this.onMetricChanged,
  });

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.productMargin;
    final byMargin = metric == 0;

    Widget body;
    if (report.entries.isEmpty) {
      body = BiEmptyState(
        message: report.withoutCost > 0
            ? 'Los productos vendidos no tienen costo de producción '
                  'registrado: agrégalo en Productos para ver su margen.'
            : 'Sin datos para los filtros aplicados',
      );
    } else if (chartType == BiChartType.list) {
      body = _MarginList(entries: _sorted(report.entries, byMargin));
    } else {
      body = BiRankingChart(
        // En barras, "cantidad" es el margen % y "monto" la ganancia.
        entries: [
          for (final e in report.entries)
            BiEntry(label: e.name, amount: e.profit, quantity: e.marginPct),
        ],
        byQuantity: byMargin,
        quantityText: (e) => 'Margen ${formatPercent(e.quantity)}',
      );
    }

    return BiSectionCard(
      title: indicator.title,
      subtitle: indicator.description,
      info: indicator.info,
      controls: BiControls.of(
        indicator: indicator,
        chartType: chartType,
        onChartTypeChanged: onChartTypeChanged,
        metric: report.entries.isEmpty
            ? null
            : BiMetricToggle(
                labels: const ['Margen %', 'Ganancia'],
                selected: metric,
                onChanged: onMetricChanged,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          if (report.withoutCost > 0 && report.entries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              report.withoutCost == 1
                  ? '1 producto vendido no aparece: no tiene costo de '
                        'producción registrado.'
                  : '${report.withoutCost} productos vendidos no aparecen: '
                        'no tienen costo de producción registrado.',
              style: _small(context),
            ),
          ],
        ],
      ),
    );
  }

  List<BiMarginEntry> _sorted(List<BiMarginEntry> entries, bool byMargin) {
    final list = [...entries];
    list.sort(
      (a, b) =>
          byMargin ? b.marginPct.compareTo(a.marginPct) : b.profit.compareTo(a.profit),
    );
    return list;
  }
}

// Lista ordenada con todos los datos del margen de cada producto.
class _MarginList extends StatelessWidget {
  final List<BiMarginEntry> entries;

  const _MarginList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            decoration: BoxDecoration(
              border: i == entries.length - 1
                  ? null
                  : const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text('${i + 1}', style: _small(context)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entries[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _label(context, bold: true),
                      ),
                      Text(
                        'Ingresos ${formatMoney(entries[i].revenue)} · '
                        'Costo ${formatMoney(entries[i].cost)} · '
                        '${entries[i].units} uds.',
                        style: _small(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPercent(entries[i].marginPct),
                      style: _label(
                        context,
                        bold: true,
                        color: entries[i].profit < 0
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(formatMoney(entries[i].profit), style: _small(context)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Proyección de ventas
// ---------------------------------------------------------------------------

class BiProjectionSection extends StatefulWidget {
  final BiProjection projection;
  final BiTimeSeries series;

  const BiProjectionSection({
    super.key,
    required this.projection,
    required this.series,
  });

  // Series de la leyenda (y del gráfico): lo real y la tendencia/proyección.
  static const int realSeries = 0;
  static const int trendSeries = 1;

  @override
  State<BiProjectionSection> createState() => _BiProjectionSectionState();
}

class _BiProjectionSectionState extends State<BiProjectionSection> {
  Set<int> _hidden = {};
  // Punto tocado de cada serie: serie -> índice de su punto.
  Map<int, int> _touched = {};
  final _tip = GlobalKey<BiTooltipLayerState>();

  BiProjection get projection => widget.projection;
  BiTimeSeries get series => widget.series;

  String get _unit => switch (projection.granularity) {
    BiGranularity.day => 'días',
    BiGranularity.week => 'semanas',
    BiGranularity.month => 'meses',
  };

  String get _perUnit => switch (projection.granularity) {
    BiGranularity.day => 'por día',
    BiGranularity.week => 'por semana',
    BiGranularity.month => 'por mes',
  };

  List<int> get _visible => [
    for (var s = 0; s < 2; s++)
      if (!_hidden.contains(s)) s,
  ];

  void _toggle(int s) {
    _tip.currentState?.hide();
    setState(() {
      _hidden = toggleSeries(_hidden, s, 2);
      _touched = {};
    });
  }

  @override
  void didUpdateWidget(BiProjectionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series ||
        oldWidget.projection != widget.projection) {
      _touched = {};
    }
  }

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.salesProjection;
    return BiSectionCard(
      title: indicator.title,
      subtitle: indicator.description,
      info: indicator.info,
      child: !projection.isAvailable
          ? BiEmptyState(message: projection.unavailableReason!)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chart(),
                const SizedBox(height: AppSpacing.s12),
                BiToggleLegend(
                  keyPrefix: 'bi-legend-projection',
                  hidden: _hidden,
                  onToggle: _toggle,
                  items: [
                    BiLegendItem(
                      color: chartColorAt(BiProjectionSection.realSeries),
                      label: 'Ingresos reales',
                    ),
                    BiLegendItem(
                      color: chartColorAt(BiProjectionSection.trendSeries),
                      label: 'Tendencia y proyección (punteada)',
                      dashed: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  key: const ValueKey('bi-projection-summary'),
                  'Próximos ${projection.projected.length} $_unit: '
                  '≈ ${formatMoney(projection.projectedTotal)} en total.',
                  style: _label(context, bold: true),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(_trendText(), style: _small(context)),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Estimación basada en la tendencia reciente; no es una '
                  'garantía.',
                  style: _small(context),
                ),
              ],
            ),
    );
  }

  String _trendText() {
    final mean = projection.fitted.isEmpty
        ? 0.0
        : projection.fitted.fold(0.0, (s, p) => s + p.value) /
              projection.fitted.length;
    final slope = projection.slope;
    if (mean <= 0 || slope.abs() < mean * 0.01) {
      return 'Tendencia estable.';
    }
    return slope > 0
        ? 'Tendencia al alza: +${formatMoney(slope)} $_perUnit.'
        : 'Tendencia a la baja: −${formatMoney(slope.abs())} $_perUnit.';
  }

  Widget _chart() {
    final buckets = series.buckets;
    final n = buckets.length;
    final futureCount = projection.projected.length;
    final total = n + futureCount;
    final visible = _visible;

    int indexOf(DateTime start) => buckets.indexWhere((b) => b.start == start);

    // Línea de tendencia: los intervalos ajustados y, tras el de hoy, los
    // proyectados (índices n, n+1...).
    final trendSpots = <FlSpot>[
      for (final p in projection.fitted)
        if (indexOf(p.start) >= 0) FlSpot(indexOf(p.start).toDouble(), p.value),
      for (var k = 0; k < futureCount; k++)
        FlSpot((n + k).toDouble(), projection.projected[k].value),
    ];

    final maxValue = [
      if (visible.contains(BiProjectionSection.realSeries))
        ...buckets.map((b) => b.ingresos),
      if (visible.contains(BiProjectionSection.trendSeries))
        ...trendSpots.map((s) => s.y),
    ].fold(0.0, math.max);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;

    DateTime startAt(int i) =>
        i < n ? buckets[i].start : projection.projected[i - n].start;

    final fullMax = (total - 1).toDouble();

    return BiZoomableTimeChart(
      maxX: fullMax,
      count: total,
      height: 196,
      tooltipKey: _tip,
      onTooltipHidden: () {
        if (_touched.isNotEmpty) setState(() => _touched = {});
      },
      labelOf: (i) => bucketAxisLabel(startAt(i), projection.granularity),
      chartBuilder: (context, minX, maxX) => LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: 0,
          maxY: maxY,
          clipData: biIsZoomed(minX, maxX, fullMax)
              ? const FlClipData.all()
              : const FlClipData.none(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: const AxisTitles(),
            leftTitles: AxisTitles(sideTitles: moneyAxisTitles()),
          ),
          // Marca dónde termina lo real y empieza la estimación.
          extraLinesData: ExtraLinesData(
            verticalLines: [
              VerticalLine(
                x: (n - 1).toDouble(),
                color: AppColors.textSecondary,
                strokeWidth: 1,
                dashArray: const [4, 4],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topLeft,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  labelResolver: (_) => 'Hoy',
                ),
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: false,
            touchSpotThreshold: 24,
            getTouchedSpotIndicator: biSpotIndicators,
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent &&
                  event is! FlLongPressStart &&
                  event is! FlLongPressMoveUpdate) {
                return;
              }
              final spots = response?.lineBarSpots;
              final position = event.localPosition;
              if (spots == null || spots.isEmpty || position == null) {
                _tip.currentState?.hide();
                if (_touched.isNotEmpty) setState(() => _touched = {});
                return;
              }
              final x = spots.first.x.round();
              setState(() {
                _touched = {
                  for (final spot in spots) visible[spot.barIndex]: spot.spotIndex,
                };
              });
              _tip.currentState?.showLocal(
                position,
                BiTip(
                  title: bucketDetailLabel(startAt(x), projection.granularity),
                  lines: [
                    for (final spot in spots)
                      '${visible[spot.barIndex] == BiProjectionSection.realSeries ? 'Ingresos' : (spot.x.round() >= n ? 'Proyección' : 'Tendencia')}: '
                          '${formatMoney(spot.y)}',
                  ],
                ),
              );
            },
          ),
          lineBarsData: [
            for (final s in visible)
              if (s == BiProjectionSection.realSeries)
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < n; i++)
                      FlSpot(i.toDouble(), buckets[i].ingresos),
                  ],
                  color: chartColorAt(0),
                  barWidth: 2.5,
                  isCurved: false,
                  showingIndicators: [
                    ?_touched[BiProjectionSection.realSeries],
                  ],
                  dotData: FlDotData(
                    show: n <= 31,
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: 3,
                      color: chartColorAt(0),
                      strokeWidth: 1.5,
                      strokeColor: AppColors.surface,
                    ),
                  ),
                )
              else
                LineChartBarData(
                  spots: trendSpots,
                  color: chartColorAt(1),
                  barWidth: 2.5,
                  isCurved: false,
                  dashArray: const [6, 4],
                  showingIndicators: [
                    ?_touched[BiProjectionSection.trendSeries],
                  ],
                  // Solo los puntos estimados llevan marca, huecos, para
                  // distinguirlos de lo real.
                  dotData: FlDotData(
                    checkToShowDot: (spot, barData) => spot.x >= n,
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.surface,
                      strokeWidth: 2,
                      strokeColor: chartColorAt(1),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Evento vs. días regulares
// ---------------------------------------------------------------------------

class BiEventComparisonSection extends StatelessWidget {
  final BiEventComparison comparison;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;

  const BiEventComparisonSection({
    super.key,
    required this.comparison,
    required this.chartType,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.eventComparison;
    final c = comparison;
    final usable = c.eventDays > 0 && c.regularDays > 0;

    Widget body;
    if (c.eventDays == 0) {
      body = const BiEmptyState(
        message: 'No hubo días de evento en el periodo elegido.',
      );
    } else if (c.regularDays == 0) {
      body = const BiEmptyState(
        message:
            'Todo el periodo fue de evento: no hay días regulares con los '
            'que comparar.',
      );
    } else if (chartType == BiChartType.bar) {
      body = BiGroupedBars(
        groups: const ['Por día', 'Por venta'],
        seriesNames: const ['Días de evento', 'Días regulares'],
        values: [
          [c.eventPerDay ?? 0, c.eventPerSale ?? 0],
          [c.regularPerDay ?? 0, c.regularPerSale ?? 0],
        ],
        format: formatMoney,
      );
    } else {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _ComparisonColumn(
              title: 'Días de evento',
              color: chartColorAt(0),
              days: c.eventDays,
              sales: c.eventSales,
              revenue: c.eventRevenue,
              perDay: c.eventPerDay,
              perSale: c.eventPerSale,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: _ComparisonColumn(
              title: 'Días regulares',
              color: chartColorAt(1),
              days: c.regularDays,
              sales: c.regularSales,
              revenue: c.regularRevenue,
              perDay: c.regularPerDay,
              perSale: c.regularPerSale,
            ),
          ),
        ],
      );
    }

    final difference = c.perDayDifferencePct;
    return BiSectionCard(
      title: indicator.title,
      subtitle: indicator.description,
      info: indicator.info,
      controls: usable
          ? BiControls.of(
              indicator: indicator,
              chartType: chartType,
              onChartTypeChanged: onChartTypeChanged,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          if (usable && difference != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              key: const ValueKey('bi-event-verdict'),
              difference >= 0
                  ? 'En días de evento se vende ${formatPercent(difference)} '
                        'más por día que en días regulares.'
                  : 'En días de evento se vende ${formatPercent(difference.abs())} '
                        'menos por día que en días regulares.',
              style: _label(context, bold: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonColumn extends StatelessWidget {
  final String title;
  final Color color;
  final int days;
  final int sales;
  final double revenue;
  final double? perDay;
  final double? perSale;

  const _ComparisonColumn({
    required this.title,
    required this.color,
    required this.days,
    required this.sales,
    required this.revenue,
    required this.perDay,
    required this.perSale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _label(context, bold: true)),
          const SizedBox(height: AppSpacing.s8),
          Text('Por día', style: _small(context)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              perDay == null ? '—' : formatMoney(perDay!),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text('Por venta', style: _small(context)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              perSale == null ? '—' : formatMoney(perSale!),
              style: _label(context, bold: true),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            '$days ${days == 1 ? 'día' : 'días'} · '
            '$sales ${sales == 1 ? 'venta' : 'ventas'}',
            style: _small(context),
          ),
          Text(formatMoney(revenue), style: _small(context)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Costo de materiales vs. ingresos
// ---------------------------------------------------------------------------

class BiMaterialCostSection extends StatelessWidget {
  final BiMaterialCost cost;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;

  const BiMaterialCostSection({
    super.key,
    required this.cost,
    required this.chartType,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.materialCostRatio;
    final ratio = cost.ratioPct;
    final hasData = cost.materialSpend > 0 || cost.revenue > 0;

    Widget body;
    if (!hasData) {
      body = const BiEmptyState();
    } else if (chartType == BiChartType.bar) {
      body = BiRankingChart(
        entries: [
          BiEntry(label: 'Ingresos por ventas', amount: cost.revenue, quantity: 0),
          BiEntry(
            label: 'Compras de materiales',
            amount: cost.materialSpend,
            quantity: 0,
          ),
        ],
        byQuantity: false,
        keepOrder: true,
        quantityText: (_) => '',
      );
    } else {
      body = Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Ingresos',
              value: formatMoney(cost.revenue),
              valueColor: AppColors.primaryDark,
            ),
          ),
          Expanded(
            child: _SummaryTile(
              label: 'Materiales',
              value: formatMoney(cost.materialSpend),
              valueColor: AppColors.error,
            ),
          ),
          Expanded(
            child: _SummaryTile(
              label: '% del ingreso',
              value: ratio == null ? '—' : formatPercent(ratio),
              valueColor: AppColors.textPrimary,
            ),
          ),
        ],
      );
    }

    return BiSectionCard(
      title: indicator.title,
      subtitle: indicator.description,
      info: indicator.info,
      controls: hasData
          ? BiControls.of(
              indicator: indicator,
              chartType: chartType,
              onChartTypeChanged: onChartTypeChanged,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          if (hasData) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              key: const ValueKey('bi-material-ratio'),
              ratio == null
                  ? 'Sin ingresos en el periodo: no se puede calcular la '
                        'proporción.'
                  : 'Por cada Bs. 1 vendido se gastaron '
                        'Bs. ${fixed2(ratio / 100)} en materiales.',
              style: _label(context, bold: true),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Indicador aproximado: no es un costo de ventas exacto.',
              style: _small(context),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inventario: stock bajo y sin movimiento
// ---------------------------------------------------------------------------

// Productos activos con stock bajo: estado actual del inventario, no
// depende de las fechas ni de los filtros.
class BiLowStockSection extends StatelessWidget {
  final List<LowStockEntry> entries;

  const BiLowStockSection({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.lowStock;
    return BiSectionCard(
      title: indicator.title,
      subtitle: 'Stock de $lowStockThreshold o menos · estado actual, sin filtros',
      info: indicator.info,
      child: entries.isEmpty
          ? const BiEmptyState(message: 'Ningún producto con stock bajo')
          : Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  _InventoryRow(
                    title: entries[i].product.name,
                    subtitle: entries[i].categoryName,
                    trailing: entries[i].isOutOfStock
                        ? 'Agotado'
                        : '${entries[i].product.stock} en stock',
                    trailingColor: AppColors.error,
                    isLast: i == entries.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;
  final bool isLast;

  const _InventoryRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: trailingColor),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _label(context, bold: true),
                ),
                Text(subtitle, style: _small(context)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              style: _label(context, bold: true, color: trailingColor),
            ),
          ),
        ],
      ),
    );
  }
}

// Productos activos sin ventas en los últimos N días (N configurable).
class BiNoMovementSection extends StatelessWidget {
  final List<NoMovementEntry> entries;
  final int windowDays;
  final ValueChanged<int> onWindowChanged;
  final int maxItems;

  const BiNoMovementSection({
    super.key,
    required this.entries,
    required this.windowDays,
    required this.onWindowChanged,
    this.maxItems = 15,
  });

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.noMovement;
    final shown = entries.take(maxItems).toList();
    return BiSectionCard(
      title: indicator.title,
      subtitle: 'Sin ventas en los últimos $windowDays días · estado actual, sin filtros',
      info: indicator.info,
      controls: BiMetricToggle(
        labels: [for (final d in noMovementWindowOptions) '$d d'],
        selected: noMovementWindowOptions.indexOf(windowDays),
        onChanged: (i) => onWindowChanged(noMovementWindowOptions[i]),
      ),
      child: entries.isEmpty
          ? BiEmptyState(
              message:
                  'Todos los productos activos se vendieron en los últimos '
                  '$windowDays días.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < shown.length; i++)
                  _InventoryRow(
                    title: shown[i].product.name,
                    subtitle:
                        'Stock: ${shown[i].product.stock} · '
                        '${shown[i].lastSale == null ? 'nunca se vendió' : 'última venta ${formatDate(shown[i].lastSale!)}'}',
                    trailing: shown[i].daysSinceLastSale == null
                        ? 'Sin ventas'
                        : 'Hace ${shown[i].daysSinceLastSale} días',
                    trailingColor: AppColors.textSecondary,
                    isLast: i == shown.length - 1,
                  ),
                if (entries.length > maxItems) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Mostrando los $maxItems primeros de ${entries.length}',
                    style: _small(context),
                  ),
                ],
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Radar de productos
// ---------------------------------------------------------------------------

const List<String> radarAxes = ['Ingresos', 'Margen', 'Unidades', 'Rotación'];

class BiRadarSection extends StatefulWidget {
  final BiRadar radar;
  final List<ProductModel> products;
  final ValueChanged<List<int>> onSelectionChanged;

  const BiRadarSection({
    super.key,
    required this.radar,
    required this.products,
    required this.onSelectionChanged,
  });

  @override
  State<BiRadarSection> createState() => _BiRadarSectionState();
}

class _BiRadarSectionState extends State<BiRadarSection> {
  // Productos ocultos con la leyenda (posiciones en radar.products).
  Set<int> _hidden = {};
  final _tip = GlobalKey<BiTooltipLayerState>();

  BiRadar get radar => widget.radar;

  @override
  void didUpdateWidget(BiRadarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = [for (final p in oldWidget.radar.products) p.id];
    final after = [for (final p in radar.products) p.id];
    if (before.length != after.length ||
        [for (var i = 0; i < before.length; i++) before[i] == after[i]]
            .contains(false)) {
      _hidden = {};
    }
  }

  void _toggle(int product) {
    _tip.currentState?.hide();
    setState(() {
      _hidden = toggleSeries(_hidden, product, radar.products.length);
    });
  }

  // Radio, en dp, alrededor de un vértice dentro del cual un toque lo elige.
  static const double _radarTouchRadius = 24;

  // El vértice de producto más cercano al toque. fl_chart no sirve aquí: el
  // conjunto invisible que fija la escala tiene un vértice en la punta de cada
  // eje y gana cualquier toque cerca de ella, justo donde está el mejor
  // producto de Ingresos y de Unidades. Se calcula con la misma geometría de
  // la librería: centro del área, radio = 80 % de la mitad del lado menor y el
  // eje 0 hacia arriba, en el sentido de las agujas del reloj. Si dos vértices
  // coinciden, gana el que se dibuja encima (el último).
  void _touch(Offset? position, List<int> visible) {
    final box = _tip.currentContext?.findRenderObject();
    if (position == null || box is! RenderBox) {
      _tip.currentState?.hide();
      return;
    }
    final center = box.size.center(Offset.zero);
    final radius = math.min(box.size.width, box.size.height) / 2 * 0.8;
    int? bestProduct;
    var bestAxis = 0;
    var bestDistance = _radarTouchRadius;
    for (final index in visible) {
      final p = radar.products[index];
      final values = [p.revenueNorm, p.marginNorm, p.unitsNorm, p.rotationNorm];
      for (var axis = 0; axis < values.length; axis++) {
        final angle = 2 * math.pi / values.length * axis - math.pi / 2;
        final vertex =
            center +
            Offset(math.cos(angle), math.sin(angle)) * (radius * values[axis]);
        final distance = (vertex - position).distance;
        if (distance <= bestDistance) {
          bestDistance = distance;
          bestProduct = index;
          bestAxis = axis;
        }
      }
    }
    final index = bestProduct;
    if (index == null) {
      _tip.currentState?.hide();
      return;
    }
    final product = radar.products[index];
    _tip.currentState?.showLocal(
      position,
      BiTip(
        title: product.name,
        color: chartColorAt(index),
        lines: ['${radarAxes[bestAxis]}: ${_axisValue(product, bestAxis)}'],
      ),
    );
  }

  String _axisValue(BiRadarProduct p, int axis) => switch (axis) {
    0 => formatMoney(p.revenue),
    1 => p.marginPct == null ? 'sin costo' : formatPercent(p.marginPct!),
    2 => '${p.units} uds.',
    _ => formatPercent(p.rotationNorm * 100),
  };

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.productRadar;
    final visible = [
      for (var i = 0; i < radar.products.length; i++)
        if (!_hidden.contains(i)) i,
    ];
    return BiSectionCard(
      title: indicator.title,
      subtitle: radar.autoSelected
          ? 'Mostrando los productos con más ingresos'
          : indicator.description,
      info: indicator.info,
      controls: OutlinedButton.icon(
        key: const ValueKey('bi-radar-pick'),
        onPressed: () => _pickProducts(context),
        icon: const Icon(Icons.tune_rounded, size: 16),
        label: const Text('Elegir productos'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.primaryDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppIos.groupRadius)),
        ),
      ),
      child: radar.products.length < radarMinProducts
          ? const BiEmptyState(
              message:
                  'Se necesitan al menos 2 productos con ventas en el periodo '
                  'para comparar.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 260,
                  child: BiTooltipLayer(
                    key: _tip,
                    child: BiEntrance(
                      builder: (context, t) => RadarChart(
                        RadarChartData(
                          radarShape: RadarShape.polygon,
                          tickCount: 4,
                          ticksTextStyle: const TextStyle(
                            fontSize: 9,
                            color: Colors.transparent,
                          ),
                          tickBorderData: const BorderSide(
                            color: AppColors.border,
                          ),
                          gridBorderData: const BorderSide(
                            color: AppColors.border,
                          ),
                          radarBorderData: const BorderSide(
                            color: AppColors.border,
                          ),
                          titleTextStyle: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textPrimary),
                          getTitle: (index, angle) =>
                              RadarChartTitle(text: radarAxes[index % 4]),
                          radarTouchData: RadarTouchData(
                            touchSpotThreshold: _radarTouchRadius,
                            touchCallback: (event, response) {
                              if (event is! FlTapUpEvent &&
                                  event is! FlLongPressStart) {
                                return;
                              }
                              _touch(event.localPosition, visible);
                            },
                          ),
                          dataSets: [
                            // Fija la escala del radar de 0 a 100 %: sin esto
                            // la librería escalaría al mayor valor mostrado.
                            RadarDataSet(
                              fillColor: Colors.transparent,
                              borderColor: Colors.transparent,
                              borderWidth: 0,
                              entryRadius: 0,
                              dataEntries: const [
                                RadarEntry(value: 1),
                                RadarEntry(value: 1),
                                RadarEntry(value: 1),
                                RadarEntry(value: 1),
                              ],
                            ),
                            for (final i in visible)
                              RadarDataSet(
                                fillColor: chartColorAt(i).withValues(alpha: 0.2),
                                borderColor: chartColorAt(i),
                                borderWidth: 2,
                                entryRadius: 3,
                                dataEntries: [
                                  RadarEntry(
                                    value: radar.products[i].revenueNorm * t,
                                  ),
                                  RadarEntry(
                                    value: radar.products[i].marginNorm * t,
                                  ),
                                  RadarEntry(
                                    value: radar.products[i].unitsNorm * t,
                                  ),
                                  RadarEntry(
                                    value: radar.products[i].rotationNorm * t,
                                  ),
                                ],
                              ),
                          ],
                        ),
                        swapAnimationDuration: t < 1
                            ? Duration.zero
                            : const Duration(milliseconds: 150),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                for (var i = 0; i < radar.products.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: _RadarLegendRow(
                      index: i,
                      product: radar.products[i],
                      visible: !_hidden.contains(i),
                      onTap: () => _toggle(i),
                    ),
                  ),
                Text(
                  'Todos los ejes de 0 a 100 %. Ingresos y Unidades se miden '
                  'contra el producto que más vendió en el periodo.',
                  style: _small(context),
                ),
              ],
            ),
    );
  }

  Future<void> _pickProducts(BuildContext context) async {
    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RadarPicker(
        products: widget.products,
        initial: [for (final p in radar.products) p.id],
      ),
    );
    if (result != null) widget.onSelectionChanged(result);
  }
}

// Una fila de la leyenda del radar: tocarla oculta o muestra ese producto.
class _RadarLegendRow extends StatelessWidget {
  final int index;
  final BiRadarProduct product;
  final bool visible;
  final VoidCallback onTap;

  const _RadarLegendRow({
    required this.index,
    required this.product,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondary.withValues(alpha: 0.7);
    return Semantics(
      button: true,
      toggled: visible,
      label: product.name,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: ValueKey('bi-radar-legend-$index'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: ValueKey('bi-radar-swatch-$index'),
              margin: const EdgeInsets.only(top: 2),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: visible ? chartColorAt(index) : Colors.transparent,
                border: visible ? null : Border.all(color: muted, width: 2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: _label(context, bold: true, color: visible ? null : muted)
                        ?.copyWith(
                          decoration: visible ? null : TextDecoration.lineThrough,
                        ),
                  ),
                  Text(
                    'Ingresos ${formatMoney(product.revenue)} · '
                    'Margen ${product.marginPct == null ? 'sin costo' : formatPercent(product.marginPct!)} · '
                    '${product.units} uds. · '
                    'Rotación ${formatPercent(product.rotationNorm * 100)}',
                    style: _small(context, color: visible ? null : muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Hoja para elegir de 2 a 4 productos del radar.
class _RadarPicker extends StatefulWidget {
  final List<ProductModel> products;
  final List<int> initial;

  const _RadarPicker({required this.products, required this.initial});

  @override
  State<_RadarPicker> createState() => _RadarPickerState();
}

class _RadarPickerState extends State<_RadarPicker> {
  late final List<int> _selected = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    final active = widget.products.where((p) => p.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final full = _selected.length >= radarMaxProducts;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elige de $radarMinProducts a $radarMaxProducts productos',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in active)
                    CheckboxListTile(
                      key: ValueKey('bi-radar-option-${p.id}'),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primaryDark,
                      title: Text(p.name),
                      value: _selected.contains(p.id),
                      onChanged: !_selected.contains(p.id) && full
                          ? null
                          : (checked) => setState(() {
                              if (checked == true) {
                                _selected.add(p.id);
                              } else {
                                _selected.remove(p.id);
                              }
                            }),
                    ),
                  // Al final del contenido que se desplaza, no fijos.
                  const SizedBox(height: AppSpacing.s12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, <int>[]),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(color: AppColors.primaryDark),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppIos.groupRadius),
                            ),
                          ),
                          // Una sola línea: en pantallas angostas se reduce un poco.
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Los más vendidos', maxLines: 1, softWrap: false),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: ElevatedButton(
                          key: const ValueKey('bi-radar-done'),
                          onPressed: _selected.length >= radarMinProducts
                              ? () => Navigator.pop(context, _selected)
                              : null,
                          child: const Text('Listo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
