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
import '../config/rounding.dart';
import 'date_range_filter.dart';
import 'location_options.dart';
import '../config/app_clock.dart';

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

  // ¿La fecha propia de un registro (venta o compra) cae dentro del rango de
  // los filtros? Trabaja con días completos: [startDate] incluye ese día desde
  // las 00:00 y el fin incluye ese día completo (con solo "Desde" el fin es
  // ese mismo día). Un registro con fecha posterior a hoy está solo
  // "preparado": todavía no ocurrió, así que nunca cuenta, ni siquiera con un
  // reporte sin fecha de fin. Se usa SIEMPRE la fecha del registro, nunca la de
  // un evento al que esté vinculado.
  bool isInReportRange(DateTime date, ReportFilters filters, {DateTime? now}) {
    final today = dateOnly(now ?? appNow());
    if (filters.startDate != null &&
        date.isBefore(dateOnly(filters.startDate!))) {
      return false;
    }
    var lastDay = today;
    final requestedEnd = filters.effectiveEndDate;
    if (requestedEnd != null && dateOnly(requestedEnd).isBefore(today)) {
      lastDay = dateOnly(requestedEnd);
    }
    // Límite superior exclusivo: el inicio del día siguiente al último día.
    final endExclusive = DateTime(lastDay.year, lastDay.month, lastDay.day + 1);
    return date.isBefore(endExclusive);
  }

  // Filtra ventas según fecha, cliente, ubicación y evento (a nivel de venta)
  // y según producto, categoría y tipo de precio (a nivel de línea): una venta
  // se incluye si al menos una de sus líneas cumple todos los filtros de línea
  // activos a la vez. [now] solo existe para poder probar el corte "hoy".
  List<SaleModel> filterSales({
    required List<SaleModel> sales,
    required List<ProductModel> products,
    required Map<int, List<SaleItemModel>> saleItemsMap,
    required ReportFilters filters,
    // Ubicaciones existentes: hacen falta para filtrar por país y ciudad.
    List<LocationModel> locations = const [],
    DateTime? now,
  }) {
    final locationById = {for (final l in locations) l.id: l};
    final categoryByProduct = {for (final p in products) p.id: p.categoryId};
    final lineFilters = _hasLineFilters(filters);

    return sales.where((s) {
      // Una venta cancelada ya no es un ingreso: su stock se devolvió.
      if (s.isCanceled) return false;
      if (!isInReportRange(s.date, filters, now: now)) return false;
      if (filters.clientId != null && s.clientId != filters.clientId) {
        return false;
      }
      if (filters.locationId != null && s.locationId != filters.locationId) {
        return false;
      }
      if (!locationMatches(
        locationById[s.locationId],
        country: filters.country,
        city: filters.city,
      )) {
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
      // Prorrateo del descuento a centavos: cada línea recibe su parte
      // redondeada y la última lo que falta, para que las partes de TODAS las
      // líneas sumen exactamente el descuento de la venta.
      final shares = <double>[];
      var assigned = 0.0;
      for (var i = 0; i < items.length; i++) {
        final share = i == items.length - 1
            ? round2(sale.discount - assigned)
            : (sale.totalAmount > 0
                  ? round2(sale.discount * items[i].subtotal / sale.totalAmount)
                  : 0.0);
        assigned += share;
        shares.add(share);
      }
      result[sale.id] = [
        for (var i = 0; i < items.length; i++)
          if (_lineMatches(items[i], categoryByProduct, filters))
            SaleLineReport(
              item: items[i],
              categoryId: categoryByProduct[items[i].productId],
              categoryName:
                  categoryNames[categoryByProduct[items[i].productId]] ??
                  'Sin categoría',
              discountShare: sale.totalAmount > 0 ? shares[i] : 0,
            ),
      ];
    }
    return result;
  }

  // Filtra compras según fecha, proveedor, ubicación y evento
  List<PurchaseModel> filterPurchases({
    required List<PurchaseModel> purchases,
    required ReportFilters filters,
    // Ubicaciones existentes: hacen falta para filtrar por país y ciudad.
    List<LocationModel> locations = const [],
    DateTime? now,
  }) {
    final locationById = {for (final l in locations) l.id: l};
    return purchases.where((p) {
      // Una compra cancelada ya no es un gasto: su stock se restó.
      if (p.isCanceled) return false;
      if (!filters.purchaseKind.includes(p)) return false;
      if (!isInReportRange(p.date, filters, now: now)) return false;
      if (filters.supplierId != null && p.supplierId != filters.supplierId) {
        return false;
      }
      if (filters.locationId != null && p.locationId != filters.locationId) {
        return false;
      }
      if (!locationMatches(
        locationById[p.locationId],
        country: filters.country,
        city: filters.city,
      )) {
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
      totalAmount: round2(rows.fold(0.0, (sum, r) => sum + r.netAmount)),
      totalDiscount: round2(rows.fold(0.0, (sum, r) => sum + r.discountAmount)),
    );
  }

  // Resume el total gastado y conteo de materiales de una lista de compras
  PurchasesSummary summarizePurchases(List<PurchaseModel> purchases) {
    return PurchasesSummary(
      count: purchases.length,
      totalAmount: round2(purchases.fold(0.0, (sum, p) => sum + p.totalAmount)),
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
            ? locationLabelWithZone(location)
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
            ? locationLabelWithZone(location)
            : null,
        eventName: event?.name,
        items: itemsByPurchase?[p.id] ?? const [],
      );
    }).toList();
  }
}
