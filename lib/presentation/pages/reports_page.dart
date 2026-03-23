import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sale_provider.dart';
import '../../application/purchase_provider.dart';
import '../../application/client_provider.dart';
import '../../application/supplier_provider.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../../application/product_provider.dart';
import '../../models/sale_model.dart';
import '../../models/purchase_model.dart';
import '../../models/sale_item_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/report_filters_widget.dart';
import '../widgets/report_sale_card.dart';
import '../widgets/report_purchase_card.dart';
import 'report_detail_page.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReportFilters _filters = const ReportFilters();
  int _currentTab = 0;

  // Mapa de saleId -> lista de ítems, para filtrar por producto/categoría
  Map<int, List<SaleItemModel>> _saleItemsMap = {};
  bool _loadingItems = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentTab = _tabController.index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllSaleItems();
    });
  }

  // Precarga todos los ítems de ventas para filtrar por producto y categoría
  Future<void> _loadAllSaleItems() async {
    // Espera a que carguen las ventas si aún están cargando
    var sales = ref.read(saleProvider).sales;
    if (sales.isEmpty && ref.read(saleProvider).isLoading) {
      await Future.delayed(const Duration(milliseconds: 500));
      sales = ref.read(saleProvider).sales;
    }
    final map = <int, List<SaleItemModel>>{};
    for (final sale in sales) {
      final items = await ref
          .read(saleProvider.notifier)
          .getItemsForSale(sale.id);
      map[sale.id] = items;
    }
    if (mounted) {
      setState(() {
        _saleItemsMap = map;
        _loadingItems = false;
      });
    }
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

    if (saleState.isLoading || purchaseState.isLoading || _loadingItems) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final products = ref.watch(productProvider).products;
    final allSales = saleState.sales;
    final allPurchases = purchaseState.purchases;

    final filteredSales = allSales.where((s) {
      if (_filters.startDate != null && s.date.isBefore(_filters.startDate!))
        return false;
      if (_filters.endDate != null &&
          s.date.isAfter(_filters.endDate!.add(const Duration(days: 1))))
        return false;
      if (_filters.clientId != null && s.clientId != _filters.clientId)
        return false;
      if (_filters.locationId != null && s.locationId != _filters.locationId)
        return false;
      if (_filters.eventId != null && s.eventId != _filters.eventId)
        return false;

      // Filtra por producto
      if (_filters.productId != null) {
        final items = _saleItemsMap[s.id] ?? [];
        final hasProduct = items.any((i) => i.productId == _filters.productId);
        if (!hasProduct) return false;
      }

      // Filtra por categoría
      if (_filters.categoryId != null) {
        final items = _saleItemsMap[s.id] ?? [];
        final productIds = items.map((i) => i.productId).toSet();
        final hasCategory = productIds.any((pid) {
          final product = products.where((p) => p.id == pid).firstOrNull;
          return product?.categoryId == _filters.categoryId;
        });
        if (!hasCategory) return false;
      }

      return true;
    }).toList();

    final filteredPurchases = allPurchases.where((p) {
      if (_filters.startDate != null && p.date.isBefore(_filters.startDate!))
        return false;
      if (_filters.endDate != null &&
          p.date.isAfter(_filters.endDate!.add(const Duration(days: 1))))
        return false;
      if (_filters.supplierId != null && p.supplierId != _filters.supplierId)
        return false;
      if (_filters.locationId != null && p.locationId != _filters.locationId)
        return false;
      if (_filters.eventId != null && p.eventId != _filters.eventId)
        return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Reportes',
        showBack: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: 'Ventas'),
            Tab(text: 'Compras'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Panel de filtros
          ReportFiltersWidget(
            filters: _filters,
            onChanged: (f) => setState(() => _filters = f),
            activeTab: _currentTab,
          ),

          // Tabs de contenido
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Container(
                  key: ValueKey(_filters.hashCode),
                  color: AppColors.background,
                  child: _SalesTab(sales: filteredSales),
                ),
                Container(
                  key: ValueKey(_filters.hashCode + 1),
                  color: AppColors.background,
                  child: _PurchasesTab(purchases: filteredPurchases),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Tab de ventas
class _SalesTab extends ConsumerWidget {
  final List<SaleModel> sales;

  const _SalesTab({required this.sales});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientProvider).clients;
    final locations = ref.watch(locationProvider).locations;
    final events = ref.watch(eventProvider).events;

    final totalAmount = sales.fold(0.0, (sum, s) => sum + s.finalAmount);
    final totalDiscount = sales.fold(0.0, (sum, s) => sum + s.discount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const SizedBox(height: 16),
        _SummaryBar(
          children: [
            _SummaryTile(label: 'Ventas', value: '${sales.length}'),
            _SummaryTile(
              label: 'Ingresos',
              value: 'Bs. ${totalAmount.toStringAsFixed(2)}',
              valueColor: AppColors.primary,
            ),
            _SummaryTile(
              label: 'Descuentos',
              value: 'Bs. ${totalDiscount.toStringAsFixed(2)}',
              valueColor: AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ViewFullReportButton(
          enabled: sales.isNotEmpty,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailPage(
                title: 'Reporte de Ventas',
                type: ReportType.sales,
                sales: sales,
                purchases: const [],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (sales.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(
              child: Text(
                'Sin resultados para los filtros aplicados',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...sales.map((s) {
            final client = clients.where((c) => c.id == s.clientId).firstOrNull;
            final location = locations
                .where((l) => l.id == s.locationId)
                .firstOrNull;
            final event = events.where((e) => e.id == s.eventId).firstOrNull;
            return ReportSaleCard(
              sale: s,
              clientName: client?.name ?? 'Sin nombre',
              locationName: location != null
                  ? '${location.city}, ${location.country}'
                  : null,
              eventName: event?.name,
            );
          }),
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
    final suppliers = ref.watch(supplierProvider).suppliers;
    final locations = ref.watch(locationProvider).locations;
    final events = ref.watch(eventProvider).events;

    final totalAmount = purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
    final materialCount = purchases.where((p) => p.isMaterial).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const SizedBox(height: 16),
        _SummaryBar(
          children: [
            _SummaryTile(label: 'Compras', value: '${purchases.length}'),
            _SummaryTile(
              label: 'Gasto total',
              value: 'Bs. ${totalAmount.toStringAsFixed(2)}',
              valueColor: AppColors.error,
            ),
            _SummaryTile(
              label: 'Materiales',
              value: '$materialCount',
              valueColor: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ViewFullReportButton(
          enabled: purchases.isNotEmpty,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailPage(
                title: 'Reporte de Compras',
                type: ReportType.purchases,
                sales: const [],
                purchases: purchases,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (purchases.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(
              child: Text(
                'Sin resultados para los filtros aplicados',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...purchases.map((p) {
            final supplier = suppliers
                .where((s) => s.id == p.supplierId)
                .firstOrNull;
            final location = locations
                .where((l) => l.id == p.locationId)
                .firstOrNull;
            final event = events.where((e) => e.id == p.eventId).firstOrNull;
            return ReportPurchaseCard(
              purchase: p,
              supplierName: supplier?.name ?? 'Sin nombre',
              locationName: location != null
                  ? '${location.city}, ${location.country}'
                  : null,
              eventName: event?.name,
            );
          }),
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
      padding: const EdgeInsets.all(16),
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
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

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
