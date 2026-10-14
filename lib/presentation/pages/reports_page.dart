import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/purchase_provider.dart';
import '../../application/report_provider.dart';
import '../../application/sale_provider.dart';
import '../../config/rounding.dart';
import '../../models/purchase_model.dart';
import '../../models/report_filters.dart';
import '../../models/report_models.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_group.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_filters_widget.dart';
import '../widgets/report_records.dart';
import '../widgets/screen_header.dart';
import 'report_detail_page.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ScreenScaffold(
      title: 'Reportes',
      body: ReportsBody(),
    );
  }
}

class ReportsBody extends ConsumerStatefulWidget {
  const ReportsBody({super.key});

  @override
  ConsumerState<ReportsBody> createState() => _ReportsBodyState();
}

class _ReportsBodyState extends ConsumerState<ReportsBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReportFilters _salesFilters = const ReportFilters();
  ReportFilters _purchaseFilters = const ReportFilters();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saleState = ref.watch(saleProvider);
    final purchaseState = ref.watch(purchaseProvider);
    final saleItemsMapAsync = ref.watch(saleItemsMapProvider);

    if (saleState.isLoading ||
        purchaseState.isLoading ||
        saleItemsMapAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final saleRows = ref.watch(saleReportRowsProvider(_salesFilters));
    final purchases = ref.watch(filteredPurchasesProvider(_purchaseFilters));

    return Column(
      children: [
        Material(
          color: AppColors.background,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.cyanDark,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.cyanDark,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Ventas'),
              Tab(text: 'Compras'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
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
      ],
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
          child: _ReportSummary(
            values: [
              ('Ventas', '${summary.count}'),
              ('Ingresos', 'Bs. ${fixed2(summary.totalAmount)}'),
              ('Descuentos', 'Bs. ${fixed2(summary.totalDiscount)}'),
            ],
            enabled: rows.isNotEmpty,
            onOpen: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportDetailPage(
                  title: 'Reporte de Ventas',
                  type: ReportType.sales,
                  saleRows: rows,
                  purchases: const [],
                ),
              ),
            ),
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
          child: SizedBox(
            height: AppSpacing.s24 + MediaQuery.paddingOf(context).bottom,
          ),
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
          child: _ReportSummary(
            values: [
              ('Compras', '${summary.count}'),
              ('Gasto total', 'Bs. ${fixed2(summary.totalAmount)}'),
              (
                materialsSummaryLabel(summary.materialCount),
                '${summary.materialCount}',
              ),
            ],
            enabled: purchases.isNotEmpty,
            onOpen: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportDetailPage(
                  title: 'Reporte de Compras',
                  type: ReportType.purchases,
                  saleRows: const [],
                  purchases: purchases,
                ),
              ),
            ),
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
          child: SizedBox(
            height: AppSpacing.s24 + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

class _ReportSummary extends StatelessWidget {
  final List<(String, String)> values;
  final bool enabled;
  final VoidCallback onOpen;

  const _ReportSummary({
    required this.values,
    required this.enabled,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSection(
          children: [
            for (final (label, value) in values)
              AppValueRow(label: label, value: value),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            0,
            AppSpacing.s16,
            AppSpacing.s16,
          ),
          child: ElevatedButton.icon(
            onPressed: enabled ? onOpen : null,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Ver reporte completo y exportar'),
          ),
        ),
      ],
    );
  }
}

String materialsSummaryLabel(int count) => count == 1 ? 'Material' : 'Materiales';
