import 'chart_metrics.dart';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';
import '../../models/bi_config.dart';
import '../../models/bi_models.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';
import 'empty_state.dart';
import 'info_hint.dart';
import 'bi_interaction.dart';

String formatMoney(double value) => 'Bs. ${fixed2(value)}';

String formatPercent(double value) => '${fixed2(value)}%';

String _compactMoney(double value) {
  if (value.abs() >= 1000) {
    final k = value / 1000;
    return '${formatNumber(double.parse(k.toStringAsFixed(1)))}k';
  }
  return formatNumber(double.parse(value.toStringAsFixed(0)));
}

Future<void> showBiInfo(BuildContext context, String title, String info) =>
    showInfoDialog(context, title: title, message: info);

IconData _chartTypeIcon(BiChartType type) => switch (type) {
  BiChartType.bar => Icons.bar_chart_rounded,
  BiChartType.pie => Icons.pie_chart_rounded,
  BiChartType.line => Icons.show_chart_rounded,
  BiChartType.list => Icons.format_list_bulleted_rounded,
  BiChartType.cards => Icons.view_agenda_rounded,
  BiChartType.radar => Icons.radar_rounded,
};

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
    return _BiPillTrack(
      children: [
        for (final type in types)
          Tooltip(
            message: type.label,
            child: _BiPill(
              key: ValueKey('bi-chart-type-${type.name}'),
              selected: type == selected,
              onTap: () => onChanged(type),
              child: Icon(
                _chartTypeIcon(type),
                size: AppIconSize.s18,
                semanticLabel: type.label,
                color: type == selected
                    ? AppColors.cyanDark
                    : AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _BiPillTrack extends StatelessWidget {
  final List<Widget> children;

  const _BiPillTrack({required this.children});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s2),
        decoration: BoxDecoration(
          color: AppColors.track,
          borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _BiPill extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _BiPill({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.s32, minWidth: AppExtent.e40),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppMetrics.thumbRadius),
        ),
        child: child,
      ),
    );
  }
}

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
      decoration: AppCards.decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BiSectionHeader(title: title, info: info),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
          if (controls != null) ...[
            const SizedBox(height: AppSpacing.s12),
            controls!,
          ],
          const SizedBox(height: AppSpacing.s12),
          child,
        ],
      ),
    );
  }
}

class BiStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool large;
  final Key? valueKey;

  const BiStat({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    this.large = false,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final base = large ? textTheme.headlineMedium : textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              key: valueKey,
              style: base?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class BiSectionHeader extends StatelessWidget {
  final String title;
  final String? info;

  const BiSectionHeader({super.key, required this.title, this.info});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: AppSectionTitle(title)),
        if (info != null)
          InkResponse(
            key: ValueKey('bi-info-$title'),
            onTap: () => showBiInfo(context, title, info!),
            radius: AppSpacing.s20,
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.s4),
              child: Icon(
                Icons.info_outline_rounded,
                size: AppIconSize.s20,
                color: AppColors.textMuted,
                semanticLabel: 'Información',
              ),
            ),
          ),
      ],
    );
  }
}

class BiEmptyState extends StatelessWidget {
  final String? message;

  const BiEmptyState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) {
      return AppEmptyState.noData(
        what: 'datos',
        period: 'en el período',
        compact: true,
      );
    }
    return AppEmptyState.hint(
      icon: Icons.bar_chart_rounded,
      text: text,
      compact: true,
    );
  }
}

class _RankedBar {
  final BiEntry entry;
  final String label;
  final String? detail;
  final double value;
  final String valueLabel;

  const _RankedBar({
    required this.entry,
    required this.label,
    required this.detail,
    required this.value,
    required this.valueLabel,
  });
}

class BiRankingChart extends StatefulWidget {
  final List<BiEntry> entries;
  final bool byQuantity;
  final String Function(BiEntry) quantityText;
  final int maxItems;

  final bool keepOrder;

  final ValueChanged<BiEntry>? onEntryTap;

  const BiRankingChart({
    super.key,
    required this.entries,
    required this.byQuantity,
    required this.quantityText,
    this.maxItems = 10,
    this.keepOrder = false,
    this.onEntryTap,
  });

