import '../config/rounding.dart';
import 'purchase_item_model.dart';
import 'sale_item_model.dart';
import 'sale_model.dart';
import 'purchase_model.dart';

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

class SaleLineReport {
  final SaleItemModel item;
  final int? categoryId;
  final String categoryName;

  final double discountShare;

  const SaleLineReport({
    required this.item,
    required this.categoryId,
    required this.categoryName,
    this.discountShare = 0,
  });

  double get subtotal => item.subtotal;

  double get netAmount => round2(item.subtotal - discountShare);
}

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

  double get subtotalAmount => round2(
    lines?.fold<double>(0, (sum, l) => sum + l.subtotal) ?? sale.totalAmount,
  );

  double get discountAmount => round2(
    lines?.fold<double>(0, (sum, l) => sum + l.discountShare) ?? sale.discount,
  );

  double get netAmount => round2(
    lines?.fold<double>(0, (sum, l) => sum + l.netAmount) ?? sale.finalAmount,
  );
}

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
