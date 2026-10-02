import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../config/date_formatters.dart';
import '../../models/bi_models.dart';
import '../../theme/app_theme.dart';

// Widgets de los gráficos de Business Intelligence. Todos los colores de las
// series salen de chartColorAt (paleta de 5 colores que se repite a partir de
// la sexta serie): aquí no hay colores sueltos ni paleta por defecto de la
// librería.

String formatMoney(double value) => 'Bs. ${value.toStringAsFixed(2)}';

// Cantidad sin ceros sobrantes (12, 2.5, 0.75).
String formatQuantity(double value) =>
    formatNumber(double.parse(value.toStringAsFixed(2)));

// Monto abreviado para los ejes (1.2k).
String _compactMoney(double value) {
  if (value.abs() >= 1000) {
    final k = value / 1000;
    return '${formatNumber(double.parse(k.toStringAsFixed(1)))}k';
  }
  return formatNumber(double.parse(value.toStringAsFixed(0)));
}

// Tarjeta contenedora de un indicador, con el estilo de las tarjetas de
// Reportes.
class BiSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const BiSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          child,
        ],
      ),
    );
  }
}

class BiEmptyState extends StatelessWidget {
  final String message;

  const BiEmptyState({
    super.key,
    this.message = 'Sin datos para los filtros aplicados',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// Una barra horizontal de un ranking, para el valor que se esté mostrando.
class _RankedBar {
  final String label;
  final String? detail;
  final double value;
  final String valueLabel;

  const _RankedBar({
    required this.label,
    required this.detail,
    required this.value,
    required this.valueLabel,
  });
}

// Ranking con barras horizontales: una fila por elemento, con su nombre, su
// valor y una barra proporcional al mayor. Las barras toman los colores de la
// paleta en orden y los repiten a partir de la sexta. Muestra como máximo
// [maxItems] (los de mayor valor).
class BiRankingChart extends StatelessWidget {
  final List<BiEntry> entries;
  final bool byQuantity;
  final String Function(BiEntry) quantityText;
  final int maxItems;

  const BiRankingChart({
    super.key,
    required this.entries,
    required this.byQuantity,
    required this.quantityText,
    this.maxItems = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const BiEmptyState();

    double valueOf(BiEntry e) => byQuantity ? e.quantity : e.amount;
    final sorted = [...entries]
      ..sort((a, b) {
        final byValue = valueOf(b).compareTo(valueOf(a));
        return byValue != 0 ? byValue : a.label.compareTo(b.label);
      });
    final shown = sorted.take(maxItems).toList();
    final bars = [
      for (final e in shown)
        _RankedBar(
          label: e.label,
          // El otro dato (unidades o dinero) va como detalle bajo el nombre.
          detail: byQuantity ? formatMoney(e.amount) : quantityText(e),
          value: valueOf(e),
          valueLabel: byQuantity ? quantityText(e) : formatMoney(e.amount),
        ),
    ];
    final maxValue = bars.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < bars.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == bars.length - 1 ? 0 : 12),
            child: _RankingRow(
              index: i,
              bar: bars[i],
              fraction: maxValue > 0 ? bars[i].value / maxValue : 0,
            ),
          ),
        if (sorted.length > maxItems) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Mostrando los $maxItems primeros de ${sorted.length}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int index;
  final _RankedBar bar;
  final double fraction;

  const _RankingRow({
    required this.index,
    required this.bar,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: AppColors.textPrimary);
    final detailStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                bar.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              bar.valueLabel,
              style: labelStyle?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (bar.detail != null)
          Text(bar.detail!, style: detailStyle, maxLines: 1),
        const SizedBox(height: AppSpacing.s4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 10,
            color: AppColors.background,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction <= 0 ? 0 : fraction.clamp(0.02, 1.0),
              child: Container(
                key: ValueKey('bi-bar-$index'),
                color: chartColorAt(index),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Interruptor pequeño entre dos métricas de un mismo gráfico (p. ej. ingresos
// o unidades), con el estilo de los chips de Reportes.
class BiMetricToggle extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const BiMetricToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s4),
          GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s10,
                vertical: AppSpacing.s4,
              ),
              decoration: BoxDecoration(
                color: i == selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: i == selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                labels[i],
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: i == selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Indicador con ranking y, si tiene dos métricas, un interruptor para
// alternar entre ellas (por defecto, el dinero).
class BiRankingSection extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<BiEntry> entries;
  // Nombre de la métrica de dinero ("Ingresos", "Gasto") y de la de cantidad
  // ("Unidades"); sin [quantityLabel] no hay interruptor y solo se ve el dinero.
  final String amountLabel;
  final String? quantityLabel;
  final String Function(BiEntry) quantityText;

  const BiRankingSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.amountLabel,
    required this.quantityText,
    this.quantityLabel,
  });

  @override
  State<BiRankingSection> createState() => _BiRankingSectionState();
}

class _BiRankingSectionState extends State<BiRankingSection> {
  int _metric = 0;

  @override
  Widget build(BuildContext context) {
    final hasToggle = widget.quantityLabel != null && widget.entries.isNotEmpty;
    return BiSectionCard(
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: hasToggle
          ? BiMetricToggle(
              labels: [widget.amountLabel, widget.quantityLabel!],
              selected: _metric,
              onChanged: (i) => setState(() => _metric = i),
            )
          : null,
      child: BiRankingChart(
        entries: widget.entries,
        byQuantity: hasToggle && _metric == 1,
        quantityText: widget.quantityText,
      ),
    );
  }
}

// Reparto por tipo de precio: gráfico de pastel con una leyenda de monto,
// unidades y porcentaje de cada tipo.
class BiPriceTypeChart extends StatelessWidget {
  final List<BiEntry> entries;

  const BiPriceTypeChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const BiEmptyState();
    final total = entries.fold(0.0, (sum, e) => sum + e.amount);

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].amount > 0 ? entries[i].amount : 0.0001,
                    color: chartColorAt(i),
                    radius: 50,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == entries.length - 1 ? 0 : AppSpacing.s8,
            ),
            child: Row(
              children: [
                Container(
                  key: ValueKey('bi-price-swatch-$i'),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: chartColorAt(i),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    '${entries[i].label} · ${formatQuantity(entries[i].quantity)} uds.',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${formatMoney(entries[i].amount)}  '
                  '(${total > 0 ? (entries[i].amount / total * 100).toStringAsFixed(1) : '0.0'}%)',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Etiqueta de un intervalo en el eje y en el detalle.
String bucketAxisLabel(DateTime start, BiGranularity granularity) {
  final day = start.day.toString().padLeft(2, '0');
  final month = start.month.toString().padLeft(2, '0');
  return granularity == BiGranularity.month
      ? '$month/${start.year % 100}'
      : '$day/$month';
}

String bucketDetailLabel(DateTime start, BiGranularity granularity) =>
    switch (granularity) {
      BiGranularity.day => formatDate(start),
      BiGranularity.week => 'Semana del ${formatDate(start)}',
      BiGranularity.month =>
        '${start.month.toString().padLeft(2, '0')}/${start.year}',
    };

// Evolución de ingresos (línea continua) y gastos (línea punteada) en el
// tiempo.
class BiTimeSeriesChart extends StatelessWidget {
  final BiTimeSeries series;

  const BiTimeSeriesChart({super.key, required this.series});

  static const int ingresosSeries = 0;
  static const int gastosSeries = 1;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const BiEmptyState();

    final buckets = series.buckets;
    final n = buckets.length;
    final maxValue = buckets.fold<double>(
      0,
      (m, b) => [m, b.ingresos, b.gastos].reduce((a, c) => a > c ? a : c),
    );
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;
    // Unas 5 etiquetas en el eje, sin importar cuántos intervalos haya.
    final labelEvery = (n / 5).ceil().clamp(1, n);
    final showDots = n <= 31;

    LineChartBarData line(
      double Function(BiTimeBucket) valueOf,
      int seriesIndex, {
      List<int>? dash,
    }) {
      final color = chartColorAt(seriesIndex);
      return LineChartBarData(
        spots: [
          for (var i = 0; i < n; i++) FlSpot(i.toDouble(), valueOf(buckets[i])),
        ],
        color: color,
        barWidth: 2.5,
        isCurved: false,
        dashArray: dash,
        dotData: FlDotData(
          show: showDots,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3,
            color: color,
            strokeWidth: 1.5,
            strokeColor: AppColors.surface,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: n == 1 ? 1 : (n - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) {
                          return value == 0
                              ? const Text(
                                  '0',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : const SizedBox.shrink();
                        }
                        return Text(
                          _compactMoney(value),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (value != i.toDouble() ||
                            i < 0 ||
                            i >= n ||
                            i % labelEvery != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s6),
                          child: Text(
                            bucketAxisLabel(
                              buckets[i].start,
                              series.granularity,
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    getTooltipColor: (_) => AppColors.surface,
                    getTooltipItems: (spots) => [
                      for (final spot in spots)
                        LineTooltipItem(
                          // La primera línea del tooltip lleva el intervalo.
                          '${spot.barIndex == ingresosSeries ? '${bucketDetailLabel(buckets[spot.spotIndex].start, series.granularity)}\n' : ''}'
                          '${spot.barIndex == ingresosSeries ? 'Ingresos' : 'Gastos'}: '
                          '${formatMoney(spot.y)}',
                          TextStyle(
                            color: chartColorAt(spot.barIndex),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  line((b) => b.ingresos, ingresosSeries),
                  line((b) => b.gastos, gastosSeries, dash: const [6, 4]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            _LegendDot(color: chartColorAt(ingresosSeries), label: 'Ingresos'),
            const SizedBox(width: AppSpacing.s16),
            _LegendDot(
              color: chartColorAt(gastosSeries),
              label: 'Gastos (punteada)',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.s6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