  @override
  State<BiRankingChart> createState() => _BiRankingChartState();
}

class _BiRankingChartState extends State<BiRankingChart> {
  final _tip = GlobalKey<BiTooltipLayerState>();

  void _showTip(_RankedBar bar, int index, Offset globalPosition) {
    _tip.currentState?.showGlobal(
      globalPosition,
      BiTip(
        title: bar.label,
        color: chartColorAt(index),
        lines: [bar.valueLabel, if (bar.detail != null) bar.detail!],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    if (entries.isEmpty) return const BiEmptyState();

    double valueOf(BiEntry e) => widget.byQuantity ? e.quantity : e.amount;
    final sorted = [...entries];
    if (!widget.keepOrder) {
      sorted.sort((a, b) {
        final byValue = valueOf(b).compareTo(valueOf(a));
        return byValue != 0 ? byValue : a.label.compareTo(b.label);
      });
    }
    final shown = sorted.take(widget.maxItems).toList();
    final bars = [
      for (final e in shown)
        _RankedBar(
          entry: e,
          label: e.label,
          detail: widget.byQuantity
              ? formatMoney(e.amount)
              : widget.quantityText(e),
          value: valueOf(e),
          valueLabel: widget.byQuantity
              ? widget.quantityText(e)
              : formatMoney(e.amount),
        ),
    ];
    final maxValue = bars.map((b) => b.value).reduce(math.max);
    final onEntryTap = widget.onEntryTap;

    return BiTooltipLayer(
      key: _tip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BiEntrance(
            builder: (context, t) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < bars.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == bars.length - 1 ? 0 : AppSpacing.s12,
                    ),
                    child: _RankingRow(
                      index: i,
                      bar: bars[i],
                      fraction: maxValue > 0 ? bars[i].value / maxValue : 0,
                      growth: t,
                      onTap: onEntryTap == null
                          ? null
                          : () => onEntryTap(bars[i].entry),
                      onShowTip: (position) => _showTip(bars[i], i, position),
                    ),
                  ),
              ],
            ),
          ),
          if (sorted.length > widget.maxItems) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Mostrando los ${widget.maxItems} primeros de ${sorted.length}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int index;
  final _RankedBar bar;
  final double fraction;
  final double growth;
  final VoidCallback? onTap;
  final ValueChanged<Offset> onShowTip;

  const _RankingRow({
    required this.index,
    required this.bar,
    required this.fraction,
    required this.growth,
    required this.onTap,
    required this.onShowTip,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: AppColors.textPrimary);
    final detailStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);

