import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/report_service.dart';
import 'package:offline_first_bi/models/client_model.dart';
import 'package:offline_first_bi/models/event_model.dart';
import 'package:offline_first_bi/models/location_model.dart';
import 'package:offline_first_bi/models/product_model.dart';
import 'package:offline_first_bi/models/purchase_item_model.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/models/sale_item_model.dart';
import 'package:offline_first_bi/models/sale_model.dart';
import 'package:offline_first_bi/models/supplier_model.dart';

SaleModel _sale({
  required int id,
  int? clientId,
  int? locationId,
  int? eventId,
  required DateTime date,
  double totalAmount = 100,
  double discount = 0,
  double? finalAmount,
}) {
  return SaleModel(
    id: id,
    clientId: clientId,
    locationId: locationId,
    eventId: eventId,
    totalAmount: totalAmount,
    discount: discount,
    finalAmount: finalAmount ?? (totalAmount - discount),
    date: date,
    createdAt: date,
  );
}

PurchaseModel _purchase({
  required int id,
  int? supplierId,
  int? locationId,
  int? eventId,
  bool isMaterial = true,
  required DateTime date,
  double totalAmount = 50,
}) {
  return PurchaseModel(
    id: id,
    supplierId: supplierId,
    locationId: locationId,
    eventId: eventId,
    isMaterial: isMaterial,
    totalAmount: totalAmount,
    date: date,
    createdAt: date,
  );
}

SaleItemModel _item({
  required int saleId,
  required int productId,
  int quantity = 1,
  String priceType = 'A',
}) {
  return SaleItemModel(
    id: saleId * 10 + productId,
    saleId: saleId,
    productId: productId,
    productName: 'Producto $productId',
    quantity: quantity,
    unitPrice: 10,
    priceType: priceType,
    subtotal: 10.0 * quantity,
  );
}

