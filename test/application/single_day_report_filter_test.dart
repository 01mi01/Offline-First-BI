import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/report_service.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/models/sale_model.dart';

// Reportes: con solo "Desde" (sin "Hasta") se filtra ese único día.
void main() {
  final service = ReportService();

  SaleModel sale(int id, DateTime date) => SaleModel(
    id: id,
    clientId: null,
    locationId: null,
    eventId: null,
    totalAmount: 1,
    discount: 0,
    finalAmount: 1,
    date: date,
    createdAt: date,
  );

  PurchaseModel purchase(int id, DateTime date) => PurchaseModel(
    id: id,
    supplierId: null,
    locationId: null,
    eventId: null,
    isMaterial: false,
    totalAmount: 1,
    date: date,
    createdAt: date,
  );

  final day = DateTime(2026, 9, 10);
  final sales = [
    sale(1, DateTime(2026, 9, 9, 23, 59)),
    sale(2, DateTime(2026, 9, 10, 0, 0)),
    sale(3, DateTime(2026, 9, 10, 18, 30)),
    sale(4, DateTime(2026, 9, 11, 0, 0)),
  ];
  final purchases = [
    purchase(1, DateTime(2026, 9, 9, 23, 59)),
    purchase(2, DateTime(2026, 9, 10, 9, 15)),
    purchase(3, DateTime(2026, 9, 11, 0, 0)),
  ];

  List<int> salesFor(ReportFilters f) => service
      .filterSales(sales: sales, products: const [], saleItemsMap: const {}, filters: f)
      .map((s) => s.id)
      .toList();

  List<int> purchasesFor(ReportFilters f) =>
      service.filterPurchases(purchases: purchases, filters: f).map((p) => p.id).toList();

  test('only Desde shows just that day (sales)', () {
    expect(salesFor(ReportFilters(startDate: day)), [2, 3]);
  });

  test('only Desde shows just that day (purchases)', () {
    expect(purchasesFor(ReportFilters(startDate: day)), [2]);
  });

  test('with Hasta set the range is unchanged', () {
    expect(
      salesFor(ReportFilters(startDate: day, endDate: DateTime(2026, 9, 11))),
      [2, 3, 4],
    );
    expect(
      purchasesFor(ReportFilters(startDate: day, endDate: day)),
      [2],
    );
  });

  test('only Hasta keeps everything up to that day', () {
    expect(salesFor(ReportFilters(endDate: day)), [1, 2, 3]);
  });

  test('effectiveEndDate falls back to Desde', () {
    expect(ReportFilters(startDate: day).effectiveEndDate, day);
    expect(ReportFilters(startDate: day, endDate: DateTime(2026, 9, 12)).effectiveEndDate,
        DateTime(2026, 9, 12));
    expect(const ReportFilters().effectiveEndDate, isNull);
  });
}
