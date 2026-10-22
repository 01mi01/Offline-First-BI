import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/bi_provider.dart';
import '../../config/date_formatters.dart';
import '../../config/quantity_format.dart';
import '../../models/bi_config.dart';
import '../../models/bi_models.dart';
import '../../theme/app_theme.dart';
import 'app_buttons.dart';
import 'app_sheet.dart';
import 'app_style.dart';
import 'bi_charts.dart';
import 'bi_interaction.dart';

enum BiDrillKind { product, category, event, material }

Future<void> showBiDrillDown(
  BuildContext context, {
  required BiDrillKind kind,
  required BiEntry entry,
  required BiQuery query,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => _DrillSheet(kind: kind, entry: entry, query: query),
  );
}

class _DrillSheet extends ConsumerWidget {
  final BiDrillKind kind;
  final BiEntry entry;
  final BiQuery query;

  const _DrillSheet({
    required this.kind,
    required this.entry,
    required this.query,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = entry.refId;
    final List<Widget> body;
    switch (kind) {
      case BiDrillKind.product:
        final detail = ref.watch(
          biProductDetailProvider((query: query, id: id ?? -1)),
        );
        body = _productBody(detail);
      case BiDrillKind.category:
        final detail = ref.watch(
          biCategoryDetailProvider((query: query, name: entry.label)),
        );
        body = _categoryBody(context, detail);
      case BiDrillKind.event:
        final detail = ref.watch(
          biEventDetailProvider((query: query, id: id ?? -1)),
        );
        body = _eventBody(context, detail);
      case BiDrillKind.material:
        final detail = ref.watch(
          biMaterialDetailProvider((query: query, id: id ?? -1)),
        );
        body = _materialBody(detail);
    }

    final subtitle = switch (kind) {
      BiDrillKind.product => 'Detalle del producto',
      BiDrillKind.category =>
        'Productos de la categoría, de más a menos ingresos',
      BiDrillKind.event => 'Ventas y gastos vinculados al evento',
      BiDrillKind.material => 'Compras del material',
    };

    return AppSheetScaffold(
      title: entry.label,
      titleKey: const ValueKey('bi-drill-title'),
      expand: false,
      actions: AppActionButton(
        key: const ValueKey('bi-drill-close'),
        label: 'Cerrar',
        kind: AppButtonKind.neutral,
        onPressed: () => Navigator.pop(context),
      ),
      child: ListView(
        key: const ValueKey('bi-drill-list'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s8,
          AppSpacing.s16,
          AppSpacing.s16,
        ),
        children: [
          Text(subtitle, style: AppText.rowSubtitle(context)),
          const SizedBox(height: AppSpacing.s16),
          ...body,
        ],
      ),
    );
  }

  List<Widget> _productBody(BiProductDetail d) {
    if (d.isEmpty) return const [BiEmptyState()];
    return [
      Row(
        children: [
          Expanded(
            child: _DrillStat(
              statKey: 'revenue',
              label: 'Ingresos',
              value: formatMoney(d.revenue),
              color: AppColors.cyanDark,
            ),
          ),
          Expanded(
            child: _DrillStat(
              statKey: 'units',
              label: 'Unidades',
              value: unitsText(d.units),
            ),
          ),
          Expanded(
            child: _DrillStat(
              statKey: 'count',
              label: 'Ventas',
              value: '${d.salesCount}',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.s16),
      _OverTime(
        key: const ValueKey('bi-drill-over-time'),
        buckets: d.buckets,
        granularity: d.granularity,
        metrics: [
          _Metric('Ingresos', (b) => b.amount, formatMoney),
          _Metric(
            'Unidades',
            (b) => b.quantity,
            unitsText,
          ),
        ],
        rowText: (b) =>
            '${formatMoney(b.amount)} · ${unitsText(b.quantity)}'
            ' · ${b.count == 1 ? '1 venta' : '${b.count} ventas'}',
      ),
    ];
  }

  List<Widget> _categoryBody(BuildContext context, BiCategoryDetail d) {
    if (d.isEmpty) return const [BiEmptyState()];
    final maxAmount = d.products.map((p) => p.amount).fold(0.0, math.max);
    final label = Theme.of(context).textTheme.labelMedium;
    final small = Theme.of(context).textTheme.labelSmall;
    return [
      Row(
        children: [
          Expanded(
            child: _DrillStat(
              statKey: 'revenue',
              label: 'Ingresos',
              value: formatMoney(d.revenue),
              color: AppColors.cyanDark,
            ),
          ),
          Expanded(
            child: _DrillStat(
              statKey: 'units',
              label: 'Unidades',
              value: unitsText(d.units),
            ),
          ),
          Expanded(
            child: _DrillStat(
              statKey: 'count',
              label: 'Productos',
              value: '${d.products.length}',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.s16),
      for (var i = 0; i < d.products.length; i++)
        Padding(
          key: ValueKey('bi-drill-product-$i'),
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: small?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      d.products[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    formatMoney(d.products[i].amount),
                    style: label?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s24),
                child: Text(
                  '${unitsText(d.products[i].quantity)} · '
                  '${d.revenue > 0 ? formatPercent(d.products[i].amount / d.revenue * 100) : '0.0%'} '
                  'de la categoría',
                  style: small?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 8,
                    color: AppColors.background,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: maxAmount > 0
                          ? (d.products[i].amount / maxAmount).clamp(0.02, 1.0)
                          : 0,
                      child: Container(color: chartColorAt(i)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _eventBody(BuildContext context, BiEventDetail d) {
    if (d.isEmpty) return const [BiEmptyState()];
    final label = Theme.of(context).textTheme.labelMedium;
    final small = Theme.of(context).textTheme.labelSmall;
    final profit = d.profit;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s16,
        bottom: AppSpacing.s8,
      ),
      child: Text(
        title,
        style: label?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget line(String key, String text, String detail, String amount) =>
        Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: label?.copyWith(color: AppColors.textPrimary),
                    ),
                    Text(
                      detail,
                      style: small?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                amount,
                style: label?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

    return [
      Row(
        children: [
          Expanded(
            child: _DrillStat(
              statKey: 'income',
              label: d.sales.length == 1
                  ? 'Ingresos (1 venta)'
                  : 'Ingresos (${d.sales.length} ventas)',
              value: formatMoney(d.income),
              color: AppColors.cyanDark,
            ),
          ),
          Expanded(
            child: _DrillStat(
              statKey: 'expenses',
              label: d.expenses.length == 1
                  ? 'Gastos (1 compra)'
                  : 'Gastos (${d.expenses.length} compras)',
              value: formatMoney(d.totalExpenses),
              color: AppColors.error,
            ),
          ),
          Expanded(
            child: _DrillStat(
              statKey: 'profit',
              label: 'Resultado',
              value: formatMoney(profit),
              color: profit < 0 ? AppColors.error : AppColors.cyanDark,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.s12),
      Text(
        key: const ValueKey('bi-drill-expense-split'),
        'Gastos generales ${formatMoney(d.generalExpenses)} · '
        'Compras de materiales ${formatMoney(d.materialExpenses)}',
        style: small?.copyWith(color: AppColors.textSecondary),
      ),
      section('Ventas'),
      if (d.sales.isEmpty)
        Text(
          'Ninguna venta vinculada en el período.',
          style: small?.copyWith(color: AppColors.textSecondary),
        ),
      for (var i = 0; i < d.sales.length; i++)
        line(
          'bi-drill-sale-$i',
          d.sales[i].clientName,
          formatDate(d.sales[i].date),
          formatMoney(d.sales[i].amount),
        ),
      section('Gastos vinculados'),
      if (d.expenses.isEmpty)
        Text(
          'Ninguna compra vinculada en el período.',
          style: small?.copyWith(color: AppColors.textSecondary),
        ),
      for (var i = 0; i < d.expenses.length; i++)
        line(
          'bi-drill-expense-$i',
          d.expenses[i].description,
          '${formatDate(d.expenses[i].date)} · '
              '${d.expenses[i].isMaterial ? 'Materiales' : 'Gasto general'}',
          formatMoney(d.expenses[i].amount),
        ),
    ];
  }

  List<Widget> _materialBody(BiMaterialDetail d) {
    if (d.isEmpty) return const [BiEmptyState()];
    String quantityText(double v) =>
        quantityWithUnit(v, d.unit);
    return [
      Row(
        children: [
          Expanded(
            child: _DrillStat(
              statKey: 'spend',
              label: 'Gasto',
              value: formatMoney(d.spend),
              color: AppColors.cyanDark,
            ),
          ),
          Expanded(
            child: _DrillStat(
              statKey: 'quantity',
              label: 'Cantidad',
              value: quantityText(d.quantity),
            ),
          ),
          Expanded(
            child: _DrillStat(
              statKey: 'count',
              label: 'Compras',
              value: '${d.purchaseCount}',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.s16),
      _OverTime(
        key: const ValueKey('bi-drill-over-time'),
        buckets: d.buckets,
        granularity: d.granularity,
        metrics: [
          _Metric('Gasto', (b) => b.amount, formatMoney),
          _Metric('Cantidad', (b) => b.quantity, quantityText),
        ],
        rowText: (b) =>
            '${formatMoney(b.amount)} · ${quantityText(b.quantity)}'
            ' · ${b.count == 1 ? '1 compra' : '${b.count} compras'}',
      ),
    ];
  }
}

class _DrillStat extends StatelessWidget {
  final String statKey;
  final String label;
  final String value;
  final Color color;

  const _DrillStat({
    required this.statKey,
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) => BiStat(
    label: label,
    value: value,
    valueColor: color,
    valueKey: ValueKey('bi-drill-stat-$statKey'),
  );
}

class _Metric {
  final String name;
  final double Function(BiDrillBucket) valueOf;
  final String Function(double) format;

  const _Metric(this.name, this.valueOf, this.format);
}

class _OverTime extends StatefulWidget {
  final List<BiDrillBucket> buckets;
  final BiGranularity granularity;
  final List<_Metric> metrics;
  final String Function(BiDrillBucket) rowText;

  const _OverTime({
    super.key,
    required this.buckets,
    required this.granularity,
    required this.metrics,
    required this.rowText,
  });

  @override
  State<_OverTime> createState() => _OverTimeState();
}

class _OverTimeState extends State<_OverTime> {
  int _metric = 0;
  int? _touched;
  final _tip = GlobalKey<BiTooltipLayerState>();

  @override
  Widget build(BuildContext context) {
    final metric = widget.metrics[_metric];
    final buckets = widget.buckets;
    final n = buckets.length;
    final maxValue = buckets.map(metric.valueOf).fold(0.0, math.max);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;
    final rodWidth = n <= 8 ? 14.0 : (n <= 20 ? 8.0 : 4.0);
    final active = [
      for (final b in buckets)
        if (b.count > 0) b,
    ];
    final small = Theme.of(context).textTheme.labelSmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Por ${switch (widget.granularity) {
            BiGranularity.day => 'día',
            BiGranularity.week => 'semana',
            BiGranularity.month => 'mes',
          }}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        BiMetricToggle(
          labels: [for (final m in widget.metrics) m.name],
          selected: _metric,
          onChanged: (i) {
            _tip.currentState?.hide();
            setState(() {
              _metric = i;
              _touched = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.s12),
        SizedBox(
          height: 180,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: BiTooltipLayer(
              key: _tip,
              onHidden: () {
                if (_touched != null) setState(() => _touched = null);
              },
              child: BiEntrance(
                builder: (context, t) => BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: maxY,
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
                        sideTitles: bucketAxisTitles(
                          context: context,
                          count: n,
                          labelOf: (i) => bucketAxisLabel(
                            buckets[i].start,
                            widget.granularity,
                          ),
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      handleBuiltInTouches: false,
                      touchExtraThreshold: const EdgeInsets.fromLTRB(
                        6,
                        14,
                        6,
                        6,
                      ),
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent &&
                            event is! FlLongPressStart &&
                            event is! FlLongPressMoveUpdate) {
                          return;
                        }
                        final group = response?.spot?.touchedBarGroupIndex;
                        final position = event.localPosition;
                        if (group == null || position == null) {
                          _tip.currentState?.hide();
                          if (_touched != null) setState(() => _touched = null);
                          return;
                        }
                        setState(() => _touched = group);
                        _tip.currentState?.showLocal(
                          position,
                          BiTip(
                            title: bucketDetailLabel(
                              buckets[group].start,
                              widget.granularity,
                            ),
                            lines: [
                              '${metric.name}: ${metric.format(metric.valueOf(buckets[group]))}',
                            ],
                          ),
                        );
                      },
                    ),
                    barGroups: [
                      for (var i = 0; i < n; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: metric.valueOf(buckets[i]) * t,
                              color: _touched == null || _touched == i
                                  ? chartColorAt(_metric)
                                  : chartColorAt(
                                      _metric,
                                    ).withValues(alpha: 0.4),
                              width: rodWidth,
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
        for (var i = 0; i < active.length; i++)
          Container(
            key: ValueKey('bi-drill-bucket-$i'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            decoration: BoxDecoration(
              border: i == active.length - 1
                  ? null
                  : const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    bucketDetailLabel(active[i].start, widget.granularity),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.rowText(active[i]),
                    textAlign: TextAlign.right,
                    style: small?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
