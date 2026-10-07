import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sale_provider.dart';
import '../../application/purchase_provider.dart';
import '../../application/report_provider.dart';
import '../../models/report_filters.dart';
import '../../models/report_models.dart';
import '../../models/purchase_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/report_filters_widget.dart';
import '../widgets/report_sale_card.dart';
import '../widgets/report_purchase_card.dart';
import 'report_detail_page.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: 'Reportes', showBack: true),
      body: const ReportsBody(),
    );
  }
}

// Contenido de reportes (filtros + tabs Ventas/Compras), sin AppBar propia.
// Se usa tanto en ReportsPage (con AppBar y back) como embebido en el sub-tab
// "Reportes" del tab "Reportes + BI" de la navegación inferior (sin AppBar).
class ReportsBody extends ConsumerStatefulWidget {
  const ReportsBody({super.key});

  @override
  ConsumerState<ReportsBody> createState() => _ReportsBodyState();
}

class _ReportsBodyState extends ConsumerState<ReportsBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Cada pestaña (Ventas / Compras) conserva sus propios filtros: cambiar de
  // pestaña no arrastra las fechas ni el resto de filtros de la otra.
  ReportFilters _salesFilters = const ReportFilters();
  ReportFilters _purchaseFilters = const ReportFilters();
  int _currentTab = 0;

  ReportFilters get _activeFilters =>
      _currentTab == 0 ? _salesFilters : _purchaseFilters;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentTab = _tabController.index);
    });
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
    final filteredPurchases = ref.watch(
      filteredPurchasesProvider(_purchaseFilters),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Tabs Ventas/Compras, embebidos en el contenido (sin AppBar propia)
            Material(
              color: AppColors.background,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
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

            // Panel de filtros. Con el buscador en línea abierto y el teclado
            // arriba puede no caber: se limita a la mitad del alto disponible y se
            // desplaza dentro (sin recortar el resto, que sigue debajo).
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.5,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  ReportFiltersWidget(
                    filters: _activeFilters,
                    onChanged: (f) => setState(() {
                      if (_currentTab == 0) {
                        _salesFilters = f;
                      } else {
                        _purchaseFilters = f;
                      }
                    }),
                    activeTab: _currentTab,
                  ),
                ],
              ),
            ),

            // Tabs de contenido
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Container(
                    key: ValueKey(_salesFilters.hashCode),
                    color: AppColors.background,
                    child: _SalesTab(rows: saleRows),
                  ),
                  Container(
                    key: ValueKey(_purchaseFilters.hashCode + 1),
                    color: AppColors.background,
                    child: _PurchasesTab(purchases: filteredPurchases),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Tab de ventas
class _SalesTab extends ConsumerWidget {
  final List<SaleReportRow> rows;

  const _SalesTab({required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reportServiceProvider).summarizeSaleRows(rows);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      children: [
        const SizedBox(height: AppSpacing.s16),
        _SummaryBar(
          children: [
            _SummaryTile(label: 'Ventas', value: '${summary.count}'),
            _SummaryTile(
              label: 'Ingresos',
              value: 'Bs. ${summary.totalAmount.toStringAsFixed(2)}',
              valueColor: AppColors.primary,
            ),
            _SummaryTile(
              label: 'Descuentos',
              value: 'Bs. ${summary.totalDiscount.toStringAsFixed(2)}',
              valueColor: AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        _ViewFullReportButton(
          enabled: rows.isNotEmpty,
          onTap: () => Navigator.push(
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
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.s32),
            child: Center(
              child: Text(
                'Sin resultados para los filtros aplicados',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...rows.map((r) => ReportSaleCard(row: r)),
      ],
    );
  }
}

// Tab de compras
class _PurchasesTab extends ConsumerWidget {
  final List<PurchaseModel> purchases;

  const _PurchasesTab({required this.purchases});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(purchasesSummaryProvider(purchases));
    final rows = ref.watch(purchaseReportRowsProvider(purchases));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      children: [
        const SizedBox(height: AppSpacing.s16),
        _SummaryBar(
          children: [
            _SummaryTile(label: 'Compras', value: '${summary.count}'),
            _SummaryTile(
              label: 'Gasto total',
              value: 'Bs. ${summary.totalAmount.toStringAsFixed(2)}',
              valueColor: AppColors.error,
            ),
            _SummaryTile(
              label: materialsSummaryLabel(summary.materialCount),
              value: '${summary.materialCount}',
              valueColor: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        _ViewFullReportButton(
          enabled: purchases.isNotEmpty,
          onTap: () => Navigator.push(
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
        const SizedBox(height: 12),
        if (purchases.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.s32),
            child: Center(
              child: Text(
                'Sin resultados para los filtros aplicados',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...rows.map(
            (r) => ReportPurchaseCard(
              purchase: r.purchase,
              supplierName: r.supplierName,
              locationName: r.locationName,
              eventName: r.eventName,
            ),
          ),
      ],
    );
  }
}

// Barra de resumen
class _SummaryBar extends StatelessWidget {
  final List<Widget> children;

  const _SummaryBar({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: children.map((c) => Expanded(child: c)).toList()),
    );
  }
}

// Tile de resumen
class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// Etiqueta del conteo de compras de materiales en el resumen: "1 Material" en
// singular, "N Materiales" en cualquier otro caso (incluido 0).
String materialsSummaryLabel(int count) => count == 1 ? 'Material' : 'Materiales';

// Botón ver reporte completo
class _ViewFullReportButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ViewFullReportButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: const Icon(Icons.open_in_new, size: 16),
      label: const Text('Ver reporte completo y exportar'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
    );
  }
}
