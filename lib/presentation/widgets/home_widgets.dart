import 'package:flutter/material.dart';
import '../../application/home_dashboard.dart';
import '../../config/date_formatters.dart';
import '../../theme/app_theme.dart';
import 'bi_charts.dart' show formatMoney;
import 'home_profit_chart.dart';
import 'screen_header.dart';
import 'app_list_row.dart';

const Duration _entranceDuration = Duration(milliseconds: 300);

const double homeMaxContentWidth = 720;

double homeSidePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final extra = (width - homeMaxContentWidth) / 2;
  return extra > AppSpacing.s16 ? extra : AppSpacing.s16;
}

class HomeEntrance extends StatelessWidget {
  final Widget child;

  const HomeEntrance({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _entranceDuration,
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * AppSpacing.s16),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Encabezado
// ---------------------------------------------------------------------------

class HomeHeader extends StatelessWidget {
  final String userName;
  final HomePeriod period;
  final ValueChanged<HomePeriod> onPeriodChanged;
  final Widget? hero;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.period,
    required this.onPeriodChanged,
    this.hero,
  });

  @override
  Widget build(BuildContext context) {
    final side = homeSidePadding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenTitle('Hola, $userName', horizontal: side),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _PeriodPicker(period: period, onChanged: onPeriodChanged),
          ),
        ),
        if (hero != null)
          Padding(
            padding: EdgeInsets.fromLTRB(side, AppSpacing.s8, side, 0),
            child: hero,
          ),
      ],
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  final HomePeriod period;
  final ValueChanged<HomePeriod> onChanged;

  const _PeriodPicker({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    return PopupMenuButton<HomePeriod>(
      tooltip: 'Cambiar periodo',
      color: AppColors.surface,
      initialValue: period,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final option in HomePeriod.values)
          PopupMenuItem<HomePeriod>(
            key: ValueKey('home-period-${option.name}'),
            value: option,
            child: Text(option.label, style: labelStyle),
          ),
      ],
      child: SizedBox(
        height: AppFlat.minTap,
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: Container(
            key: const ValueKey('home-period-chip'),
            padding: const EdgeInsets.only(
              left: AppSpacing.s12,
              right: AppSpacing.s6,
              top: AppSpacing.s6,
              bottom: AppSpacing.s6,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(period.label, style: labelStyle),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 24,
                  color: AppColors.primaryDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta principal
// ---------------------------------------------------------------------------

class HomeHeroCard extends StatefulWidget {
  final HomePeriod period;
  final String title;
  final String amount;
  final HomeChange change;
  final double sales;
  final double expenses;
  final HomeProfitSeries? series;
  final String emptyMessage;

  const HomeHeroCard({
    super.key,
    required this.period,
    required this.title,
    required this.amount,
    required this.change,
    required this.sales,
    required this.expenses,
    this.series,
    this.emptyMessage = '',
  });

  @override
  State<HomeHeroCard> createState() => _HomeHeroCardState();
}

class _HomeHeroCardState extends State<HomeHeroCard> {
  int? _selected;

  @override
  void didUpdateWidget(HomeHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final series = widget.series;
    final index = _selected;
    final point = series != null && index != null && index < series.points.length
        ? series.points[index]
        : null;

    final label = point == null
        ? widget.title
        : homeBucketLabel(series!.bucket, point.start);
    final amount = point == null
        ? widget.amount
        : formatMoney(point.profit);
    final sales = point?.sales ?? widget.sales;
    final expenses = point?.expenses ?? widget.expenses;

    return Container(
      key: const ValueKey('home-hero'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: AppCards.decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Visibility(
                visible: point == null,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: HomeChangePill(change: widget.change),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              key: const ValueKey('home-hero-amount'),
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 32,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Ventas ${formatMoney(sales)} · Gastos ${formatMoney(expenses)}',
            key: const ValueKey('home-hero-detail'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (series != null && series.points.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            SizedBox(
              height: HomeProfitChart.height + HomeProfitChart.axisHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: HomeProfitChart(
                        key: ValueKey(widget.period),
                        series: series,
                        period: widget.period,
                        selected: _selected,
                        onSelect: (value) {
                          if (value != _selected) {
                            setState(() => _selected = value);
                          }
                        },
                      ),
                    ),
                  ),
                  if (!series.hasMovement)
                    Positioned.fill(
                      bottom: HomeProfitChart.axisHeight,
                      child: IgnorePointer(
                        child: Align(
                          alignment: const Alignment(0, -0.5),
                          child: HomeEmptyMessage(widget.emptyMessage),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeChangePill extends StatelessWidget {
  final HomeChange change;

  const HomeChangePill({super.key, required this.change});

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, Color iconColor, IconData? icon) =
        switch (change.trend) {
          HomeTrend.up => (
            AppColors.successSoft,
            AppColors.successDark,
            AppColors.successDark,
            Icons.arrow_upward_rounded,
          ),
          HomeTrend.down => (
            AppColors.errorSoft,
            AppColors.error,
            AppColors.error,
            Icons.arrow_downward_rounded,
          ),
          HomeTrend.flat => (
            AppColors.border,
            AppColors.textPrimary,
            AppColors.textSecondary,
            Icons.remove_rounded,
          ),
          HomeTrend.none => (
            AppColors.border,
            AppColors.textPrimary,
            AppColors.textSecondary,
            null,
          ),
        };

    return Semantics(
      label: change.trend == HomeTrend.none
          ? 'Sin comparación con el periodo anterior'
          : 'Cambio frente al periodo anterior: ${change.label}',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('home-change-pill'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: AppSpacing.s2),
            ],
            Text(
              change.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Indicadores
// ---------------------------------------------------------------------------

class HomeKpi {
  final String key;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color? background;

  const HomeKpi({
    required this.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.background,
  });
}

class HomeKpiGrid extends StatelessWidget {
  final List<HomeKpi> items;

  const HomeKpiGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final pair = items.skip(i).take(2).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < pair.length; j++) ...[
                if (j > 0) const SizedBox(width: AppSpacing.s12),
                Expanded(child: _KpiCard(kpi: pair[j])),
              ],
            ],
          ),
        ),
      );
      if (i + 2 < items.length) {
        rows.add(const SizedBox(height: AppSpacing.s12));
      }
    }
    return Column(children: rows);
  }
}

class _KpiCard extends StatelessWidget {
  final HomeKpi kpi;

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

// ---------------------------------------------------------------------------
// Accesos rápidos
// ---------------------------------------------------------------------------

class HomeShortcutItem {
  final HomeShortcut shortcut;
  final IconData icon;
  final VoidCallback onTap;

  const HomeShortcutItem({
    required this.shortcut,
    required this.icon,
    required this.onTap,
  });
}

class HomeShortcutRow extends StatelessWidget {
  final List<HomeShortcutItem> items;

  const HomeShortcutRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: homeSidePadding(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items) Expanded(child: _ShortcutButton(item: item)),
        ],
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  final HomeShortcutItem item;

  const _ShortcutButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final label = item.shortcut.label;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('home-shortcut-${item.shortcut.name}'),
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppCards.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.card,
                ),
                child: Icon(item.icon, size: 26, color: AppColors.primaryDark),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Secciones y gráficos
// ---------------------------------------------------------------------------

class HomeSectionTitle extends StatelessWidget {
  final String title;

  const HomeSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class HomeChartCard extends StatelessWidget {
  final String id;
  final String title;
  final String? subtitle;
  final Widget child;

  const HomeChartCard({
    super.key,
    required this.id,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: ValueKey('home-chart-$id'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: AppCards.decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionTitle(title),
          if (subtitle != null)
            Text(
              subtitle!,
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.s12),
          child,
        ],
      ),
    );
  }
}

class HomeEmptyMessage extends StatelessWidget {
  final String message;

  const HomeEmptyMessage(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class HomeLoadingCard extends StatelessWidget {
  const HomeLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('home-loading'),
      height: 140,
      width: double.infinity,
      decoration: AppCards.decoration,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class HomeErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const HomeErrorCard({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('home-error'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: AppCards.decoration,
      child: Column(
        children: [
          const Icon(Icons.error_rounded, color: AppColors.error, size: 28),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'No se pudo cargar la información',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              minimumSize: const Size(48, 48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actividad reciente
// ---------------------------------------------------------------------------

class HomeActivityCard extends StatelessWidget {
  final List<HomeActivity> activities;

  const HomeActivityCard({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      key: const ValueKey('home-activity'),
      children: [
        if (activities.isEmpty)
          const HomeEmptyMessage('Aún no hay movimientos')
        else
          for (final activity in activities) _activityRow(context, activity),
      ],
    );
  }
}

Widget _activityRow(BuildContext context, HomeActivity activity) {
  final textTheme = Theme.of(context).textTheme;
  final isSale = activity.isSale;
  final canceled = activity.isCanceled;
  final id = isSale ? activity.sale!.id : activity.purchase!.id;
  final amountText = '${isSale ? '+' : '-'} ${formatMoney(activity.amount)}';

  return AppListRow(
    key: ValueKey('home-activity-${isSale ? 'sale' : 'purchase'}-$id'),
    icon: isSale ? Icons.point_of_sale_rounded : Icons.shopping_bag_rounded,
    iconColor: isSale ? AppColors.primaryDark : AppColors.chartColor5,
    iconBackground: isSale ? AppColors.primarySoft : AppColors.steelSoft,
    title: isSale ? 'Venta' : 'Compra',
    subtitle: '${activity.title} · ${formatDate(activity.date)}',
    trailing: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          amountText,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: canceled ? AppColors.textMuted : AppColors.textPrimary,
            decoration: canceled ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.textMuted,
          ),
        ),
        if (canceled) ...[
          const SizedBox(height: AppSpacing.s4),
          const _CanceledPill(),
        ],
      ],
    ),
  );
}

class _CanceledPill extends StatelessWidget {
  const _CanceledPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        'Cancelada',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.error,
        ),
      ),
    );
  }
}
