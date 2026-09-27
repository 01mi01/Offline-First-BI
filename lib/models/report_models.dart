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

// Venta enriquecida con los nombres de sus entidades relacionadas
class SaleReportRow {
  final SaleModel sale;
  final String clientName;
  final String? locationName;
  final String? eventName;

  const SaleReportRow({
    required this.sale,
    required this.clientName,
    this.locationName,
    this.eventName,
  });
}

// Compra enriquecida con los nombres de sus entidades relacionadas
class PurchaseReportRow {
  final PurchaseModel purchase;
  final String supplierName;
  final String? locationName;
  final String? eventName;

  const PurchaseReportRow({
    required this.purchase,
    required this.supplierName,
    this.locationName,
    this.eventName,
  });
}
