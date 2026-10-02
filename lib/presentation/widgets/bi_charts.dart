import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../config/date_formatters.dart';
import '../../models/bi_config.dart';
import '../../models/bi_models.dart';
import '../../theme/app_theme.dart';

// Widgets de los gráficos de Business Intelligence. Todos los colores de las
// series salen de chartColorAt (paleta de 5 colores que se repite a partir de
// la sexta serie): aquí no hay colores sueltos ni paleta por defecto de la
// librería.

String formatMoney(double value) => 'Bs. ${value.toStringAsFixed(2)}';

String formatPercent(double value) => '${value.toStringAsFixed(1)}%';

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

const TextStyle _axisStyle = TextStyle(
  fontSize: 10,
  color: AppColors.textSecondary,
);

// Muestra el texto de ayuda de un indicador: qué muestra y para qué sirve.
Future<void> showBiInfo(BuildContext context, String title, String info) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        title,
        style: Theme.of(ctx).textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          info,
          style: Theme.of(
            ctx,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Entendido',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
}

IconData _chartTypeIcon(BiChartType type) => switch (type) {
  BiChartType.bar => Icons.bar_chart,
  BiChartType.pie => Icons.pie_chart_outline,
  BiChartType.line => Icons.show_chart,
  BiChartType.list => Icons.format_list_bulleted,
  BiChartType.cards => Icons.view_agenda_outlined,
  BiChartType.radar => Icons.radar,
};

// Selector del tipo de gráfico de un indicador (solo si ofrece más de uno).
class BiChartTypePicker extends StatelessWidget {
  final List<BiChartType> types;
  final BiChartType selected;
  final ValueChanged<BiChartType> onChanged;

