import 'purchase_item_model.dart';
import 'sale_item_model.dart';
import 'sale_model.dart';
import 'purchase_model.dart';

// Resumen agregado de ventas para el módulo de reportes
class SalesSummary {
  final int count;
  final double totalAmount;
  final double totalDiscount;

  const SalesSummary({
    required this.count,
    required this.totalAmount,
    required this.totalDiscount,
  });
}

// Resumen agregado de compras para el módulo de reportes
class PurchasesSummary {
  final int count;
  final double totalAmount;
  final int materialCount;

  const PurchasesSummary({
    required this.count,
    required this.totalAmount,
    required this.materialCount,
  });
}

// Línea (ítem) de una venta dentro de un reporte, con su categoría y la parte
// del descuento de la venta que le corresponde. Los reportes de ventas
// filtran y totalizan por línea, no por venta completa.
class SaleLineReport {
  final SaleItemModel item;
  final int? categoryId;
  final String categoryName;

  // Parte del descuento global de la venta asignada a esta línea (prorrateo
  // proporcional a su subtotal).
  final double discountShare;

  const SaleLineReport({
    required this.item,
    required this.categoryId,
    required this.categoryName,
    this.discountShare = 0,
  });

  double get subtotal => item.subtotal;

  // Monto neto de la línea: su subtotal menos su parte del descuento.
  double get netAmount => item.subtotal - discountShare;
}

// Venta enriquecida con los nombres de sus entidades relacionadas.
//
// [lines] son las líneas de la venta que cumplen los filtros de
// producto/categoría/tipo de precio; los montos de la fila (subtotal,
// descuento y neto) se calculan solo con esas líneas. Si [lines] es null se
// considera la venta completa (sin filtrado por línea).
class SaleReportRow {
  final SaleModel sale;
  final String clientName;
  final String? locationName;
  final String? eventName;
  final List<SaleLineReport>? lines;

  const SaleReportRow({
    required this.sale,
    required this.clientName,
    this.locationName,
    this.eventName,
    this.lines,
  });

  double get subtotalAmount =>
      lines?.fold<double>(0, (sum, l) => sum + l.subtotal) ?? sale.totalAmount;

  double get discountAmount =>
      lines?.fold<double>(0, (sum, l) => sum + l.discountShare) ??
      sale.discount;

  double get netAmount =>
      lines?.fold<double>(0, (sum, l) => sum + l.netAmount) ??
      sale.finalAmount;
}

// Compra enriquecida con los nombres de sus entidades relacionadas.
//
// [items] son las líneas de material de la compra (vacío para un gasto
// general, que no tiene ítems).
class PurchaseReportRow {
  final PurchaseModel purchase;
  final String supplierName;
  final String? locationName;
  final String? eventName;
  final List<PurchaseItemModel> items;

  const PurchaseReportRow({
    required this.purchase,
    required this.supplierName,
    this.locationName,
    this.eventName,
    this.items = const [],
  });
}
