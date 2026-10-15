import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppKpi {
  final String key;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color? background;

  const AppKpi({
    required this.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.background,
  });
}

class AppKpiGrid extends StatelessWidget {
  final List<AppKpi> items;
  final double? cardHeight;

  const AppKpiGrid({super.key, required this.items, this.cardHeight});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final pair = items.skip(i).take(2).toList();
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var j = 0; j < pair.length; j++) ...[
            if (j > 0) const SizedBox(width: AppSpacing.s12),
            Expanded(child: _KpiCard(kpi: pair[j])),
          ],
        ],
      );
      rows.add(
        cardHeight == null
            ? IntrinsicHeight(child: row)
            : SizedBox(height: cardHeight, child: row),
      );
      if (i + 2 < items.length) {
        rows.add(const SizedBox(height: AppSpacing.s12));
      }
    }
    return Column(children: rows);
  }
}

class _KpiCard extends StatelessWidget {
  final AppKpi kpi;

  const _KpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: ValueKey('home-kpi-${kpi.key}'),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: AppCards.decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kpi.background ?? kpi.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(kpi.icon, size: 20, color: kpi.color),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            kpi.label,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
