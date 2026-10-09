import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/bi_config.dart';
import '../../models/bi_models.dart';
import '../../theme/app_theme.dart';
import 'bi_charts.dart';
import 'bi_interaction.dart';

// Vistas de los indicadores de ventas adicionales de Business Intelligence:
// productos comprados juntos, ventas por día de la semana, ticket promedio,
// rentabilidad por evento, impacto de los descuentos y retorno sobre el costo
// de producción. Todos los colores de gráfico salen de chartColorAt; el rojo
// (AppColors.error) se reserva para las pérdidas.

TextStyle? _label(BuildContext context, {Color? color, bool bold = false}) =>
    Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color ?? AppColors.textPrimary,
      fontWeight: bold ? FontWeight.w600 : null,
    );

TextStyle? _small(BuildContext context, {Color? color}) => Theme.of(
  context,
).textTheme.labelSmall?.copyWith(color: color ?? AppColors.textSecondary);

String _salesText(int n) => n == 1 ? '1 venta' : '$n ventas';

// Cifra grande con su etiqueta debajo (el estilo de las tarjetas de resumen).
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool large;

  const _StatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = large
        ? Theme.of(context).textTheme.headlineLarge
        : Theme.of(context).textTheme.displayMedium;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: base?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontSize: large ? 28 : null,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(label, style: _small(context), textAlign: TextAlign.center),
      ],
    );
  }
}

// Eje izquierdo de conteos: solo números enteros.
SideTitles _countAxisTitles(double maxY) {
  final interval = math.max(1, (maxY / 5).ceil()).toDouble();
  return SideTitles(
    showTitles: true,
    reservedSize: 32,
    interval: interval,
    getTitlesWidget: (value, meta) {
      if (value != value.roundToDouble() || value == meta.max) {
        return const SizedBox.shrink();
      }
      return Text(
        value.round().toString(),
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      );
    },
  );
}

FlGridData _grid() => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) =>
      const FlLine(color: AppColors.border, strokeWidth: 1),
);

// ---------------------------------------------------------------------------
// Productos comprados juntos
// ---------------------------------------------------------------------------

class BiCoPurchaseSection extends StatelessWidget {
  final BiCoPurchaseReport report;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;
  final int maxItems;

  const BiCoPurchaseSection({
    super.key,
    required this.report,
    required this.chartType,
    required this.onChartTypeChanged,
    this.maxItems = 10,
  });

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.coPurchase;
    final pairs = report.pairs;
    final shown = pairs.take(maxItems).toList();

