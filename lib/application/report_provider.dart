import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/report_export_repository.dart';
import '../models/purchase_model.dart';
import '../models/report_filters.dart';
import '../models/report_models.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';
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

final filteredSalesProvider = Provider.autoDispose
    .family<List<SaleModel>, ReportFilters>((ref, filters) {
  final sales = ref.watch(saleProvider).sales;
  final products = ref.watch(productProvider).products;
  final saleItemsMap = ref.watch(saleItemsMapProvider).valueOrNull ?? {};
  final service = ref.watch(reportServiceProvider);
  return service.filterSales(
    sales: sales,
    products: products,
    saleItemsMap: saleItemsMap,
    filters: filters,
  );
});

final filteredPurchasesProvider = Provider.autoDispose
    .family<List<PurchaseModel>, ReportFilters>((ref, filters) {
  final purchases = ref.watch(purchaseProvider).purchases;
  final service = ref.watch(reportServiceProvider);
  return service.filterPurchases(purchases: purchases, filters: filters);
});

final salesSummaryProvider = Provider.autoDispose
    .family<SalesSummary, List<SaleModel>>((ref, sales) {
  return ref.watch(reportServiceProvider).summarizeSales(sales);
});

final purchasesSummaryProvider = Provider.autoDispose
    .family<PurchasesSummary, List<PurchaseModel>>((ref, purchases) {
  return ref.watch(reportServiceProvider).summarizePurchases(purchases);
});

final saleReportRowsProvider = Provider.autoDispose
    .family<List<SaleReportRow>, List<SaleModel>>((ref, sales) {
  final clients = ref.watch(clientProvider).clients;
  final locations = ref.watch(locationProvider).locations;
  final events = ref.watch(eventProvider).events;
  return ref.watch(reportServiceProvider).buildSaleRows(
    sales: sales,
    clients: clients,
    locations: locations,
    events: events,
  );
});

final purchaseReportRowsProvider = Provider.autoDispose
    .family<List<PurchaseReportRow>, List<PurchaseModel>>((ref, purchases) {
  final suppliers = ref.watch(supplierProvider).suppliers;
  final locations = ref.watch(locationProvider).locations;
  final events = ref.watch(eventProvider).events;
  return ref.watch(reportServiceProvider).buildPurchaseRows(
    purchases: purchases,
    suppliers: suppliers,
    locations: locations,
    events: events,
  );
});