    return GestureDetector(
      key: ValueKey('bi-ranking-row-$index'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onTapUp: onTap == null ? (d) => onShowTip(d.globalPosition) : null,
      onLongPressStart: (d) => onShowTip(d.globalPosition),
      child: Column(
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
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  size: AppIconSize.s18,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          if (bar.detail != null)
            Text(bar.detail!, style: detailStyle, maxLines: 1),
          const SizedBox(height: AppSpacing.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.s4),
            child: Container(
              height: AppSpacing.s10,
              color: AppColors.background,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction <= 0
                    ? 0
                    : (fraction.clamp(0.02, 1.0) * growth).clamp(0.0, 1.0),
                child: Container(
                  key: ValueKey('bi-bar-$index'),
                  color: chartColorAt(index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BiBarItem {
  final String label;
  final List<String> details;
  final double value;
  final String valueLabel;

  const BiBarItem({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.details = const [],
  });
}

class BiSignedBars extends StatefulWidget {
  final List<BiBarItem> items;

  const BiSignedBars({super.key, required this.items});

  @override
  State<BiSignedBars> createState() => _BiSignedBarsState();
}

class _BiSignedBarsState extends State<BiSignedBars> {
  final _tip = GlobalKey<BiTooltipLayerState>();

  void _showTip(BiBarItem item, int index, Offset globalPosition) {
    _tip.currentState?.showGlobal(
      globalPosition,
      BiTip(
        title: item.label,
        color: item.value < 0 ? AppColors.error : chartColorAt(index),
        lines: [item.valueLabel, ...item.details],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const BiEmptyState();
    final maxPositive = items.fold(0.0, (m, i) => math.max(m, i.value));
    final maxNegative = items.fold(0.0, (m, i) => math.max(m, -i.value));
    final span = maxPositive + maxNegative;

    return BiTooltipLayer(
      key: _tip,
      child: BiEntrance(
        builder: (context, t) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == items.length - 1 ? 0 : AppSpacing.s12,
                ),
                child: _SignedBarRow(
                  index: i,
                  item: items[i],
                  maxNegative: maxNegative,
                  span: span,
                  growth: t,
                  onShowTip: (position) => _showTip(items[i], i, position),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignedBarRow extends StatelessWidget {
  final int index;
  final BiBarItem item;
  final double maxNegative;
  final double span;
  final double growth;
  final ValueChanged<Offset> onShowTip;

  const _SignedBarRow({
    required this.index,
    required this.item,
    required this.maxNegative,
    required this.span,
    required this.growth,
    required this.onShowTip,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: AppColors.textPrimary);
    final detailStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);
    final isLoss = item.value < 0;

    return GestureDetector(
      key: ValueKey('bi-signed-row-$index'),
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => onShowTip(d.globalPosition),
      onLongPressStart: (d) => onShowTip(d.globalPosition),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                item.valueLabel,
                key: ValueKey('bi-bar-value-$index'),
                style: labelStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isLoss ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          for (final detail in item.details) Text(detail, style: detailStyle),
          const SizedBox(height: AppSpacing.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.s4),
            child: SizedBox(
              height: AppSpacing.s10,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final scale = span > 0 ? width / span : 0.0;
                  final zeroX = maxNegative * scale;
                  var barWidth = item.value.abs() * scale;
                  if (item.value != 0 && barWidth < AppStroke.thick) barWidth = AppStroke.thick;
                  barWidth *= growth;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Container(color: AppColors.background),
                      ),
                      if (maxNegative > 0)
                        Positioned(
                          left: zeroX,
                          top: 0,
                          bottom: 0,
                          width: AppStroke.hairline,
                          child: Container(color: AppColors.textSecondary),
                        ),
                      if (item.value != 0)
                        Positioned(
                          left: isLoss ? zeroX - barWidth : zeroX,
                          top: 0,
                          bottom: 0,
                          width: barWidth,
                          child: Container(
                            key: ValueKey('bi-bar-$index'),
                            color: isLoss
                                ? AppColors.error
                                : chartColorAt(index),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return _BiPillTrack(
      children: [
        for (var i = 0; i < labels.length; i++)
          _BiPill(
            selected: i == selected,
            onTap: () => onChanged(i),
            child: Text(
              labels[i],
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: i == selected
                    ? AppColors.cyanDark
                    : AppColors.textSecondary,
                fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

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

class BiRankingSection extends StatelessWidget {
  final BiIndicator indicator;
  final BiChartType chartType;
  final ValueChanged<BiChartType> onChartTypeChanged;
  final String? subtitle;
  final List<BiEntry> entries;
  final String amountLabel;
  final String? quantityLabel;
  final String Function(BiEntry) quantityText;
  final bool keepOrder;
  final ValueChanged<BiEntry>? onEntryTap;
  final int metric;
  final ValueChanged<int> onMetricChanged;

  const BiRankingSection({
    super.key,
    required this.indicator,
    required this.chartType,
    required this.onChartTypeChanged,
    required this.entries,
    required this.amountLabel,
    required this.quantityText,
    required this.metric,
    required this.onMetricChanged,
    this.quantityLabel,
    this.keepOrder = false,
    this.subtitle,
    this.onEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasToggle = quantityLabel != null && entries.isNotEmpty;
    final labels = [amountLabel, quantityLabel ?? ''];
    final byQuantity = hasToggle && metric == 1;

    final chart = chartType == BiChartType.pie
        ? BiPieChart(
            entries: entries,
            byQuantity: byQuantity,
            quantityText: quantityText,
            keepOrder: keepOrder,
          )
        : BiRankingChart(
            entries: entries,
            byQuantity: byQuantity,
            quantityText: quantityText,
            keepOrder: keepOrder,
            onEntryTap: onEntryTap,
          );

    return BiSectionCard(
      title: indicator.title,
      subtitle: subtitle ?? indicator.description,
      info: indicator.info,
      controls: BiControls.of(
        indicator: indicator,
        chartType: chartType,
        onChartTypeChanged: onChartTypeChanged,
        metric: hasToggle
            ? BiMetricToggle(
                labels: labels,
                selected: metric,
                onChanged: onMetricChanged,
              )
            : null,
      ),
      child: chart,
    );
  }
}

class BiPieChart extends StatefulWidget {
  final List<BiEntry> entries;
  final bool byQuantity;
  final String Function(BiEntry) quantityText;
  final int maxItems;

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
  State<BiPieChart> createState() => _BiPieChartState();
}

class _BiPieChartState extends State<BiPieChart> {
  final _tip = GlobalKey<BiTooltipLayerState>();
  int? _touched;

  void _hideTip() {
    _tip.currentState?.hide();
    _clearMarker();
  }

  void _clearMarker() {
    if (_touched != null) setState(() => _touched = null);
  }

  @override
  void didUpdateWidget(BiPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.byQuantity != widget.byQuantity ||
        oldWidget.entries != widget.entries) {
      _touched = null;
      _tip.currentState?.hide(notify: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final byQuantity = widget.byQuantity;
    if (entries.isEmpty) return const BiEmptyState();
    double valueOf(BiEntry e) => byQuantity ? e.quantity : e.amount;
    final sorted = [...entries];
    if (byQuantity && !widget.keepOrder) {
      sorted.sort((a, b) => valueOf(b).compareTo(valueOf(a)));
    }
    final shown = sorted.take(widget.maxItems).toList();
    final total = shown.fold(0.0, (sum, e) => sum + valueOf(e));
    final quantityText = widget.quantityText;

    String percentOf(BiEntry e) =>
        total > 0 ? formatPercent(valueOf(e) / total * 100) : '0.00%';
    String valueText(BiEntry e) =>
        byQuantity ? quantityText(e) : formatMoney(e.amount);

    return Column(
      children: [
        BiTooltipLayer(
          key: _tip,
          onHidden: _clearMarker,
          child: SizedBox(
            height: AppExtent.e180,
            child: BiEntrance(
              builder: (context, t) => BiSweepClip(
                t: t,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent &&
                            event is! FlLongPressStart) {
                          return;
                        }
                        final index =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
                        final position = event.localPosition;
                        if (index < 0 ||
                            index >= shown.length ||
                            position == null) {
                          _hideTip();
                          return;
                        }
                        setState(() => _touched = index);
                        _tip.currentState?.showLocal(
                          position,
                          BiTip(
                            title: shown[index].label,
                            color: chartColorAt(index),
                            lines: [
                              valueText(shown[index]),
                              percentOf(shown[index]),
                            ],
                          ),
                        );
                      },
                    ),
                    sections: [
                      for (var i = 0; i < shown.length; i++)
                        PieChartSectionData(
                          value: valueOf(shown[i]) > 0
                              ? valueOf(shown[i])
                              : 0.0001,
                          color: chartColorAt(i),
                          radius: _touched == i ? AppExtent.e56 : AppExtent.e50,
                          showTitle: false,
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
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == shown.length - 1 ? 0 : AppSpacing.s8,
            ),
            child: Row(
              children: [
                Container(
                  key: ValueKey('bi-pie-swatch-$i'),
                  width: AppSpacing.s12,
                  height: AppSpacing.s12,
                  decoration: BoxDecoration(
                    color: chartColorAt(i),
                    borderRadius: BorderRadius.circular(AppSmallRadius.r3),
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
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${valueText(shown[i])}  (${percentOf(shown[i])})',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (sorted.length > widget.maxItems) ...[
          const SizedBox(height: AppSpacing.s12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Mostrando los ${widget.maxItems} primeros de ${sorted.length}; los '
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

SideTitles moneyAxisTitles() => SideTitles(
  showTitles: true,
  reservedSize: kBiMoneyAxisReserved,
  getTitlesWidget: (value, meta) {
    if (value == meta.max) return const SizedBox.shrink();
    if (value == meta.min && value < 0) {
      final offset = value % meta.appliedInterval;
      if (offset > 1e-6 && meta.appliedInterval - offset > 1e-6) {
        return const SizedBox.shrink();
      }
    }
    return Text(_compactMoney(value), style: chartAxisStyle);
  },
);

SideTitles bucketAxisTitles({
  required BuildContext context,
  required int count,
  required String Function(int index) labelOf,
}) {
  final every = (count / 5).ceil().clamp(1, math.max(1, count));
  return SideTitles(
    showTitles: true,
    reservedSize: scaledAxisSize(context, AppSpacing.s24),
    interval: 1,
    getTitlesWidget: (value, meta) {
      final i = value.round();
      if (value != i.toDouble() || i < 0 || i >= count || i % every != 0) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s6),
        child: Text(labelOf(i), style: chartAxisStyle),
      );
    },
  );
}

List<TouchedSpotIndicatorData?> biSpotIndicators(
  LineChartBarData bar,
  List<int> indexes,
) {
  return [
    for (final _ in indexes)
      TouchedSpotIndicatorData(
        const FlLine(color: AppColors.border, strokeWidth: AppStroke.thin),
        FlDotData(
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: AppSmallRadius.r5,
            color: bar.color ?? AppColors.cyanDark,
            strokeWidth: AppStroke.medium,
            strokeColor: AppColors.surface,
          ),
        ),
      ),
  ];
}

bool biIsZoomed(double min, double max, double fullMax) =>
    min > 0.0001 || max < fullMax - 0.0001;

class BiTimeSeriesChart extends StatefulWidget {
  final BiTimeSeries series;
  final bool asBars;
  final bool showExpenses;

  const BiTimeSeriesChart({
    super.key,
    required this.series,
    this.asBars = false,
    this.showExpenses = true,
  });

  static const int ingresosSeries = 0;
  static const int gastosSeries = 1;

  @override
  State<BiTimeSeriesChart> createState() => _BiTimeSeriesChartState();
}

class _BiTimeSeriesChartState extends State<BiTimeSeriesChart> {
  Set<int> _hidden = {};
  int? _touchedIndex;
  final _tip = GlobalKey<BiTooltipLayerState>();

  static const _names = ['Ingresos', 'Gastos'];

  double _valueOf(BiTimeBucket b, int series) =>
      series == BiTimeSeriesChart.ingresosSeries ? b.ingresos : b.gastos;

  int get _seriesCount => widget.showExpenses ? 2 : 1;

  List<int> get _visible => [
    for (var s = 0; s < _seriesCount; s++)
      if (!_hidden.contains(s)) s,
  ];

  void _toggle(int series) {
    _tip.currentState?.hide();
    setState(() {
      _hidden = toggleSeries(_hidden, series, _seriesCount);
      _touchedIndex = null;
    });
  }

  void _clearTouch() {
    _tip.currentState?.hide();
    _clearMarker();
  }

  void _clearMarker() {
    if (_touchedIndex != null) setState(() => _touchedIndex = null);
  }

  BiTip _tipFor(int bucketIndex) {
    final bucket = widget.series.buckets[bucketIndex];
    return BiTip(
      title: bucketDetailLabel(bucket.start, widget.series.granularity),
      lines: [
        for (final s in _visible)
          '${_names[s]}: ${formatMoney(_valueOf(bucket, s))}',
      ],
    );
  }

  void _touch(FlTouchEvent event, int? bucketIndex) {
    final position = event.localPosition;
    if (bucketIndex == null || position == null) {
      _clearTouch();
      return;
    }
    setState(() => _touchedIndex = bucketIndex);
    _tip.currentState?.showLocal(position, _tipFor(bucketIndex));
  }

  bool _isSelect(FlTouchEvent event) =>
      event is FlTapUpEvent ||
      event is FlLongPressStart ||
      event is FlLongPressMoveUpdate;

  @override
  void didUpdateWidget(BiTimeSeriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series) _touchedIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    if (series.isEmpty) return const BiEmptyState();

    final buckets = series.buckets;
    final n = buckets.length;
    final visible = _visible;
    final maxValue = buckets.fold<double>(
      0,
      (m, b) => visible.fold(m, (acc, s) => math.max(acc, _valueOf(b, s))),
    );
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.asBars)
          SizedBox(
            height: AppExtent.e220,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s8),
              child: BiTooltipLayer(
                key: _tip,
                onHidden: _clearMarker,
                child: BiEntrance(
                  key: const ValueKey('bi-entrance-bars'),
                  builder: (context, t) => _bars(buckets, maxY, visible, t),
                ),
              ),
            ),
          )
        else
          BiZoomableTimeChart(
            maxX: n == 1 ? 1 : (n - 1).toDouble(),
            count: n,
            height: AppExtent.e196,
            tooltipKey: _tip,
            onTooltipHidden: _clearMarker,
            labelOf: (i) =>
                bucketAxisLabel(buckets[i].start, series.granularity),
            chartBuilder: (context, min, max) =>
                _lines(buckets, maxY, visible, min, max),
          ),
        const SizedBox(height: AppSpacing.s12),
        BiToggleLegend(
          keyPrefix: 'bi-legend-timeseries',
          hidden: _hidden,
          onToggle: _toggle,
          items: [
            BiLegendItem(
              color: chartColorAt(BiTimeSeriesChart.ingresosSeries),
              label: 'Ingresos',
            ),
            if (widget.showExpenses)
              BiLegendItem(
                color: chartColorAt(BiTimeSeriesChart.gastosSeries),
                label: widget.asBars ? 'Gastos' : 'Gastos (punteada)',
                dashed: !widget.asBars,
              ),
          ],
        ),
      ],
    );
  }

  Widget _lines(
    List<BiTimeBucket> buckets,
    double maxY,
    List<int> visible,
    double minX,
    double maxX,
  ) {
    final n = buckets.length;
    final fullMax = n == 1 ? 1.0 : (n - 1).toDouble();
    final showDots = n <= 31;

    LineChartBarData line(int seriesIndex, {List<int>? dash}) {
      final color = chartColorAt(seriesIndex);
      return LineChartBarData(
        spots: [
          for (var i = 0; i < n; i++)
            FlSpot(i.toDouble(), _valueOf(buckets[i], seriesIndex)),
        ],
        color: color,
        barWidth: 2.5,
        isCurved: false,
        dashArray: dash,
        showingIndicators: _touchedIndex == null ? const [] : [_touchedIndex!],
        dotData: FlDotData(
          show: showDots,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: AppSmallRadius.r3,
            color: color,
            strokeWidth: AppStroke.thin,
            strokeColor: AppColors.surface,
          ),
        ),
      );
    }

    return LineChart(
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
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: AppStroke.hairline),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: const AxisTitles(),
          leftTitles: AxisTitles(sideTitles: moneyAxisTitles()),
        ),
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
            );
          },
        ),
        lineBarsData: [
          for (final s in visible)
            line(
              s,
              dash: s == BiTimeSeriesChart.gastosSeries ? const [6, 4] : null,
            ),
        ],
      ),
    );
  }

  Widget _bars(
    List<BiTimeBucket> buckets,
    double maxY,
    List<int> visible,
    double t,
  ) {
    final n = buckets.length;
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
              const FlLine(color: AppColors.border, strokeWidth: AppStroke.hairline),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(sideTitles: moneyAxisTitles()),
          bottomTitles: AxisTitles(
            sideTitles: bucketAxisTitles(
              context: context,
              count: n,
              labelOf: (i) =>
                  bucketAxisLabel(buckets[i].start, widget.series.granularity),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          handleBuiltInTouches: false,
          touchExtraThreshold: const EdgeInsets.fromLTRB(
            AppSpacing.s6,
            AppSpacing.s14,
            AppSpacing.s6,
            AppSpacing.s6,
          ),
          touchCallback: (event, response) {
            if (!_isSelect(event)) return;
            _touch(event, response?.spot?.touchedBarGroupIndex);
          },
        ),
        barGroups: [
          for (var i = 0; i < n; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 1,
              barRods: [
                for (final s in visible)
                  BarChartRodData(
                    toY: _valueOf(buckets[i], s) * t,
                    color: _touchedIndex == null || _touchedIndex == i
                        ? chartColorAt(s)
                        : chartColorAt(s).withValues(alpha: AppOpacity.a40),
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
    );
  }
}