    Widget body;
    if (report.totalSales == 0) {
      body = const BiEmptyState();
    } else if (pairs.isEmpty) {
      body = BiEmptyState(
        message: report.multiProductSales == 0
            ? 'Ninguna venta del periodo incluye 2 o más productos distintos.'
            : 'Ningún par de productos coincide en al menos '
                  '$coPurchaseMinSales ventas del periodo.',
      );
    } else if (chartType == BiChartType.bar) {
      body = BiSignedBars(
        items: [
          for (final p in shown)
            BiBarItem(
              label: p.label,
              value: p.sales.toDouble(),
              valueLabel: _salesText(p.sales),
              details: ['${formatPercent(p.pct)} de las ventas del periodo'],
            ),
        ],
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < shown.length; i++)
            Container(
              key: ValueKey('bi-pair-$i'),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              decoration: BoxDecoration(
                border: i == shown.length - 1
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
                    child: Text(
                      shown[i].label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _label(context, bold: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _salesText(shown[i].sales),
                        style: _label(context, bold: true),
                      ),
                      Text(formatPercent(shown[i].pct), style: _small(context)),
                    ],
                  ),
                ],
              ),
            ),
        ],
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          const SizedBox(height: AppSpacing.s8),
          Text(
            key: const ValueKey('bi-pair-footnote'),
            [
              'Solo pares vistos en al menos $coPurchaseMinSales ventas.',
              '${_salesText(report.totalSales)} en el periodo, '
                  '${report.multiProductSales} con 2 o más productos distintos.',
              if (pairs.length > maxItems)
                'Mostrando los $maxItems primeros de ${pairs.length} pares.',
            ].join(' '),
            style: _small(context),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ventas por día de la semana
// ---------------------------------------------------------------------------

class BiWeekdaySection extends StatefulWidget {
  final List<BiWeekdayEntry> entries;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;
  // 0 = ingresos, 1 = número de ventas. La guarda quien usa el widget
  // (BiConfig.metrics) para que sobreviva a que se reconstruya.
  final int metric;
  final ValueChanged<int> onMetricChanged;

  const BiWeekdaySection({
    super.key,
    required this.entries,
    required this.chartType,
    required this.onChartTypeChanged,
    required this.metric,
    required this.onMetricChanged,
  });

  @override
  State<BiWeekdaySection> createState() => _BiWeekdaySectionState();
}

class _BiWeekdaySectionState extends State<BiWeekdaySection> {
  int? _touched;
  final _tip = GlobalKey<BiTooltipLayerState>();

  bool get _byRevenue => widget.metric == 0;

  @override
  void didUpdateWidget(BiWeekdaySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Otro tipo de gráfico u otra métrica: el punto tocado y su globo ya no
    // corresponden.
    if (oldWidget.chartType != widget.chartType ||
        oldWidget.metric != widget.metric) {
      _touched = null;
      _tip.currentState?.hide(notify: false);
    }
  }

  double _valueOf(BiWeekdayEntry e) =>
      _byRevenue ? e.ingresos : e.ventas.toDouble();

  String _valueText(BiWeekdayEntry e) =>
      _byRevenue ? formatMoney(e.ingresos) : _salesText(e.ventas);

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.weekdaySales;
    final entries = widget.entries;
    final hasData = entries.any((e) => e.ventas > 0);

    BiWeekdayEntry? best;
    if (hasData) {
      best = entries.reduce((a, b) => _valueOf(b) > _valueOf(a) ? b : a);
    }

    return BiSectionCard(
      title: indicator.title,
      subtitle: indicator.description,
      info: indicator.info,
      controls: hasData
          ? BiControls.of(
              indicator: indicator,
              chartType: widget.chartType,
              onChartTypeChanged: widget.onChartTypeChanged,
              metric: BiMetricToggle(
                labels: const ['Ingresos', 'Número de ventas'],
                selected: widget.metric,
                onChanged: widget.onMetricChanged,
              ),
            )
          : null,
      child: !hasData
          ? const BiEmptyState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 200,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: BiTooltipLayer(
                      key: _tip,
                      onHidden: () {
                        if (_touched != null) setState(() => _touched = null);
                      },
                      // Una clave por tipo de gráfico: al cambiarlo la
                      // animación de entrada vuelve a correr.
                      child: BiEntrance(
                        key: ValueKey(widget.chartType),
                        builder: (context, t) => widget.chartType == BiChartType.line
                            ? BiRevealClip(t: t, child: _line(entries))
                            : _bars(entries, t),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    key: ValueKey('bi-weekday-row-$i'),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entries[i].name,
                            style: _label(
                              context,
                              bold: entries[i].weekday == best?.weekday,
                            ),
                          ),
                        ),
                        Text(
                          '${formatMoney(entries[i].ingresos)} · '
                          '${_salesText(entries[i].ventas)}',
                          style: _label(
                            context,
                            bold: entries[i].weekday == best?.weekday,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  key: const ValueKey('bi-weekday-best'),
                  'Día más fuerte: ${best!.name} (${_valueText(best)}).',
                  style: _label(context, bold: true),
                ),
              ],
            ),
    );
  }

  double _maxY(List<BiWeekdayEntry> entries) {
    final maxValue = entries.fold(0.0, (m, e) => math.max(m, _valueOf(e)));
    return maxValue <= 0 ? 1.0 : maxValue * 1.15;
  }

  FlTitlesData _titles(List<BiWeekdayEntry> entries, double maxY) {
    return FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: _byRevenue ? moneyAxisTitles() : _countAxisTitles(maxY),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final i = value.round();
            if (value != i.toDouble() || i < 0 || i >= entries.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s6),
              child: Text(
                entries[i].shortName,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isSelect(FlTouchEvent event) =>
      event is FlTapUpEvent ||
      event is FlLongPressStart ||
      event is FlLongPressMoveUpdate;

  void _touch(FlTouchEvent event, int? index, List<BiWeekdayEntry> entries) {
    final position = event.localPosition;
    if (index == null || position == null) {
      _tip.currentState?.hide();
      if (_touched != null) setState(() => _touched = null);
      return;
    }
    setState(() => _touched = index);
    _tip.currentState?.showLocal(
      position,
      BiTip(
        title: entries[index].name,
        color: chartColorAt(0),
        lines: [_valueText(entries[index])],
      ),
    );
  }

  Widget _bars(List<BiWeekdayEntry> entries, double t) {
    final maxY = _maxY(entries);
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _titles(entries, maxY),
        barTouchData: BarTouchData(
          handleBuiltInTouches: false,
          touchExtraThreshold: const EdgeInsets.fromLTRB(6, 14, 6, 6),
          touchCallback: (event, response) {
            if (!_isSelect(event)) return;
            _touch(event, response?.spot?.touchedBarGroupIndex, entries);
          },
        ),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _valueOf(entries[i]) * t,
                  color: _touched == null || _touched == i
                      ? chartColorAt(0)
                      : chartColorAt(0).withValues(alpha: 0.4),
                  width: 20,
                  borderRadius: BorderRadius.zero,
                ),
              ],
            ),
        ],
      ),
      swapAnimationDuration: t < 1
          ? Duration.zero
          : const Duration(milliseconds: 150),
    );
  }

  Widget _line(List<BiWeekdayEntry> entries) {
    final maxY = _maxY(entries);
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (entries.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _titles(entries, maxY),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchSpotThreshold: 24,
          getTouchedSpotIndicator: biSpotIndicators,
          touchCallback: (event, response) {
            if (!_isSelect(event)) return;
            final spots = response?.lineBarSpots;
            _touch(
              event,
              spots == null || spots.isEmpty ? null : spots.first.spotIndex,
              entries,
            );
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < entries.length; i++)
                FlSpot(i.toDouble(), _valueOf(entries[i])),
            ],
            color: chartColorAt(0),
            barWidth: 2.5,
            isCurved: false,
            showingIndicators: _touched == null ? const [] : [_touched!],
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: chartColorAt(0),
                strokeWidth: 1.5,
                strokeColor: AppColors.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ticket promedio
// ---------------------------------------------------------------------------

class BiTicketSection extends StatelessWidget {
  final BiTicketReport report;
  final BiTimeSeries series;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;

  const BiTicketSection({
    super.key,
    required this.report,
    required this.series,
    required this.chartType,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.averageTicket;
    final average = report.average;

    Widget body;
    if (average == null) {
      body = const BiEmptyState();
    } else if (chartType == BiChartType.line) {
      body = _TrendLine(
        series: series,
        average: average,
        valueOf: (b) => b.ticket,
        valueName: 'Ticket promedio',
        extraTooltip: (b) => _salesText(b.ventas),
      );
    } else {
      body = Column(
        children: [
          _StatTile(
            key: const ValueKey('bi-ticket-average'),
            label: 'Ticket promedio',
            value: formatMoney(average),
            valueColor: AppColors.primaryDark,
            large: true,
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Ventas',
                  value: '${report.salesCount}',
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: 'Ingresos',
                  value: formatMoney(report.total),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return BiSectionCard(
      title: indicator.title,
      subtitle: average != null && chartType == BiChartType.line
          ? 'Por venta · vista ${series.granularity.label.toLowerCase()}'
          : indicator.description,
      info: indicator.info,
      controls: average == null
          ? null
          : BiControls.of(
              indicator: indicator,
              chartType: chartType,
              onChartTypeChanged: onChartTypeChanged,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          if (average != null && chartType == BiChartType.line) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              key: const ValueKey('bi-ticket-summary'),
              'Promedio del periodo: ${formatMoney(average)} '
              '(${_salesText(report.salesCount)}).',
              style: _label(context, bold: true),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'La línea punteada es el promedio del periodo; los intervalos '
              'sin ventas no tienen punto.',
              style: _small(context),
            ),
          ],
        ],
      ),
    );
  }
}

// Línea de un valor por intervalo (los mismos intervalos que Evolución en el
// tiempo). Los intervalos sin valor (null) no llevan punto; una línea punteada
// marca [average] si se indica. Se dibuja sola al aparecer, tocar un punto
// muestra su detalle y admite pellizco para acercar y arrastre para moverse en
// el tiempo.
class _TrendLine extends StatefulWidget {
  final BiTimeSeries series;
  final double? average;
  final double? Function(BiTimeBucket) valueOf;
  final String valueName;
  final String Function(BiTimeBucket) extraTooltip;

  const _TrendLine({
    required this.series,
    required this.valueOf,
    required this.valueName,
    required this.extraTooltip,
    this.average,
  });

  @override
  State<_TrendLine> createState() => _TrendLineState();
}

class _TrendLineState extends State<_TrendLine> {
  // Índice (en la lista de puntos) del punto tocado.
  int? _touched;
  final _tip = GlobalKey<BiTooltipLayerState>();

  @override
  void didUpdateWidget(_TrendLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series) _touched = null;
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final average = widget.average;
    final buckets = series.buckets;
    final n = buckets.length;
    if (n == 0) return const BiEmptyState();

    final spots = <FlSpot>[
      for (var i = 0; i < n; i++)
        if (widget.valueOf(buckets[i]) != null)
          FlSpot(i.toDouble(), widget.valueOf(buckets[i])!),
    ];
    final maxValue = [...spots.map((s) => s.y), ?average].fold(0.0, math.max);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;
    final color = chartColorAt(0);
    final fullMax = n == 1 ? 1.0 : (n - 1).toDouble();

    return BiZoomableTimeChart(
      maxX: fullMax,
      count: n,
      height: 196,
      tooltipKey: _tip,
      onTooltipHidden: () {
        if (_touched != null) setState(() => _touched = null);
      },
      labelOf: (i) => bucketAxisLabel(buckets[i].start, series.granularity),
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
          extraLinesData: average == null
              ? null
              : ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: average,
                      color: chartColorAt(1),
                      strokeWidth: 1.5,
                      dashArray: const [6, 4],
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
              final touched = response?.lineBarSpots;
              final position = event.localPosition;
              if (touched == null || touched.isEmpty || position == null) {
                _tip.currentState?.hide();
                if (_touched != null) setState(() => _touched = null);
                return;
              }
              final spot = touched.first;
              final bucket = buckets[spot.x.round()];
              setState(() => _touched = spot.spotIndex);
              final extra = widget.extraTooltip(bucket);
              _tip.currentState?.showLocal(
                position,
                BiTip(
                  title: bucketDetailLabel(bucket.start, series.granularity),
                  color: color,
                  lines: [
                    '${widget.valueName}: ${formatMoney(spot.y)}',
                    if (extra.isNotEmpty) extra,
                  ],
                ),
              );
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: color,
              barWidth: 2.5,
              isCurved: false,
              showingIndicators: _touched == null ? const [] : [_touched!],
              dotData: FlDotData(
                show: spots.length <= 31,
                getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                  radius: 3,
                  color: color,
                  strokeWidth: 1.5,
                  strokeColor: AppColors.surface,
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
// Impacto de los descuentos
// ---------------------------------------------------------------------------

class BiDiscountSection extends StatelessWidget {
  final BiDiscountReport report;
  final BiTimeSeries series;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;

  const BiDiscountSection({
    super.key,
    required this.report,
    required this.series,
    required this.chartType,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.discountImpact;
    final hasData = report.salesCount > 0;
    final pct = report.pct;

    Widget body;
    if (!hasData) {
      body = const BiEmptyState();
    } else if (chartType == BiChartType.line) {
      body = _TrendLine(
        series: series,
        valueOf: (b) => b.ventas > 0 ? b.descuentos : null,
        valueName: 'Descuentos',
        extraTooltip: (b) => b.descuentoPct == null
            ? ''
            : '${formatPercent(b.descuentoPct!)} de las ventas brutas',
      );
    } else {
      body = Row(
        children: [
          Expanded(
            child: _StatTile(
              key: const ValueKey('bi-discount-total'),
              label: 'Descuentos',
              value: formatMoney(report.totalDiscount),
              valueColor: AppColors.primaryDark,
            ),
          ),
          Expanded(
            child: _StatTile(
              key: const ValueKey('bi-discount-pct'),
              label: '% de ventas brutas',
              value: pct == null ? '—' : formatPercent(pct),
            ),
          ),
          Expanded(
            child: _StatTile(
              key: const ValueKey('bi-discount-gross'),
              label: 'Ventas brutas',
              value: formatMoney(report.grossSales),
            ),
          ),
        ],
      );
    }

    return BiSectionCard(
      title: indicator.title,
      subtitle: hasData && chartType == BiChartType.line
          ? 'Descuentos dados · vista ${series.granularity.label.toLowerCase()}'
          : indicator.description,
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
              key: const ValueKey('bi-discount-summary'),
              report.discountedSales == 0
                  ? 'Ninguna venta del periodo tuvo descuento.'
                  : '${report.discountedSales} de '
                        '${_salesText(report.salesCount)} tuvieron descuento.',
              style: _label(context, bold: true),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Porcentaje sobre las ventas brutas, antes de descontar.',
              style: _small(context),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rentabilidad por evento
// ---------------------------------------------------------------------------

class BiEventProfitSection extends StatelessWidget {
  final List<BiEventProfitEntry> entries;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;

  const BiEventProfitSection({
    super.key,
    required this.entries,
    required this.chartType,
    required this.onChartTypeChanged,
  });

  String _detail(BiEventProfitEntry e) =>
      'Ingresos ${formatMoney(e.income)} (${_salesText(e.salesCount)}) · '
      'Gastos ${formatMoney(e.expenses)}';

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.eventProfit;

    Widget body;
    if (entries.isEmpty) {
      body = const BiEmptyState(
        message:
            'Ningún evento tuvo ventas ni compras vinculadas en el '
            'periodo.',
      );
    } else if (chartType == BiChartType.list) {
      body = Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Container(
              key: ValueKey('bi-event-profit-row-$i'),
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
                        Text(_detail(entries[i]), style: _small(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    formatMoney(entries[i].profit),
                    key: ValueKey('bi-event-profit-value-$i'),
                    style: _label(
                      context,
                      bold: true,
                      color: entries[i].profit < 0
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    } else {
      body = BiSignedBars(
        items: [
          for (final e in entries)
            BiBarItem(
              label: e.name,
              value: e.profit,
              valueLabel: formatMoney(e.profit),
              details: [_detail(e)],
            ),
        ],
      );
    }

    return BiSectionCard(
      title: indicator.title,
      subtitle: indicator.description,
      info: indicator.info,
      controls: entries.isEmpty
          ? null
          : BiControls.of(
              indicator: indicator,
              chartType: chartType,
              onChartTypeChanged: onChartTypeChanged,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Ingresos de las ventas del evento menos todas sus compras '
            '(gastos generales y de materiales). Las pérdidas salen en rojo.',
            style: _small(context),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Retorno sobre el costo de producción
// ---------------------------------------------------------------------------

class BiCostReturnSection extends StatelessWidget {
  final BiReturnReport report;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;

  const BiCostReturnSection({
    super.key,
    required this.report,
    required this.chartType,
    required this.onChartTypeChanged,
  });

  // Non-breaking spaces after "Bs." so a narrow phone never wraps the amount
  // away from its currency ("...fue Bs." / "2.84").
  String _phrase(BiReturnEntry e) =>
      'Por cada Bs.\u00A01 de costo, la ganancia fue '
      '${formatMoney(e.ratio).replaceFirst('Bs. ', 'Bs.\u00A0')}';

  String _detail(BiReturnEntry e) =>
      'Ingresos ${formatMoney(e.revenue)} · Costo ${formatMoney(e.cost)} · '
      '${e.units} uds.';

  @override
  Widget build(BuildContext context) {
    const indicator = BiIndicator.costReturn;
    final entries = report.entries;

    Widget body;
    if (entries.isEmpty) {
      body = BiEmptyState(
        message: report.withoutCost > 0
            ? 'Los productos vendidos no tienen costo de producción '
                  'registrado: agrégalo en Productos para ver su retorno.'
            : 'Sin datos para los filtros aplicados',
      );
    } else if (chartType == BiChartType.list) {
      body = Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Container(
              key: ValueKey('bi-return-row-$i'),
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
                          _phrase(entries[i]),
                          key: ValueKey('bi-return-phrase-$i'),
                          style: _small(
                            context,
                            color: entries[i].profit < 0
                                ? AppColors.error
                                : null,
                          ),
                        ),
                        Text(_detail(entries[i]), style: _small(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    formatMoney(entries[i].ratio),
                    key: ValueKey('bi-return-value-$i'),
                    style: _label(
                      context,
                      bold: true,
                      color: entries[i].profit < 0
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    } else {
      body = BiSignedBars(
        items: [
          for (final e in entries)
            BiBarItem(
              label: e.name,
              value: e.ratio,
              valueLabel: formatMoney(e.ratio),
              details: [_phrase(e), _detail(e)],
            ),
        ],
      );
    }

    return BiSectionCard(
      title: indicator.title,
      subtitle: indicator.description,
      info: indicator.info,
      controls: entries.isEmpty
          ? null
          : BiControls.of(
              indicator: indicator,
              chartType: chartType,
              onChartTypeChanged: onChartTypeChanged,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          if (report.withoutCost > 0 && entries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              key: const ValueKey('bi-return-without-cost'),
              report.withoutCost == 1
                  ? '1 producto vendido no aparece: no tiene costo de '
                        'producción registrado.'
                  : '${report.withoutCost} productos vendidos no aparecen: '
                        'no tienen costo de producción registrado.',
              style: _small(context),
            ),
          ],
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Usa el costo de producción actual de cada producto, que se carga '
            'a mano.',
            style: _small(context),
          ),
        ],
      ),
    );
  }
}
