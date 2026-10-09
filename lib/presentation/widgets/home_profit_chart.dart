import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../application/home_dashboard.dart';
import '../../theme/app_theme.dart';

class HomeProfitChart extends StatelessWidget {
  final HomeProfitSeries series;
  final HomePeriod period;
  final int? selected;
  final ValueChanged<int?> onSelect;

  const HomeProfitChart({
    super.key,
    required this.series,
    required this.period,
    required this.selected,
    required this.onSelect,
  });

  static const double height = 180;
  static const double axisHeight = 24;
  static const double sidePadding = AppSpacing.s12;

  @override
  Widget build(BuildContext context) {
    final points = series.points;
    final n = points.length;
    final interactive = series.hasMovement && n > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = math.max(1.0, constraints.maxWidth - 2 * sidePadding);

        void pick(double dx) {
          if (!interactive) return;
          final fraction = ((dx - sidePadding) / plotWidth).clamp(0.0, 1.0);
          onSelect(n == 1 ? 0 : (fraction * (n - 1)).round());
        }

        void release() => onSelect(null);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => pick(d.localPosition.dx),
          onTapUp: (_) => release(),
          onTapCancel: release,
          onHorizontalDragStart: (d) => pick(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
          onHorizontalDragEnd: (_) => release(),
          onHorizontalDragCancel: release,
          child: SizedBox(
            height: height + axisHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: sidePadding),
              child: IgnorePointer(child: _line(context)),
            ),
          ),
        );
      },
    );
  }

  Widget _line(BuildContext context) {
    final points = series.points;
    final n = points.length;
    final values = [for (final p in points) p.profit];
    final low = math.min(0.0, values.fold(0.0, math.min));
    final high = math.max(0.0, values.fold(0.0, math.max));
    final span = high == low ? 2.0 : high - low;
    final pad = span * 0.12;
    final minY = high == low ? -1.0 : low - pad;
    final maxY = high == low ? 1.0 : high + pad;

    final labels = series.axisIndexes.toSet();
    final axisStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);
    final selectedIndex = selected != null && selected! < n ? selected : null;
    const color = AppColors.primaryDark;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: n <= 1 ? 1 : (n - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.none(),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: AppColors.border,
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: axisHeight,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (value != i.toDouble() || i < 0 || i >= n) {
                  return const SizedBox.shrink();
                }
                if (!labels.contains(i)) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s8),
                  child: Text(
                    homeAxisLabel(period, points[i].start),
                    style: axisStyle,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          getTouchLineStart: (_, _) => minY,
          getTouchLineEnd: (_, _) => maxY,
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
                FlDotData(
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 5,
                        color: color,
                        strokeWidth: 2,
                        strokeColor: AppColors.surface,
                      ),
                ),
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < n; i++) FlSpot(i.toDouble(), values[i]),
            ],
            color: color,
            barWidth: 2,
            isCurved: true,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            isStrokeCapRound: true,
            showingIndicators: selectedIndex == null ? const [] : [selectedIndex],
            dotData: FlDotData(show: n == 1),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
