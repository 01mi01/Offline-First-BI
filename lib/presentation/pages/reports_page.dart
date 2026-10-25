import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/purchase_provider.dart';
import '../../application/report_provider.dart';
import '../../application/sale_provider.dart';
import '../../application/today_provider.dart';
import '../../config/rounding.dart';
import '../../models/purchase_model.dart';
import '../../models/report_filters.dart';
import '../../models/report_models.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_controls.dart';
import '../widgets/app_group.dart';
import '../widgets/empty_state.dart';
import '../widgets/kpi_grid.dart';
import '../widgets/profile_button.dart';
import '../widgets/report_filters_widget.dart';
import '../widgets/report_records.dart';
import '../widgets/screen_header.dart';
import 'report_detail_page.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportFilters _salesFilters = const ReportFilters();
  ReportFilters _purchaseFilters = const ReportFilters();

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime>(todayProvider, (previous, next) {
      setState(() {
        _salesFilters = _salesFilters.refreshedFor(next);
        _purchaseFilters = _purchaseFilters.refreshedFor(next);
      });
    });
    final saleState = ref.watch(saleProvider);
    final purchaseState = ref.watch(purchaseProvider);
    final loading =
        saleState.isLoading ||
        purchaseState.isLoading ||
        ref.watch(saleItemsMapProvider).isLoading;

    final saleRows = loading
        ? const <SaleReportRow>[]
        : ref.watch(saleReportRowsProvider(_salesFilters));
    final purchases = loading
        ? const <PurchaseModel>[]
        : ref.watch(filteredPurchasesProvider(_purchaseFilters));

    return DefaultTabController(
      length: 2,
      child: ScreenScaffold(
        title: 'Reportes',
        actions: const [ProfileButton()],
        bottom: const AppTabSwitcher(labels: ['Ventas', 'Compras']),
        bottomBar: loading
            ? null
            : _ExportBar(saleRows: saleRows, purchases: purchases),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _SalesTab(
                    rows: saleRows,
                    hasSales: saleState.sales.isNotEmpty,
                    filters: _salesFilters,
                    onFilters: (f) => setState(() => _salesFilters = f),
                  ),
                  _PurchasesTab(
                    purchases: purchases,
                    hasPurchases: purchaseState.purchases.isNotEmpty,
                    filters: _purchaseFilters,
                    onFilters: (f) => setState(() => _purchaseFilters = f),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  final List<SaleReportRow> saleRows;
  final List<PurchaseModel> purchases;

  const _ExportBar({required this.saleRows, required this.purchases});

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sales = controller.index == 0;
        final enabled = sales ? saleRows.isNotEmpty : purchases.isNotEmpty;
        return ElevatedButton(
          key: const ValueKey('report-export'),
          onPressed: enabled
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportDetailPage(
                      title: sales ? 'Reporte de Ventas' : 'Reporte de Compras',
                      type: sales ? ReportType.sales : ReportType.purchases,
                      saleRows: sales ? saleRows : const [],
                      purchases: sales ? const [] : purchases,
                    ),
                  ),
                )
              : null,
          child: const Text('Exportar el reporte'),
        );
      },
    );
  }
}

class _SalesTab extends ConsumerWidget {
  final List<SaleReportRow> rows;
  final bool hasSales;
  final ReportFilters filters;
  final ValueChanged<ReportFilters> onFilters;

  const _SalesTab({
    required this.rows,
    required this.hasSales,
    required this.filters,
    required this.onFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reportServiceProvider).summarizeSaleRows(rows);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ReportFiltersWidget(
            filters: filters,
            onChanged: onFilters,
            activeTab: 0,
          ),
        ),
        SliverToBoxAdapter(
          child: _ReportKpis(
            items: [
              AppKpi(
                key: 'report-income',
                label: 'Ingresos',
                value: 'Bs. ${fixed2(summary.totalAmount)}',
                icon: Icons.trending_up_rounded,
                color: AppColors.cyanDark,
              ),
              AppKpi(
                key: 'report-count',
                label: 'Ventas',
                value: '${summary.count}',
                icon: Icons.point_of_sale_rounded,
                color: AppColors.blue,
              ),
            ],
          ),
        ),
        if (rows.isEmpty)
          SliverToBoxAdapter(
            child: hasSales
                ? const AppEmptyState.noMatch()
                : AppEmptyState.list(
                    plural: 'ventas',
                    icon: Icons.point_of_sale_rounded,
                  ),
          )
        else
          AppSliverGroup(
            itemCount: rows.length,
            itemBuilder: (context, index) =>
                ReportSaleRowTile(row: rows[index]),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.s24),
        ),
      ],
    );
  }
}

class _PurchasesTab extends ConsumerWidget {
  final List<PurchaseModel> purchases;
  final bool hasPurchases;
  final ReportFilters filters;
  final ValueChanged<ReportFilters> onFilters;

  const _PurchasesTab({
    required this.purchases,
    required this.hasPurchases,
    required this.filters,
    required this.onFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(purchasesSummaryProvider(purchases));
    final rows = ref.watch(purchaseReportRowsProvider(purchases));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ReportFiltersWidget(
            filters: filters,
            onChanged: onFilters,
            activeTab: 1,
          ),
        ),
        SliverToBoxAdapter(
          child: _ReportKpis(
            items: [
              AppKpi(
                key: 'report-expense',
                label: 'Gasto total',
                value: 'Bs. ${fixed2(summary.totalAmount)}',
                icon: Icons.trending_down_rounded,
                color: AppColors.error,
                background: AppColors.errorSoft,
              ),
              AppKpi(
                key: 'report-count',
                label: 'Compras',
                value: '${summary.count}',
                icon: Icons.shopping_bag_rounded,
                color: AppColors.blue,
              ),
            ],
          ),
        ),
        if (purchases.isEmpty)
          SliverToBoxAdapter(
            child: hasPurchases
                ? const AppEmptyState.noMatch()
                : AppEmptyState.list(
                    plural: 'compras',
                    icon: Icons.shopping_bag_rounded,
                  ),
          )
        else
          AppSliverGroup(
            itemCount: rows.length,
            itemBuilder: (context, index) =>
                ReportPurchaseRowTile(row: rows[index]),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.s24),
        ),
      ],
    );
  }
}

class _ReportKpis extends StatelessWidget {
  final List<AppKpi> items;

  const _ReportKpis({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s4,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      child: AppKpiGrid(items: items, cardHeight: 136),
    );
  }
}