ProductModel _product({required int id, int categoryId = 1}) {
  return ProductModel(
    id: id,
    categoryId: categoryId,
    name: 'Producto $id',
    priceA: 10,
    priceB: 10,
    stock: 100,
    isActive: true,
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  final service = ReportService();

  group('filterSales and canceled sales', () {
    test('a canceled sale is left out of reports (it is no longer income)', () {
      final active = _sale(id: 1, date: DateTime(2024, 1, 5));
      final canceled = SaleModel(
        id: 2,
        totalAmount: 100,
        discount: 0,
        finalAmount: 100,
        date: DateTime(2024, 1, 6),
        createdAt: DateTime(2024, 1, 6),
        isCanceled: true,
        canceledAt: DateTime(2024, 1, 7),
      );

      final result = service.filterSales(
        sales: [active, canceled],
        products: const [],
        saleItemsMap: const {},
        filters: const ReportFilters(),
      );

      expect(result.map((s) => s.id), [1]);
    });
  });

  group('filterSales', () {
    final s1 = _sale(
      id: 1,
      clientId: 1,
      locationId: 10,
      eventId: 100,
      date: DateTime(2024, 1, 5),
    );
    final s2 = _sale(
      id: 2,
      clientId: 2,
      locationId: 20,
      eventId: 200,
      date: DateTime(2024, 2, 10),
    );
    final s3 = _sale(
      id: 3,
      clientId: 1,
      locationId: 10,
      eventId: 100,
      date: DateTime(2024, 3, 15),
    );
    final sales = [s1, s2, s3];

    final products = [
      _product(id: 1, categoryId: 1),
      _product(id: 2, categoryId: 2),
    ];

    final saleItemsMap = {
      1: [_item(saleId: 1, productId: 1)],
      2: [_item(saleId: 2, productId: 2)],
      3: [_item(saleId: 3, productId: 1), _item(saleId: 3, productId: 2)],
    };

    List<SaleModel> filter(ReportFilters filters) => service.filterSales(
      sales: sales,
      products: products,
      saleItemsMap: saleItemsMap,
      filters: filters,
    );

    test('no filters returns all sales', () {
      expect(filter(const ReportFilters()), [s1, s2, s3]);
    });

    test('filters by date range', () {
      final result = filter(
        ReportFilters(
          startDate: DateTime(2024, 2, 1),
          endDate: DateTime(2024, 2, 28),
        ),
      );
      expect(result, [s2]);
    });

    test('date range is inclusive of the end date (whole day)', () {
      final result = filter(
        ReportFilters(
          startDate: DateTime(2024, 3, 15),
          endDate: DateTime(2024, 3, 15),
        ),
      );
      expect(result, [s3]);
    });

    test('filters by client', () {
      expect(filter(const ReportFilters(clientId: 1)), [s1, s3]);
    });

    test('filters by location', () {
      expect(filter(const ReportFilters(locationId: 20)), [s2]);
    });

    test('filters by event', () {
      expect(filter(const ReportFilters(eventId: 100)), [s1, s3]);
    });

    test('filters by product', () {
      // product 2 appears in s2 and s3
      expect(filter(const ReportFilters(productId: 2)), [s2, s3]);
    });

    test('filters by category (via product -> category mapping)', () {
      // category 2 belongs to product 2, which appears in s2 and s3
      expect(filter(const ReportFilters(categoryId: 2)), [s2, s3]);
    });

    test('combines date range and product filters', () {
      final result = filter(
        ReportFilters(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 3, 1),
          productId: 1,
        ),
      );
      // Only s1 is both in range and has product 1 (s3 is out of the Jan-Mar 1 range)
      expect(result, [s1]);
    });

    test('combines client and event filters', () {
      final result = filter(
        const ReportFilters(clientId: 1, eventId: 100),
      );
      expect(result, [s1, s3]);
    });

    test('a sale with no items does not match a product filter', () {
      final result = service.filterSales(
        sales: sales,
        products: products,
        saleItemsMap: const {},
        filters: const ReportFilters(productId: 1),
      );
      expect(result, isEmpty);
    });

    // Full combination matrix for the four report filters (date, product,
    // event, location). Fixture recap:
    //   s1: 2024-01-05, locationId 10, eventId 100, product 1
    //   s2: 2024-02-10, locationId 20, eventId 200, product 2
    //   s3: 2024-03-15, locationId 10, eventId 100, products 1 and 2
    group('two-filter combinations', () {
      test('date + event', () {
        final result = filter(
          ReportFilters(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 12, 31),
            eventId: 100,
          ),
        );
        expect(result, [s1, s3]);
      });

      test('date + location', () {
        final result = filter(
          ReportFilters(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 12, 31),
            locationId: 20,
          ),
        );
        expect(result, [s2]);
      });

      test('product + event', () {
        // product 2 -> {s2, s3}; event 100 -> {s1, s3}; intersection -> {s3}
        expect(
          filter(const ReportFilters(productId: 2, eventId: 100)),
          [s3],
        );
      });

      test('product + location', () {
        // product 2 -> {s2, s3}; location 10 -> {s1, s3}; intersection -> {s3}
        expect(
          filter(const ReportFilters(productId: 2, locationId: 10)),
          [s3],
        );
      });

      test('event + location (non-empty result)', () {
        expect(
          filter(const ReportFilters(eventId: 100, locationId: 10)),
          [s1, s3],
        );
      });

      test('event + location (zero matching records)', () {
        // event 100 -> {s1, s3}; location 20 -> {s2}; no overlap
        expect(
          filter(const ReportFilters(eventId: 100, locationId: 20)),
          isEmpty,
        );
      });
    });

    group('three-filter combinations', () {
      test('date + product + event', () {
        final result = filter(
          ReportFilters(
            startDate: DateTime(2024, 3, 1),
            endDate: DateTime(2024, 3, 31),
            productId: 1,
            eventId: 100,
          ),
        );
        expect(result, [s3]);
      });

      test('date + product + location', () {
        final result = filter(
          ReportFilters(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 2, 28),
            productId: 1,
            locationId: 10,
          ),
        );
        expect(result, [s1]);
      });

      test('date + event + location', () {
        final result = filter(
          ReportFilters(
            startDate: DateTime(2024, 3, 1),
            endDate: DateTime(2024, 3, 31),
            eventId: 100,
            locationId: 10,
          ),
        );
        expect(result, [s3]);
      });

      test('product + event + location', () {
        final result = filter(
          const ReportFilters(productId: 2, eventId: 100, locationId: 10),
        );
        expect(result, [s3]);
      });
    });

    group('all four filters combined', () {
      test('date + product + event + location (non-empty result)', () {
        final result = filter(
          ReportFilters(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 1, 31),
            productId: 1,
            eventId: 100,
            locationId: 10,
          ),
        );
        expect(result, [s1]);
      });

      test('date + product + event + location (zero matching records)', () {
        // product 1 -> {s1, s3}; event 200 -> {s2}; no overlap regardless
        // of date range or location.
        final result = filter(
          ReportFilters(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 12, 31),
            productId: 1,
            eventId: 200,
            locationId: 20,
          ),
        );
        expect(result, isEmpty);
      });
    });

    group('single-filter edge cases with zero matching records', () {
      test('date range with no sales in it', () {
        final result = filter(
          ReportFilters(
            startDate: DateTime(2025, 1, 1),
            endDate: DateTime(2025, 1, 2),
          ),
        );
        expect(result, isEmpty);
      });

      test('product that does not exist in any sale', () {
        expect(filter(const ReportFilters(productId: 999)), isEmpty);
      });

      test('event that does not exist in any sale', () {
        expect(filter(const ReportFilters(eventId: 999)), isEmpty);
      });

      test('location that does not exist in any sale', () {
        expect(filter(const ReportFilters(locationId: 999)), isEmpty);
      });
    });
  });

  group('filterPurchases', () {
    final p1 = _purchase(
      id: 1,
      supplierId: 1,
      locationId: 10,
      eventId: 100,
      date: DateTime(2024, 1, 5),
    );
    final p2 = _purchase(
      id: 2,
      supplierId: 2,
      locationId: 20,
      eventId: 200,
      date: DateTime(2024, 2, 10),
      isMaterial: false,
    );
    final purchases = [p1, p2];

    test('no filters returns all purchases', () {
      expect(
        service.filterPurchases(
          purchases: purchases,
          filters: const ReportFilters(),
        ),
        [p1, p2],
      );
    });

    test('filters by date range', () {
      final result = service.filterPurchases(
        purchases: purchases,
        filters: ReportFilters(
          startDate: DateTime(2024, 2, 1),
          endDate: DateTime(2024, 2, 28),
        ),
      );
      expect(result, [p2]);
    });

    test('filters by supplier', () {
      expect(
        service.filterPurchases(
          purchases: purchases,
          filters: const ReportFilters(supplierId: 1),
        ),
        [p1],
      );
    });

    test('filters by location', () {
      expect(
        service.filterPurchases(
          purchases: purchases,
          filters: const ReportFilters(locationId: 20),
        ),
        [p2],
      );
    });

    test('filters by event', () {
      expect(
        service.filterPurchases(
          purchases: purchases,
          filters: const ReportFilters(eventId: 100),
        ),
        [p1],
      );
    });
  });

  group('summarizeSaleRows (whole sales, no line filtering)', () {
    test('aggregates count, total amount and discount', () {
      final sales = [
        _sale(
          id: 1,
          date: DateTime(2024, 1, 1),
          totalAmount: 100,
          discount: 10,
          finalAmount: 90,
        ),
        _sale(
          id: 2,
          date: DateTime(2024, 1, 2),
          totalAmount: 50,
          discount: 0,
          finalAmount: 50,
        ),
      ];

      final summary = service.summarizeSaleRows(
        service.buildSaleRows(
          sales: sales,
          clients: const [],
          locations: const [],
          events: const [],
        ),
      );

      expect(summary.count, 2);
      expect(summary.totalAmount, 140); // 90 + 50
      expect(summary.totalDiscount, 10);
    });

    test('empty list summarizes to zero', () {
      final summary = service.summarizeSaleRows(const []);
      expect(summary.count, 0);
      expect(summary.totalAmount, 0);
      expect(summary.totalDiscount, 0);
    });
  });

  group('summarizePurchases', () {
    test('aggregates count, total amount and material count', () {
      final purchases = [
        _purchase(id: 1, date: DateTime(2024, 1, 1), totalAmount: 100),
        _purchase(
          id: 2,
          date: DateTime(2024, 1, 2),
          totalAmount: 30,
          isMaterial: false,
        ),
      ];

      final summary = service.summarizePurchases(purchases);

      expect(summary.count, 2);
      expect(summary.totalAmount, 130);
      expect(summary.materialCount, 1);
    });
  });

  group('buildSaleRows', () {
    test('enriches sales with client, location and event names', () {
      final sale = _sale(
        id: 1,
        clientId: 1,
        locationId: 10,
        eventId: 100,
        date: DateTime(2024, 1, 1),
      );
      final clients = [
        ClientModel(
          id: 1,
          name: 'John Smith',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];
      final locations = [
        LocationModel(
          id: 10,
          city: 'La Paz - Calacoto',
          country: 'Bolivia',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];
      final events = [
        EventModel(
          id: 100,
          name: 'Feria de Arte',
          startDate: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      final rows = service.buildSaleRows(
        sales: [sale],
        clients: clients,
        locations: locations,
        events: events,
      );

      expect(rows, hasLength(1));
      expect(rows.first.clientName, 'John Smith');
      expect(rows.first.locationName, 'La Paz - Calacoto, Bolivia');
      expect(rows.first.eventName, 'Feria de Arte');
    });

    test('falls back to "Sin nombre" and null when relations are missing', () {
      final sale = _sale(id: 1, date: DateTime(2024, 1, 1));

      final rows = service.buildSaleRows(
        sales: [sale],
        clients: const [],
        locations: const [],
        events: const [],
      );

      expect(rows.first.clientName, 'Sin nombre');
      expect(rows.first.locationName, isNull);
      expect(rows.first.eventName, isNull);
    });
  });

  group('buildPurchaseRows', () {
    test('enriches purchases with supplier, location and event names', () {
      final purchase = _purchase(
        id: 1,
        supplierId: 1,
        locationId: 10,
        eventId: 100,
        date: DateTime(2024, 1, 1),
      );
      final suppliers = [
        SupplierModel(
          id: 1,
          name: 'Lino & Co.',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];
      final locations = [
        LocationModel(
          id: 10,
          city: 'Santa Cruz - Equipetrol',
          country: 'Bolivia',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];
      final events = [
        EventModel(
          id: 100,
          name: 'Exposición de Arte',
          startDate: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      final rows = service.buildPurchaseRows(
        purchases: [purchase],
        suppliers: suppliers,
        locations: locations,
        events: events,
      );

      expect(rows, hasLength(1));
      expect(rows.first.supplierName, 'Lino & Co.');
      expect(rows.first.locationName, 'Santa Cruz - Equipetrol, Bolivia');
      expect(rows.first.eventName, 'Exposición de Arte');
      expect(rows.first.items, isEmpty);
    });

    test('attaches each purchase its own material lines (none for a general expense)', () {
      final material = _purchase(id: 1, date: DateTime(2024, 1, 1));
      final expense = _purchase(id: 2, date: DateTime(2024, 1, 2));
      final otherPurchaseItem = PurchaseItemModel(
        id: 9,
        purchaseId: 3,
        materialId: 1,
        materialName: 'Tela para estuches',
        quantity: 1,
        unitPrice: 1,
        subtotal: 1,
      );
      final item = PurchaseItemModel(
        id: 1,
        purchaseId: 1,
        materialId: 1,
        materialName: 'Tela beige',
        quantity: 2,
        unitPrice: 3.5,
        subtotal: 7,
      );

      final rows = service.buildPurchaseRows(
        purchases: [material, expense],
        suppliers: const [],
        locations: const [],
        events: const [],
        itemsByPurchase: {
          1: [item],
          3: [otherPurchaseItem],
        },
      );

      expect(rows[0].items, [item]);
      expect(rows[1].items, isEmpty);
    });
  });
}
