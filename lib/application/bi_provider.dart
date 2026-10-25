import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bi_config.dart';
import '../models/bi_models.dart';
import '../models/purchase_kind.dart';
import '../models/report_filters.dart';
import 'bi_service.dart';
import 'category_provider.dart';
import 'date_range_filter.dart';
import 'event_provider.dart';
import 'material_provider.dart';
import 'product_provider.dart';
import 'report_provider.dart';
import 'sale_provider.dart';
import 'today_provider.dart';
import 'unit_provider.dart';

final biServiceProvider = Provider<BiService>((ref) => BiService());

final biConfigProvider = StateProvider.autoDispose<BiConfig>(
  (ref) => BiConfig(),
);

final biReportProvider = Provider.autoDispose.family<BiReport, BiQuery>((
  ref,
  query,
) {
  final filters = query.filters;
  final reports = ref.watch(reportServiceProvider);
  final bi = ref.watch(biServiceProvider);
  ref.watch(todayProvider);
  final products = ref.watch(productProvider).products;
  final categories = ref.watch(categoryProvider).categories;
  final materials = ref.watch(materialProvider).materials;
  final units = ref.watch(unitProvider).units;
  final events = ref.watch(eventProvider).events;
  final sales = ref.watch(saleProvider).sales;
  final saleItemsMap = ref.watch(saleItemsMapProvider).valueOrNull ?? {};
  final itemsByPurchase = ref.watch(purchaseItemsMapProvider).valueOrNull ?? {};

  final rows = ref.watch(saleReportRowsProvider(filters));
  final purchases = ref.watch(filteredPurchasesProvider(filters));
  final eventPurchases = ref.watch(
    filteredPurchasesProvider(
      filters.copyWith(purchaseKind: PurchaseKind.all, clearSupplier: true),
    ),
  );
  final summary = bi.summarize(
    sales: reports.summarizeSaleRows(rows),
    purchases: reports.summarizePurchases(purchases),
  );
  final timeSeries = bi.timeSeries(
    rows: rows,
    purchases: purchases,
    filters: filters,
  );

  return BiReport(
    summary: summary,
    salesByProduct: bi.salesByProduct(rows: rows, products: products),
    salesByCategory: bi.salesByCategory(rows: rows),
    purchasesByMaterial: bi.purchasesByMaterial(
      purchases: purchases,
      itemsByPurchase: itemsByPurchase,
      materials: materials,
      units: units,
    ),
    salesByPriceType: bi.salesByPriceType(rows: rows),
    timeSeries: timeSeries,
    salesByEvent: bi.salesByEvent(rows: rows),
    lowStock: bi.lowStock(products: products, categories: categories),
    productMargins: bi.productMargins(rows: rows, products: products),
    projection: bi.projectSales(series: timeSeries, filters: filters),
    eventComparison: bi.compareEventDays(
      rows: rows,
      events: events,
      filters: filters,
    ),
    materialCost: bi.materialCost(
      purchases: purchases,
      revenue: summary.ingresos,
    ),
    noMovement: bi.noMovement(
      products: products,
      sales: sales,
      saleItemsMap: saleItemsMap,
      windowDays: query.noMovementDays,
    ),
    periodComparison: _periodComparison(ref, bi, filters, summary),
    radar: bi.radar(
      rows: rows,
      products: products,
      selectedIds: query.radarProductIds,
    ),
    coPurchases: bi.coPurchases(
      rows: rows,
      saleItemsMap: saleItemsMap,
      products: products,
    ),
    weekdays: bi.salesByWeekday(rows: rows),
    ticket: bi.ticket(rows: rows),
    eventProfit: bi.eventProfitability(
      rows: rows,
      purchases: eventPurchases,
      events: events,
    ),
    discounts: bi.discountImpact(rows: rows),
    costReturn: bi.costReturn(rows: rows, products: products),
  );
});

BiPeriodComparison _periodComparison(
  Ref ref,
  BiService bi,
  ReportFilters filters,
  BiSummary current,
) {
  final start = filters.startDate;
  final end = filters.endDate;
  if (start == null) {
    return const BiPeriodComparison.unavailable(
      'Elige un período con fecha de inicio (por ejemplo "Este mes") para '
      'compararlo con el anterior.',
    );
  }
  final today = ref.watch(todayProvider);
  var last = dateOnly(end ?? start);
  if (last.isAfter(today)) last = today;
  final preset = filters.datePreset;
  final previous = preset != null
      ? preset.previous(today)
      : bi.previousEqualLengthPeriod(start, last);
  final previousFilters = filters.copyWith(
    startDate: previous.start,
    endDate: previous.end,
    clearDatePreset: true,
  );
  final reports = ref.watch(reportServiceProvider);
  final prevSummary = bi.summarize(
    sales: reports.summarizeSaleRows(
      ref.watch(saleReportRowsProvider(previousFilters)),
    ),
    purchases: reports.summarizePurchases(
      ref.watch(filteredPurchasesProvider(previousFilters)),
    ),
  );
  return BiPeriodComparison(
    currentStart: dateOnly(start),
    currentEnd: last,
    previousStart: previous.start,
    previousEnd: previous.end,
    current: current,
    previous: prevSummary,
  );
}

typedef BiIdKey = ({BiQuery query, int id});
typedef BiCategoryKey = ({BiQuery query, String name});

final biProductDetailProvider = Provider.autoDispose
    .family<BiProductDetail, BiIdKey>((ref, key) {
      final filters = key.query.filters;
      final bi = ref.watch(biServiceProvider);
      final rows = ref.watch(saleReportRowsProvider(filters));
      final purchases = ref.watch(filteredPurchasesProvider(filters));
      return bi.productDetail(
        rows: rows,
        products: ref.watch(productProvider).products,
        productId: key.id,
        series: bi.timeSeries(rows: rows, purchases: purchases, filters: filters),
      );
    });

final biCategoryDetailProvider = Provider.autoDispose
    .family<BiCategoryDetail, BiCategoryKey>((ref, key) {
      return ref
          .watch(biServiceProvider)
          .categoryDetail(
            rows: ref.watch(saleReportRowsProvider(key.query.filters)),
            products: ref.watch(productProvider).products,
            categoryName: key.name,
          );
    });

final biEventDetailProvider = Provider.autoDispose
    .family<BiEventDetail, BiIdKey>((ref, key) {
      final filters = key.query.filters;
      final eventPurchases = ref.watch(
        filteredPurchasesProvider(
          filters.copyWith(purchaseKind: PurchaseKind.all, clearSupplier: true),
        ),
      );
      return ref
          .watch(biServiceProvider)
          .eventDetail(
            rows: ref.watch(saleReportRowsProvider(filters)),
            purchases: eventPurchases,
            itemsByPurchase:
                ref.watch(purchaseItemsMapProvider).valueOrNull ?? {},
            events: ref.watch(eventProvider).events,
            eventId: key.id,
          );
    });

final biMaterialDetailProvider = Provider.autoDispose
    .family<BiMaterialDetail, BiIdKey>((ref, key) {
      final filters = key.query.filters;
      final bi = ref.watch(biServiceProvider);
      final rows = ref.watch(saleReportRowsProvider(filters));
      final purchases = ref.watch(filteredPurchasesProvider(filters));
      return bi.materialDetail(
        purchases: purchases,
        itemsByPurchase: ref.watch(purchaseItemsMapProvider).valueOrNull ?? {},
        materials: ref.watch(materialProvider).materials,
        units: ref.watch(unitProvider).units,
        materialId: key.id,
        series: bi.timeSeries(rows: rows, purchases: purchases, filters: filters),
      );
    });