  const BiChartTypePicker({
    super.key,
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final type in types)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s4),
            child: Tooltip(
              message: type.label,
              child: GestureDetector(
                key: ValueKey('bi-chart-type-${type.name}'),
                onTap: () => onChanged(type),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: type == selected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: type == selected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    _chartTypeIcon(type),
                    size: 18,
                    semanticLabel: type.label,
                    color: type == selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Tarjeta contenedora de un indicador, con el estilo de las tarjetas de
// Reportes: título con su icono de información y, debajo, los controles del
// indicador (tipo de gráfico, métrica...).
class BiSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? info;
  final Widget? controls;
  final Widget child;

  const BiSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.info,
    this.controls,
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
            crossAxisAlignment: CrossAxisAlignment.center,
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
              if (info != null)
                InkResponse(
                  key: ValueKey('bi-info-$title'),
                  onTap: () => showBiInfo(context, title, info!),
                  radius: 20,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.s4),
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.primary,
                      semanticLabel: 'Información',
                    ),
                  ),
                ),
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
          if (controls != null) ...[
            const SizedBox(height: AppSpacing.s10),
            controls!,
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
// [maxItems] (los de mayor valor, o los primeros si [keepOrder]).
class BiRankingChart extends StatelessWidget {
  final List<BiEntry> entries;
  final bool byQuantity;
  final String Function(BiEntry) quantityText;
  final int maxItems;

  // Respeta el orden recibido en vez de ordenar por valor (p. ej. Precio A y
  // Precio B, para que cada uno conserve su color).
  final bool keepOrder;

  const BiRankingChart({
    super.key,
    required this.entries,
    required this.byQuantity,
    required this.quantityText,
    this.maxItems = 10,
    this.keepOrder = false,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const BiEmptyState();

    double valueOf(BiEntry e) => byQuantity ? e.quantity : e.amount;
    final sorted = [...entries];
    if (!keepOrder) {
      sorted.sort((a, b) {
        final byValue = valueOf(b).compareTo(valueOf(a));
        return byValue != 0 ? byValue : a.label.compareTo(b.label);
      });
    }
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
    final maxValue = bars.map((b) => b.value).reduce(math.max);

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
    // Con varias opciones o texto grande, pasan a una segunda línea.
    return Wrap(
      spacing: AppSpacing.s4,
      runSpacing: AppSpacing.s4,
      children: [
        for (var i = 0; i < labels.length; i++)
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
                  fontWeight: i == selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Controles de un indicador: selector de tipo de gráfico (si hay más de uno)
// y, a su lado, el interruptor de métrica que se le pase.
class BiControls extends StatelessWidget {
  final BiIndicator indicator;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;
  final Widget? metric;

  const BiControls({
    super.key,
    required this.indicator,
    required this.chartType,
    required this.onChartTypeChanged,
    this.metric,
  });

  // Los controles de un indicador, o null si no tiene ninguno.
  static Widget? of({
    required BiIndicator indicator,
    required BiChartType chartType,
    required ValueChanged<BiChartType> onChartTypeChanged,
    Widget? metric,
  }) {
    if (!indicator.hasChartPicker && metric == null) return null;
    return BiControls(
      indicator: indicator,
      chartType: chartType,
      onChartTypeChanged: onChartTypeChanged,
      metric: metric,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (indicator.hasChartPicker)
          BiChartTypePicker(
            types: indicator.chartTypes,
            selected: chartType,
            onChanged: onChartTypeChanged,
          ),
        ?metric,
      ],
    );
  }
}

// Indicador con ranking (barras o pastel) y, si tiene dos métricas, un
// interruptor para alternar entre ellas (por defecto, el dinero; con
// [quantityFirst], la cantidad).
class BiRankingSection extends StatefulWidget {
  final BiIndicator indicator;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;
  final String? subtitle;
  final List<BiEntry> entries;
  // Nombre de la métrica de dinero ("Ingresos", "Gasto") y de la de cantidad
  // ("Unidades"); sin [quantityLabel] no hay interruptor y solo se ve el dinero.
  final String amountLabel;
  final String? quantityLabel;
  final String Function(BiEntry) quantityText;
  final bool quantityFirst;
  final bool keepOrder;
  final String? footnote;

  const BiRankingSection({
    super.key,
    required this.indicator,
    required this.chartType,
    required this.onChartTypeChanged,
    required this.entries,
    required this.amountLabel,
    required this.quantityText,
    this.quantityLabel,
    this.quantityFirst = false,
    this.keepOrder = false,
    this.subtitle,
    this.footnote,
  });

  @override
  State<BiRankingSection> createState() => _BiRankingSectionState();
}

class _BiRankingSectionState extends State<BiRankingSection> {
  int _metric = 0;

  @override
  Widget build(BuildContext context) {
    final hasToggle = widget.quantityLabel != null && widget.entries.isNotEmpty;
    final labels = widget.quantityFirst
        ? [widget.quantityLabel ?? '', widget.amountLabel]
        : [widget.amountLabel, widget.quantityLabel ?? ''];
    final byQuantity =
        hasToggle && (widget.quantityFirst ? _metric == 0 : _metric == 1);

    final chart = widget.chartType == BiChartType.pie
        ? BiPieChart(
            entries: widget.entries,
            byQuantity: byQuantity,
            quantityText: widget.quantityText,
            keepOrder: widget.keepOrder,
          )
        : BiRankingChart(
            entries: widget.entries,
            byQuantity: byQuantity,
            quantityText: widget.quantityText,
            keepOrder: widget.keepOrder,
          );

    return BiSectionCard(
      title: widget.indicator.title,
      subtitle: widget.subtitle ?? widget.indicator.description,
      info: widget.indicator.info,
      controls: BiControls.of(
        indicator: widget.indicator,
        chartType: widget.chartType,
        onChartTypeChanged: widget.onChartTypeChanged,
        metric: hasToggle
            ? BiMetricToggle(
                labels: labels,
                selected: _metric,
                onChanged: (i) => setState(() => _metric = i),
              )
            : null,
      ),
      child: widget.footnote == null
          ? chart
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chart,
                const SizedBox(height: AppSpacing.s8),
                Text(
                  widget.footnote!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
    );
  }
}

// Reparto en gráfico de pastel con una leyenda de monto (o cantidad) y
// porcentaje de cada elemento. Muestra como máximo [maxItems] (los mayores);
// los porcentajes son sobre los mostrados. Las rebanadas toman los colores de
// la paleta en orden, repitiéndolos a partir de la sexta.
class BiPieChart extends StatelessWidget {
  final List<BiEntry> entries;
  final bool byQuantity;
  final String Function(BiEntry) quantityText;
  final int maxItems;

  // Respeta el orden recibido también al ver cantidades (Precio A / B, para
  // que cada uno conserve su color).
  final bool keepOrder;

  const BiPieChart({
    super.key,
    required this.entries,
    required this.byQuantity,
    required this.quantityText,
    this.maxItems = 10,
    this.keepOrder = false,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const BiEmptyState();
    double valueOf(BiEntry e) => byQuantity ? e.quantity : e.amount;
    // El orden recibido se respeta (los rankings ya vienen ordenados por
    // monto y Precio A / B por tipo); solo se reordena al ver cantidades.
    final sorted = [...entries];
    if (byQuantity && !keepOrder) {
      sorted.sort((a, b) => valueOf(b).compareTo(valueOf(a)));
    }
    final shown = sorted.take(maxItems).toList();
    final total = shown.fold(0.0, (sum, e) => sum + valueOf(e));

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < shown.length; i++)
                  PieChartSectionData(
                    value: valueOf(shown[i]) > 0 ? valueOf(shown[i]) : 0.0001,
                    color: chartColorAt(i),
                    radius: 50,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == shown.length - 1 ? 0 : AppSpacing.s8,
            ),
            child: Row(
              children: [
                Container(
                  key: ValueKey('bi-pie-swatch-$i'),
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
                    byQuantity
                        ? shown[i].label
                        : '${shown[i].label} · ${quantityText(shown[i])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  '${byQuantity ? quantityText(shown[i]) : formatMoney(shown[i].amount)}  '
                  '(${total > 0 ? formatPercent(valueOf(shown[i]) / total * 100) : '0.0%'})',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (sorted.length > maxItems) ...[
          const SizedBox(height: AppSpacing.s12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Mostrando los $maxItems primeros de ${sorted.length}; los '
              'porcentajes son sobre los mostrados',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
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

// Eje izquierdo de montos (con 0 abajo y sin la cifra del tope).
SideTitles moneyAxisTitles() => SideTitles(
  showTitles: true,
  reservedSize: 40,
  getTitlesWidget: (value, meta) {
    if (value == meta.max) return const SizedBox.shrink();
    return Text(_compactMoney(value), style: _axisStyle);
  },
);

// Eje inferior con unas 5 etiquetas de intervalos, sin importar cuántos haya.
SideTitles bucketAxisTitles({
  required int count,
  required String Function(int index) labelOf,
}) {
  final every = (count / 5).ceil().clamp(1, math.max(1, count));
  return SideTitles(
    showTitles: true,
    reservedSize: 24,
    interval: 1,
    getTitlesWidget: (value, meta) {
      final i = value.round();
      if (value != i.toDouble() || i < 0 || i >= count || i % every != 0) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s6),
        child: Text(labelOf(i), style: _axisStyle),
      );
    },
  );
}

class BiLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const BiLegendDot({
    super.key,
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : color,
            border: dashed ? Border.all(color: color, width: 2) : null,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.s6),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// Evolución de ingresos y gastos en el tiempo: líneas (ingresos continua,
// gastos punteada) o barras agrupadas.
class BiTimeSeriesChart extends StatelessWidget {
  final BiTimeSeries series;
  final bool asBars;

  const BiTimeSeriesChart({super.key, required this.series, this.asBars = false});

  static const int ingresosSeries = 0;
  static const int gastosSeries = 1;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const BiEmptyState();

    final buckets = series.buckets;
    final n = buckets.length;
    final maxValue = buckets.fold<double>(
      0,
      (m, b) => math.max(m, math.max(b.ingresos, b.gastos)),
    );
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: asBars ? _bars(buckets, maxY) : _lines(buckets, maxY),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s4,
          children: [
            BiLegendDot(color: chartColorAt(ingresosSeries), label: 'Ingresos'),
            BiLegendDot(
              color: chartColorAt(gastosSeries),
              label: asBars ? 'Gastos' : 'Gastos (punteada)',
              dashed: !asBars,
            ),
          ],
        ),
        if (n == 0) const SizedBox.shrink(),
      ],
    );
  }

  String _tooltipText(int barIndex, int bucketIndex, double value, bool first) {
    final bucket = series.buckets[bucketIndex];
    final header = first
        ? '${bucketDetailLabel(bucket.start, series.granularity)}\n'
        : '';
    return '$header${barIndex == ingresosSeries ? 'Ingresos' : 'Gastos'}: '
        '${formatMoney(value)}';
  }

  Widget _lines(List<BiTimeBucket> buckets, double maxY) {
    final n = buckets.length;
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

    return LineChart(
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
          leftTitles: AxisTitles(sideTitles: moneyAxisTitles()),
          bottomTitles: AxisTitles(
            sideTitles: bucketAxisTitles(
              count: n,
              labelOf: (i) => bucketAxisLabel(buckets[i].start, series.granularity),
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
                  _tooltipText(
                    spot.barIndex,
                    spot.spotIndex,
                    spot.y,
                    spot.barIndex == ingresosSeries,
                  ),
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
    );
  }

  Widget _bars(List<BiTimeBucket> buckets, double maxY) {
    final n = buckets.length;
    // Barras más finas cuantos más intervalos haya.
    final rodWidth = n <= 8 ? 10.0 : (n <= 20 ? 6.0 : 3.0);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
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
          leftTitles: AxisTitles(sideTitles: moneyAxisTitles()),
          bottomTitles: AxisTitles(
            sideTitles: bucketAxisTitles(
              count: n,
              labelOf: (i) => bucketAxisLabel(buckets[i].start, series.granularity),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            getTooltipColor: (_) => AppColors.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  _tooltipText(rodIndex, groupIndex, rod.toY, true),
                  TextStyle(
                    color: chartColorAt(rodIndex),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < n; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 1,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].ingresos,
                  color: chartColorAt(ingresosSeries),
                  width: rodWidth,
                  borderRadius: BorderRadius.zero,
                ),
                BarChartRodData(
                  toY: buckets[i].gastos,
                  color: chartColorAt(gastosSeries),
                  width: rodWidth,
                  borderRadius: BorderRadius.zero,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
