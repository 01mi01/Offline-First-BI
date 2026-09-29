import '../models/category_model.dart';
import '../models/client_model.dart';
import '../models/event_model.dart';
import '../models/location_model.dart';
import '../models/product_model.dart';
import '../models/purchase_item_model.dart';
import '../models/purchase_model.dart';
import '../models/report_filters.dart';
import '../models/report_models.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';
import '../models/supplier_model.dart';

// Filtrado, agregación y enriquecimiento de datos para el módulo de reportes
class ReportService {
  // ¿Hay algún filtro que se evalúe sobre las líneas de la venta?
  bool _hasLineFilters(ReportFilters filters) =>
      filters.productId != null ||
      filters.categoryId != null ||
      filters.priceType != null;

  // Una línea cumple los filtros de producto, categoría y tipo de precio
  // cuando cumple TODOS los que estén activos (sobre la misma línea).
  bool _lineMatches(
    SaleItemModel item,
    Map<int, int?> categoryByProduct,
    ReportFilters filters,
  ) {
    if (filters.productId != null && item.productId != filters.productId) {
      return false;
    }
    if (filters.categoryId != null &&
        categoryByProduct[item.productId] != filters.categoryId) {
      return false;
    }
    if (filters.priceType != null && item.priceType != filters.priceType) {
      return false;
    }
    return true;
  }

  // Filtra ventas según fecha, cliente, ubicación y evento (a nivel de venta)
  // y según producto, categoría y tipo de precio (a nivel de línea): una venta
  // se incluye si al menos una de sus líneas cumple todos los filtros de línea
  // activos a la vez.
  List<SaleModel> filterSales({
    required List<SaleModel> sales,
    required List<ProductModel> products,
    required Map<int, List<SaleItemModel>> saleItemsMap,
    required ReportFilters filters,
  }) {
    final categoryByProduct = {for (final p in products) p.id: p.categoryId};
    final lineFilters = _hasLineFilters(filters);

    return sales.where((s) {
      // Una venta cancelada ya no es un ingreso: su stock se devolvió.
      if (s.isCanceled) return false;
      if (filters.startDate != null && s.date.isBefore(filters.startDate!)) {
        return false;
      }
      if (filters.endDate != null) {
        // Límite superior exclusivo: el inicio del día siguiente a endDate.
        // Se trunca a fecha (sin hora) para que endDate incluya ese día
        // completo sin importar la hora exacta de s.date.
        final endExclusive = DateTime(
          filters.endDate!.year,
          filters.endDate!.month,
          filters.endDate!.day + 1,
        );
        if (!s.date.isBefore(endExclusive)) return false;
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

      if (lineFilters) {
        final items = saleItemsMap[s.id] ?? const <SaleItemModel>[];
        if (!items.any((i) => _lineMatches(i, categoryByProduct, filters))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Líneas de cada venta que cumplen los filtros de producto/categoría/tipo
  // de precio, con su categoría y su parte prorrateada del descuento de la
  // venta. Solo incluye entradas para ventas que tienen ítems; una venta sin
  // ítems no aparece y se reporta completa (ver SaleReportRow.lines).
  Map<int, List<SaleLineReport>> buildSaleLines({
    required List<SaleModel> sales,
    required List<ProductModel> products,
    required List<CategoryModel> categories,
    required Map<int, List<SaleItemModel>> saleItemsMap,
    required ReportFilters filters,
  }) {
    final categoryByProduct = {for (final p in products) p.id: p.categoryId};
    final categoryNames = {for (final c in categories) c.id: c.name};
    final result = <int, List<SaleLineReport>>{};

    for (final sale in sales) {
      final items = saleItemsMap[sale.id];
      if (items == null || items.isEmpty) continue;
      result[sale.id] = [
        for (final item in items)
          if (_lineMatches(item, categoryByProduct, filters))
            SaleLineReport(
              item: item,
              categoryId: categoryByProduct[item.productId],
              categoryName:
                  categoryNames[categoryByProduct[item.productId]] ??
                  'Sin categoría',
              discountShare: sale.totalAmount > 0
                  ? sale.discount * item.subtotal / sale.totalAmount
                  : 0,
            ),
      ];
    }
    return result;
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
      if (filters.endDate != null) {
        final endExclusive = DateTime(
          filters.endDate!.year,
          filters.endDate!.month,
          filters.endDate!.day + 1,
        );
        if (!p.date.isBefore(endExclusive)) return false;
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

  // Resume las ventas de un reporte: cuenta las ventas que tienen al menos
  // una línea incluida y suma los montos de esas líneas (no de la venta
  // completa).
  SalesSummary summarizeSaleRows(List<SaleReportRow> rows) {
    return SalesSummary(
      count: rows.length,
      totalAmount: rows.fold(0.0, (sum, r) => sum + r.netAmount),
      totalDiscount: rows.fold(0.0, (sum, r) => sum + r.discountAmount),
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

  // Enriquece ventas con el nombre de cliente, ubicación y evento. Si se
  // pasa [linesBySale] (ver buildSaleLines), cada fila queda limitada a las
  // líneas indicadas; una venta sin entrada se reporta completa.
  List<SaleReportRow> buildSaleRows({
    required List<SaleModel> sales,
    required List<ClientModel> clients,
    required List<LocationModel> locations,
    required List<EventModel> events,
    Map<int, List<SaleLineReport>>? linesBySale,
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
        lines: linesBySale?[s.id],
      );
    }).toList();
  }

  // Enriquece compras con el nombre de proveedor, ubicación y evento, y con
  // sus líneas de material ([itemsByPurchase], indexado por id de compra; una
  // compra sin entrada, como un gasto general, queda sin ítems).
  List<PurchaseReportRow> buildPurchaseRows({
    required List<PurchaseModel> purchases,
    required List<SupplierModel> suppliers,
    required List<LocationModel> locations,
    required List<EventModel> events,
    Map<int, List<PurchaseItemModel>>? itemsByPurchase,
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
        supplierName: supplier?.name ?? 'Sin proveedor',
        locationName: location != null
            ? '${location.city}, ${location.country}'
            : null,
        eventName: event?.name,
        items: itemsByPurchase?[p.id] ?? const [],
      );
    }).toList();
  }
}
