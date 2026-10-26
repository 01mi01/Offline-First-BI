import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';

void main() {
  group('selling', () {
    late AppDatabase db;
    late SaleRepository repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = SaleRepository(db);
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Producto 1',
          priceA: 10,
          priceB: 10,
          stock: const Value(10),
        ),
      );
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Producto 2',
          priceA: 5,
          priceB: 5,
          stock: const Value(5),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('createSale deducts stock for every item sold', () async {
      await repository.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 3 * 10 + 2 * 5,
        discount: 0,
        finalAmount: 3 * 10 + 2 * 5,
        date: DateTime(2024, 1, 1),
        items: [
          {'productId': 1, 'quantity': 3, 'unitPrice': 10.0},
          {'productId': 2, 'quantity': 2, 'unitPrice': 5.0},
        ],
      );

      final p1 = await (db.select(db.products)..where((p) => p.id.equals(1))).getSingle();
      final p2 = await (db.select(db.products)..where((p) => p.id.equals(2))).getSingle();

      expect(p1.stock, 7);
      expect(p2.stock, 3);

      final sales = await repository.getAll();
      expect(sales, hasLength(1));
      expect(sales.first.finalAmount, 40);

      final items = await repository.getItemsForSale(sales.first.id);
      expect(items, hasLength(2));
    });
  });

  group('canceling a sale', () {
    late AppDatabase db;
    late SaleRepository repository;

    Future<int> stockOf(int productId) async => (await (db.select(
      db.products,
    )..where((p) => p.id.equals(productId))).getSingle()).stock;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = SaleRepository(db);
      for (final entry in {'Producto 1': 5, 'Producto 2': 4}.entries) {
        await db.into(db.products).insert(
          ProductsCompanion.insert(
            categoryId: 1,
            name: entry.key,
            priceA: 10,
            priceB: 10,
            stock: Value(entry.value),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'cancelSale gives the sold units back to the stock, marks the sale as '
      'canceled and keeps it (and its items) as history',
      () async {
        await repository.createSale(
          clientId: null,
          locationId: null,
          eventId: null,
          totalAmount: 3 * 10.0 + 2 * 10.0,
          discount: 5,
          finalAmount: 45,
          date: DateTime(2024, 1, 1),
          items: [
            {'productId': 1, 'quantity': 3, 'unitPrice': 10.0},
            {'productId': 2, 'quantity': 2, 'unitPrice': 10.0},
          ],
        );
        final sale = (await repository.getAll()).single;
        expect(sale.isCanceled, isFalse);
        expect(sale.canceledAt, isNull);
        expect(await stockOf(1), 2);
        expect(await stockOf(2), 2);

        final error = await repository.cancelSale(sale.id);

        expect(error, isNull);
        expect(await stockOf(1), 5);
        expect(await stockOf(2), 4);

        final all = await repository.getAll();
        expect(all, hasLength(1));
        expect(all.single.isCanceled, isTrue);
        expect(all.single.canceledAt, isNotNull);
        expect(all.single.finalAmount, 45);
        expect(all.single.discount, 5);
        expect(await repository.getItemsForSale(sale.id), hasLength(2));
      },
    );
  });

  group('money precision', () {
    late AppDatabase db;
    late SaleRepository sales;
    late int productId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      sales = SaleRepository(db);
      productId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Anillo',
          priceA: 33.33,
          priceB: 1,
          stock: const Value(10),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('a sale is stored with every amount on cents', () async {
      await sales.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 99.99000000000001,
        discount: 0.1 + 0.2,
        finalAmount: 99.99000000000001 - (0.1 + 0.2),
        date: DateTime(2024, 1, 1),
        items: [
          {'productId': productId, 'quantity': 3, 'unitPrice': 33.33},
        ],
      );
      final sale = (await sales.getAll()).single;
      expect(sale.totalAmount, 99.99);
      expect(sale.discount, 0.3);
      expect(sale.finalAmount, 99.69);
      final item = await db.select(db.saleItems).getSingle();
      expect(item.subtotal, 99.99);
    });
  });
}
