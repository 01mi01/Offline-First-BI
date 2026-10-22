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

class ReportService {
  bool _hasLineFilters(ReportFilters filters) =>
      filters.productId != null ||
      filters.categoryId != null ||
      filters.priceType != null;

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
    final endExclusive = DateTime(lastDay.year, lastDay.month, lastDay.day + 1);
    return date.isBefore(endExclusive);
  }

  List<SaleModel> filterSales({
    required List<SaleModel> sales,
    required List<ProductModel> products,
    required Map<int, List<SaleItemModel>> saleItemsMap,
    required ReportFilters filters,
    List<LocationModel> locations = const [],
  }) {
    final locationById = {for (final l in locations) l.id: l};
    final categoryByProduct = {for (final p in products) p.id: p.categoryId};
    final lineFilters = _hasLineFilters(filters);

    return sales.where((s) {
      if (s.isCanceled) return false;
      if (!isInReportRange(s.date, filters)) return false;
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

  List<PurchaseModel> filterPurchases({
    required List<PurchaseModel> purchases,
    required ReportFilters filters,
    List<LocationModel> locations = const [],
  }) {
    final locationById = {for (final l in locations) l.id: l};
    return purchases.where((p) {
      if (p.isCanceled) return false;
      if (!filters.purchaseKind.includes(p)) return false;
      if (!isInReportRange(p.date, filters)) return false;
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

  SalesSummary summarizeSaleRows(List<SaleReportRow> rows) {
    return SalesSummary(
      count: rows.length,
      totalAmount: round2(rows.fold(0.0, (sum, r) => sum + r.netAmount)),
      totalDiscount: round2(rows.fold(0.0, (sum, r) => sum + r.discountAmount)),
    );
  }

  PurchasesSummary summarizePurchases(List<PurchaseModel> purchases) {
    return PurchasesSummary(
      count: purchases.length,
      totalAmount: round2(purchases.fold(0.0, (sum, p) => sum + p.totalAmount)),
      materialCount: purchases.where((p) => p.isMaterial).length,
    );
  }

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
