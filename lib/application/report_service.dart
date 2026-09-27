import '../models/client_model.dart';
import '../models/event_model.dart';
import '../models/location_model.dart';
import '../models/product_model.dart';
import '../models/purchase_model.dart';
import '../models/report_filters.dart';
import '../models/report_models.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';
import '../models/supplier_model.dart';

// Filtrado, agregación y enriquecimiento de datos para el módulo de reportes
class ReportService {
  // Filtra ventas según fecha, cliente, ubicación, evento, producto y categoría
  List<SaleModel> filterSales({
    required List<SaleModel> sales,
    required List<ProductModel> products,
    required Map<int, List<SaleItemModel>> saleItemsMap,
    required ReportFilters filters,
  }) {
    return sales.where((s) {
      if (filters.startDate != null && s.date.isBefore(filters.startDate!)) {
        return false;
      }
      if (filters.endDate != null &&
          s.date.isAfter(filters.endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      if (filters.clientId != null && s.clientId != filters.clientId) {
        return false;
      }
      if (filters.locationId != null && s.locationId != filters.locationId) {
        return false;
      }
      if (filters.eventId != null && s.eventId != filters.eventId) {
        return false;
      }

      // Filtra por producto
      if (filters.productId != null) {
        final items = saleItemsMap[s.id] ?? [];
        final hasProduct = items.any((i) => i.productId == filters.productId);
        if (!hasProduct) return false;
      }

      // Filtra por categoría
      if (filters.categoryId != null) {
        final items = saleItemsMap[s.id] ?? [];
        final productIds = items.map((i) => i.productId).toSet();
        final hasCategory = productIds.any((pid) {
          final product = products.where((p) => p.id == pid).firstOrNull;
          return product?.categoryId == filters.categoryId;
        });
        if (!hasCategory) return false;
      }

      // Filtra por banda de precio (A/B) cobrada en algún ítem
      if (filters.priceType != null) {
        final items = saleItemsMap[s.id] ?? [];
        final hasPriceType = items.any((i) => i.priceType == filters.priceType);
        if (!hasPriceType) return false;
      }

      return true;
    }).toList();
  }

  // Filtra compras según fecha, proveedor, ubicación y evento
  List<PurchaseModel> filterPurchases({
    required List<PurchaseModel> purchases,
    required ReportFilters filters,
  }) {
    return purchases.where((p) {
      if (filters.startDate != null && p.date.isBefore(filters.startDate!)) {
        return false;
      }
      if (filters.endDate != null &&
          p.date.isAfter(filters.endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      if (filters.supplierId != null && p.supplierId != filters.supplierId) {
        return false;
      }
      if (filters.locationId != null && p.locationId != filters.locationId) {
        return false;
      }
      if (filters.eventId != null && p.eventId != filters.eventId) {
        return false;
      }
      return true;
    }).toList();
  }

  // Resume el total, ingresos y descuentos de una lista de ventas
  SalesSummary summarizeSales(List<SaleModel> sales) {
    return SalesSummary(
      count: sales.length,
      totalAmount: sales.fold(0.0, (sum, s) => sum + s.finalAmount),
      totalDiscount: sales.fold(0.0, (sum, s) => sum + s.discount),
    );
  }

  // Resume el total gastado y conteo de materiales de una lista de compras
  PurchasesSummary summarizePurchases(List<PurchaseModel> purchases) {
    return PurchasesSummary(
      count: purchases.length,
      totalAmount: purchases.fold(0.0, (sum, p) => sum + p.totalAmount),
      materialCount: purchases.where((p) => p.isMaterial).length,
    );
  }

  // Enriquece ventas con el nombre de cliente, ubicación y evento
  List<SaleReportRow> buildSaleRows({
    required List<SaleModel> sales,
    required List<ClientModel> clients,
    required List<LocationModel> locations,
    required List<EventModel> events,
  }) {
    return sales.map((s) {
      final client = clients.where((c) => c.id == s.clientId).firstOrNull;
      final location = locations
          .where((l) => l.id == s.locationId)
          .firstOrNull;
      final event = events.where((e) => e.id == s.eventId).firstOrNull;
      return SaleReportRow(
        sale: s,
        clientName: client?.name ?? 'Sin nombre',
        locationName: location != null
            ? '${location.city}, ${location.country}'
            : null,
        eventName: event?.name,
      );
    }).toList();
  }

  // Enriquece compras con el nombre de proveedor, ubicación y evento
  List<PurchaseReportRow> buildPurchaseRows({
    required List<PurchaseModel> purchases,
    required List<SupplierModel> suppliers,
    required List<LocationModel> locations,
    required List<EventModel> events,
  }) {
    return purchases.map((p) {
      final supplier = suppliers
          .where((s) => s.id == p.supplierId)
          .firstOrNull;
      final location = locations
          .where((l) => l.id == p.locationId)
          .firstOrNull;
      final event = events.where((e) => e.id == p.eventId).firstOrNull;
      return PurchaseReportRow(
        purchase: p,
        supplierName: supplier?.name ?? 'Sin nombre',
        locationName: location != null
            ? '${location.city}, ${location.country}'
            : null,
        eventName: event?.name,
      );
    }).toList();
  }
}
