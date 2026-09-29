import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/report_export_repository.dart';
import '../models/purchase_item_model.dart';
import '../models/purchase_model.dart';
import '../models/report_filters.dart';
import '../models/report_models.dart';
import '../models/sale_item_model.dart';
import 'category_provider.dart';
import 'client_provider.dart';
import 'event_provider.dart';
import 'location_provider.dart';
import 'product_provider.dart';
import 'purchase_provider.dart';
import 'report_service.dart';
import 'sale_provider.dart';
import 'supplier_provider.dart';

final reportServiceProvider = Provider<ReportService>((ref) => ReportService());

final reportExportRepositoryProvider = Provider<ReportExportRepository>(
  (ref) => ReportExportRepository(),
);

// Ítems de todas las ventas, agrupados por venta, para filtrar por producto/categoría
final saleItemsMapProvider =
    FutureProvider.autoDispose<Map<int, List<SaleItemModel>>>((ref) async {
  final sales = ref.watch(saleProvider).sales;
  final notifier = ref.read(saleProvider.notifier);
  final map = <int, List<SaleItemModel>>{};
  for (final sale in sales) {
    map[sale.id] = await notifier.getItemsForSale(sale.id);
  }
  return map;
});

// Ítems de material de todas las compras, agrupados por compra, para los
// reportes de compras.
final purchaseItemsMapProvider =
    FutureProvider.autoDispose<Map<int, List<PurchaseItemModel>>>((ref) async {
  final purchases = ref.watch(purchaseProvider).purchases;
  final notifier = ref.read(purchaseProvider.notifier);
  final map = <int, List<PurchaseItemModel>>{};
  for (final purchase in purchases) {
    if (!purchase.isMaterial) continue;
    map[purchase.id] = await notifier.getItemsForPurchase(purchase.id);
  }
  return map;
});

final filteredPurchasesProvider = Provider.autoDispose
    .family<List<PurchaseModel>, ReportFilters>((ref, filters) {
  final purchases = ref.watch(purchaseProvider).purchases;
  final service = ref.watch(reportServiceProvider);
  return service.filterPurchases(purchases: purchases, filters: filters);
});

final purchasesSummaryProvider = Provider.autoDispose
    .family<PurchasesSummary, List<PurchaseModel>>((ref, purchases) {
  return ref.watch(reportServiceProvider).summarizePurchases(purchases);
});

// Filas del reporte de ventas: ventas que cumplen los filtros, cada una
// limitada a las líneas (ítems) que cumplen los filtros de producto,
// categoría y tipo de precio.
final saleReportRowsProvider = Provider.autoDispose
    .family<List<SaleReportRow>, ReportFilters>((ref, filters) {
  final sales = ref.watch(saleProvider).sales;
  final products = ref.watch(productProvider).products;
  final categories = ref.watch(categoryProvider).categories;
  final saleItemsMap = ref.watch(saleItemsMapProvider).valueOrNull ?? {};
  final clients = ref.watch(clientProvider).clients;
  final locations = ref.watch(locationProvider).locations;
  final events = ref.watch(eventProvider).events;
  final service = ref.watch(reportServiceProvider);

  final filtered = service.filterSales(
    sales: sales,
    products: products,
    saleItemsMap: saleItemsMap,
    filters: filters,
  );
  return service.buildSaleRows(
    sales: filtered,
    clients: clients,
    locations: locations,
    events: events,
    linesBySale: service.buildSaleLines(
      sales: filtered,
      products: products,
      categories: categories,
      saleItemsMap: saleItemsMap,
      filters: filters,
    ),
  );
});

final salesSummaryProvider = Provider.autoDispose
    .family<SalesSummary, ReportFilters>((ref, filters) {
  return ref
      .watch(reportServiceProvider)
      .summarizeSaleRows(ref.watch(saleReportRowsProvider(filters)));
});

final purchaseReportRowsProvider = Provider.autoDispose
    .family<List<PurchaseReportRow>, List<PurchaseModel>>((ref, purchases) {
  final suppliers = ref.watch(supplierProvider).suppliers;
  final locations = ref.watch(locationProvider).locations;
  final events = ref.watch(eventProvider).events;
  final itemsByPurchase = ref.watch(purchaseItemsMapProvider).valueOrNull ?? {};
  return ref.watch(reportServiceProvider).buildPurchaseRows(
    purchases: purchases,
    suppliers: suppliers,
    locations: locations,
    events: events,
    itemsByPurchase: itemsByPurchase,
  );
});
