import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../application/bi_provider.dart';
import '../../application/client_provider.dart';
import '../../application/date_range_filter.dart';
import '../../application/home_dashboard.dart';
import '../../application/home_period_provider.dart';
import '../../application/module_permission_provider.dart';
import '../../application/purchase_provider.dart';
import '../../application/report_provider.dart';
import '../../application/sale_provider.dart';
import '../../application/supplier_provider.dart';
import '../../config/app_clock.dart';
import '../../models/bi_config.dart';
import '../../models/bi_models.dart';
import '../../models/purchase_model.dart';
import '../../models/report_filters.dart';
import '../../models/sale_model.dart';
import '../../theme/app_theme.dart';
import '../navigation/inventario_tab_page.dart';
import '../navigation/nav_resolver.dart';
import '../navigation/shell_page.dart';
import '../widgets/profile_button.dart';
import '../widgets/screen_header.dart';
import '../widgets/bi_charts.dart';
import '../widgets/bi_drilldown.dart';
import '../widgets/bi_insight_widgets.dart' show BiGroupedBars;
import '../widgets/home_widgets.dart';
import 'business_intelligence_page.dart';
import 'reports_page.dart';
import 'sales_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final readable = ref.watch(readableModulesProvider).valueOrNull ?? [];
    final access = HomeAccess.from(readable);
    final period = ref.watch(homePeriodProvider);

    final saleState = ref.watch(saleProvider);
    final purchaseState = ref.watch(purchaseProvider);
    final loading = saleState.isLoading || purchaseState.isLoading;
    final failed = saleState.error != null || purchaseState.error != null;

    final now = appNow();
    final today = dateOnly(now);
    final filters = ReportFilters(startDate: period.start(today), endDate: today);
    final query = BiQuery(filters: filters);
    final report = access.needsReport && !loading && !failed
        ? ref.watch(biReportProvider(query))
        : null;

    BiSummary summaryOf(ReportFilters f) {
      final reports = ref.watch(reportServiceProvider);
      return ref
          .watch(biServiceProvider)
          .summarize(
            sales: reports.summarizeSaleRows(
              ref.watch(saleReportRowsProvider(f)),
            ),
            purchases: reports.summarizePurchases(
              ref.watch(filteredPurchasesProvider(f)),
            ),
          );
    }

    BiSummary? previous;
    HomeProfitSeries? profitSeries;
    if (report != null && access.profit) {
      final range = period.previous(today);
      previous = summaryOf(
        filters.copyWith(startDate: range.start, endDate: range.end),
      );
      profitSeries = buildProfitSeries(
        period: period,
        sales: [
          for (final r in ref.watch(saleReportRowsProvider(filters)))
            (date: r.sale.date, amount: r.netAmount),
        ],
        expenses: [
          for (final p in ref.watch(filteredPurchasesProvider(filters)))
            (date: p.date, amount: p.totalAmount),
        ],
        now: now,
      );
    }

    void reload() {
      ref.read(saleProvider.notifier).load();
      ref.read(purchaseProvider.notifier).load();
    }

    final side = homeSidePadding(context);
    Widget padded(Widget child, {double bottom = AppSpacing.s16}) => Padding(
      padding: EdgeInsets.fromLTRB(side, 0, side, bottom),
      child: child,
    );

    Widget? hero;
    if (access.profit) {
      if (loading) {
        hero = const HomeLoadingCard();
      } else if (failed) {
        hero = HomeErrorCard(onRetry: reload);
      } else if (report != null && previous != null && profitSeries != null) {
        hero = HomeEntrance(
          child: HomeHeroCard(
            period: period,
            title: 'Ganancia ${period.ofLabel}',
            amount: formatMoney(report.summary.balance),
            change: HomeChange.of(report.summary.balance, previous.balance),
            sales: report.summary.ingresos,
            expenses: report.summary.gastos,
            series: profitSeries,
            emptyMessage: 'Aún no hay movimientos ${period.duringLabel}',
          ),
        );
      }
    }

    final sections = <Widget Function(BuildContext)>[];

    if ((loading || failed) && !access.profit && access.needsReport) {
      sections.add(
        (_) => padded(
          loading
              ? const HomeLoadingCard()
              : HomeErrorCard(onRetry: reload),
        ),
      );
    }

    final shortcutItems = [
      for (final shortcut in access.shortcuts)
        HomeShortcutItem(
          shortcut: shortcut,
          icon: _iconFor(shortcut),
          onTap: () => _open(context, shortcut),
        ),
    ];
    if (shortcutItems.isNotEmpty) {
      sections.add(
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s16),
          child: HomeEntrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(side, 0, side, AppSpacing.s8),
                  child: const HomeSectionTitle('Accesos rápidos'),
                ),
                HomeShortcutRow(items: shortcutItems),
              ],
            ),
          ),
        ),
      );
    }

    if (report != null) {
      final kpis = <HomeKpi>[
        if (access.sales)
          HomeKpi(
            key: 'ventas',
            label: 'Ventas ${period.ofLabel}',
            value: formatMoney(report.summary.ingresos),
            icon: Icons.trending_up_rounded,
            color: AppColors.chartColor1,
          ),
        if (access.purchases)
          HomeKpi(
            key: 'gastos',
            label: 'Gastos ${period.ofLabel}',
            value: formatMoney(report.summary.gastos),
            icon: Icons.trending_down_rounded,
            color: AppColors.error,
            background: AppColors.errorSoft,
          ),
        if (access.sales)
          HomeKpi(
            key: 'cantidad',
            label: 'Cantidad de ventas',
            value: '${report.ticket.salesCount}',
            icon: Icons.receipt_long_rounded,
            color: AppColors.success,
          ),
        if (access.profit)
          HomeKpi(
            key: 'margen',
            label: 'Margen de ganancia',
            value: marginText(report.summary.ingresos, report.summary.balance),
            icon: Icons.percent_rounded,
            color: AppColors.chartColor5,
          ),
      ];
      if (kpis.isNotEmpty) {
        sections.add(
          (_) => padded(
            HomeEntrance(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.s8),
                    child: HomeSectionTitle('Resumen'),
                  ),
                  HomeKpiGrid(items: kpis),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (report != null) {
      final noMovements =
          report.timeSeries.isEmpty ||
          (report.summary.ingresos == 0 && report.summary.gastos == 0);
      final noMovementsText = 'Aún no hay movimientos ${period.duringLabel}';
      final noSalesText = 'Aún no hay ventas ${period.duringLabel}';

      if (access.profit || access.sales) {
        sections.add(
          (_) => padded(
            const HomeSectionTitle('Análisis'),
            bottom: AppSpacing.s8,
          ),
        );
      }

      if (access.profit) {
        if (period != HomePeriod.today) {
          sections.add(
            (_) => padded(
              HomeChartCard(
                id: 'evolucion',
                title: 'Evolución ${period.ofLabel}',
                subtitle: period == HomePeriod.year
                    ? 'Ingresos y gastos por mes'
                    : 'Ingresos y gastos por día',
                child: noMovements
                    ? HomeEmptyMessage(noMovementsText)
                    : BiTimeSeriesChart(series: report.timeSeries),
              ),
            ),
          );
        }
        sections.add(
          (_) => padded(
            HomeChartCard(
              id: 'comparacion',
              title: 'Ingresos y gastos',
              subtitle: period.comparisonLabel,
              child: noMovements || previous == null
                  ? HomeEmptyMessage(noMovementsText)
                  : BiGroupedBars(
                      groups: const ['Ingresos', 'Gastos', 'Balance'],
                      seriesNames: const ['Actual', 'Anterior'],
                      values: [
                        [
                          report.summary.ingresos,
                          report.summary.gastos,
                          report.summary.balance,
                        ],
                        [previous.ingresos, previous.gastos, previous.balance],
                      ],
                      format: formatMoney,
                    ),
            ),
          ),
        );
      }
      if (access.sales) {
        sections.add(
          (_) => padded(
            HomeChartCard(
              id: 'categorias',
              title: 'Ventas por categoría',
              subtitle: 'Ingresos ${period.ofLabel}',
              child: report.salesByCategory.isEmpty
                  ? HomeEmptyMessage(noSalesText)
                  : BiPieChart(
                      entries: report.salesByCategory,
                      byQuantity: false,
                      quantityText: (e) => '${formatQuantity(e.quantity)} uds.',
                      maxItems: 5,
                    ),
            ),
          ),
        );
        sections.add(
          (ctx) => padded(
            HomeChartCard(
              id: 'productos',
              title: 'Productos más vendidos',
              subtitle: 'Ingresos ${period.ofLabel}',
              child: report.salesByProduct.isEmpty
                  ? HomeEmptyMessage(noSalesText)
                  : BiRankingChart(
                      entries: report.salesByProduct,
                      byQuantity: false,
                      quantityText: (e) => '${formatQuantity(e.quantity)} uds.',
                      maxItems: 5,
                      onEntryTap: access.businessIntelligence
                          ? (entry) => showBiDrillDown(
                              ctx,
                              kind: BiDrillKind.product,
                              entry: entry,
                              query: query,
                            )
                          : null,
                    ),
            ),
          ),
        );
      }
    }

    if (access.sales || access.purchases) {
      final clients = ref.watch(clientProvider).clients;
      final suppliers = ref.watch(supplierProvider).suppliers;
      String clientName(SaleModel sale) =>
          clients.where((c) => c.id == sale.clientId).firstOrNull?.name ??
          'Sin nombre';
      String supplierName(PurchaseModel purchase) =>
          suppliers.where((s) => s.id == purchase.supplierId).firstOrNull?.name ??
          'Sin proveedor';
      final activities = loading || failed
          ? const <HomeActivity>[]
          : recentActivity(
              sales: saleState.sales,
              purchases: purchaseState.purchases,
              clientName: clientName,
              supplierName: supplierName,
              now: now,
              includeSales: access.sales,
              includePurchases: access.purchases,
            );
      if (!loading && !failed) {
        sections.add(
          (_) => padded(
            const HomeSectionTitle('Actividad reciente'),
            bottom: AppSpacing.s8,
          ),
        );
        sections.add(
          (_) => padded(HomeActivityCard(activities: activities)),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const ScreenTopBar(actions: [ProfileButton()]),
          Expanded(
            child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HomeHeader(
              userName: user?.username ?? '',
              period: period,
              onPeriodChanged: (value) =>
                  ref.read(homePeriodProvider.notifier).state = value,
              hero: hero,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s16)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => sections[index](context),
              childCount: sections.length,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpacing.s24 + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(HomeShortcut shortcut) => switch (shortcut) {
    HomeShortcut.products => Icons.inventory_2_rounded,
    HomeShortcut.sales => Icons.point_of_sale_rounded,
    HomeShortcut.reports => Icons.bar_chart_rounded,
    HomeShortcut.businessIntelligence => Icons.insights_rounded,
  };

  void _open(BuildContext context, HomeShortcut shortcut) {
    switch (shortcut) {
      case HomeShortcut.products:
        _push(context, NavGroupId.inventario, const ProductsScreen());
      case HomeShortcut.sales:
        _push(context, NavGroupId.ventasCompras, const SalesPage());
      case HomeShortcut.reports:
        _push(context, NavGroupId.reportes, const ReportsPage());
      case HomeShortcut.businessIntelligence:
        _push(
          context,
          NavGroupId.reportes,
          const BusinessIntelligencePage(),
        );
    }
  }

  void _push(BuildContext context, NavGroupId group, Widget page) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShellPage(group: group, child: page)),
      );
}
