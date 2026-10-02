import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bi_models.dart';
import '../models/report_filters.dart';
import 'bi_service.dart';
import 'category_provider.dart';
import 'material_provider.dart';
import 'product_provider.dart';
import 'report_provider.dart';
import 'unit_provider.dart';

final biServiceProvider = Provider<BiService>((ref) => BiService());

// Todos los indicadores de Business Intelligence para un conjunto de filtros.
// Parte de las mismas ventas y compras filtradas que Reportes (por lo que
// respeta la fecha propia de cada registro y excluye ventas canceladas y
// registros con fecha futura), y de ahí agrega cada indicador. El stock bajo
// es el estado actual del inventario y no depende de los filtros.
final biReportProvider = Provider.autoDispose.family<BiReport, ReportFilters>((
  ref,
  filters,
) {
  final reports = ref.watch(reportServiceProvider);
  final bi = ref.watch(biServiceProvider);
  final products = ref.watch(productProvider).products;
  final categories = ref.watch(categoryProvider).categories;
  final materials = ref.watch(materialProvider).materials;
  final units = ref.watch(unitProvider).units;
  final itemsByPurchase = ref.watch(purchaseItemsMapProvider).valueOrNull ?? {};

  final rows = ref.watch(saleReportRowsProvider(filters));
  final purchases = ref.watch(filteredPurchasesProvider(filters));

  return BiReport(
    summary: bi.summarize(
      sales: reports.summarizeSaleRows(rows),
      purchases: reports.summarizePurchases(purchases),
    ),
    salesByProduct: bi.salesByProduct(rows: rows, products: products),
    salesByCategory: bi.salesByCategory(rows: rows),
    purchasesByMaterial: bi.purchasesByMaterial(
      purchases: purchases,
      itemsByPurchase: itemsByPurchase,
      materials: materials,
      units: units,
    ),
    salesByPriceType: bi.salesByPriceType(rows: rows),
    timeSeries: bi.timeSeries(
      rows: rows,
      purchases: purchases,
      filters: filters,
    ),
    salesByEvent: bi.salesByEvent(rows: rows),
    lowStock: bi.lowStock(products: products, categories: categories),
  );
});
