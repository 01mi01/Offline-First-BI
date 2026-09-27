import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/models/product_model.dart';

ProductModel _product({
  required int id,
  double salePrice = 10,
  int stock = 100,
}) {
  return ProductModel(
    id: id,
    name: 'Producto $id',
    salePrice: salePrice,
    stock: stock,
    isActive: true,
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  group('SaleRepository pure calculations (no database needed)', () {
    late AppDatabase db;
    late SaleRepository repository;

    setUpAll(() {
      // calculateSubtotal/calculateTotal/validateDiscount never touch the
      // database, but the repository still requires an instance to build.
      // A single shared instance is fine since these tests mutate nothing.
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = SaleRepository(db);
    });

    tearDownAll(() async {
      await db.close();
    });

    test('calculateSubtotal sums price * quantity for each cart item', () {
      final products = [_product(id: 1, salePrice: 10), _product(id: 2, salePrice: 5)];
      final cart = {1: 3, 2: 2}; // 3*10 + 2*5 = 40

      expect(repository.calculateSubtotal(products, cart), 40);
    });

    test('calculateSubtotal ignores cart entries with no matching product', () {
      final products = [_product(id: 1, salePrice: 10)];
      final cart = {1: 2, 99: 5}; // product 99 does not exist

      expect(repository.calculateSubtotal(products, cart), 20);
    });

    test('calculateSubtotal returns 0 for an empty cart', () {
      expect(repository.calculateSubtotal([_product(id: 1)], {}), 0);
    });

    test('calculateTotal subtracts the discount from the subtotal', () {
      expect(repository.calculateTotal(100, 20), 80);
    });

    test('calculateTotal with zero discount returns the subtotal unchanged', () {
      expect(repository.calculateTotal(100, 0), 100);
    });

    test('calculateTotal clamps to 0 when discount exceeds subtotal', () {
      expect(repository.calculateTotal(50, 80), 0);
    });

    test('validateDiscount allows a discount equal to the subtotal', () {
      expect(repository.validateDiscount(100, 100), isNull);
    });

    test('validateDiscount allows a discount smaller than the subtotal', () {
      expect(repository.validateDiscount(30, 100), isNull);
    });

    test('validateDiscount rejects a discount greater than the subtotal', () {
      expect(
        repository.validateDiscount(150, 100),
        'El descuento no puede ser mayor al subtotal',
      );
    });

    test('validateDiscount allows a zero discount', () {
      expect(repository.validateDiscount(0, 100), isNull);
    });
  });

  group('SaleRepository stock updates (in-memory database)', () {
    late AppDatabase db;
    late SaleRepository repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = SaleRepository(db);
      // Dos productos con stock inicial conocido
      await db.into(db.products).insert(
        ProductsCompanion.insert(name: 'Producto 1', salePrice: 10, stock: const Value(10)),
      );
      await db.into(db.products).insert(
        ProductsCompanion.insert(name: 'Producto 2', salePrice: 5, stock: const Value(5)),
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

      expect(p1.stock, 7); // 10 - 3
      expect(p2.stock, 3); // 5 - 2

      final sales = await repository.getAll();
      expect(sales, hasLength(1));
      expect(sales.first.finalAmount, 40);

      final items = await repository.getItemsForSale(sales.first.id);
      expect(items, hasLength(2));
    });

    test('createSale clamps stock at 0 instead of going negative', () async {
      // Producto 2 solo tiene 5 unidades; vendemos 8
      await repository.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 8 * 5,
        discount: 0,
        finalAmount: 8 * 5,
        date: DateTime(2024, 1, 1),
        items: [
          {'productId': 2, 'quantity': 8, 'unitPrice': 5.0},
        ],
      );

      final p2 = await (db.select(db.products)..where((p) => p.id.equals(2))).getSingle();
      expect(p2.stock, 0);
    });

    test('editSale restores stock from the old items before applying the new ones', () async {
      await repository.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 3 * 10,
        discount: 0,
        finalAmount: 3 * 10,
        date: DateTime(2024, 1, 1),
        items: [
          {'productId': 1, 'quantity': 3, 'unitPrice': 10.0},
        ],
      );
      final sale = (await repository.getAll()).first;
      // Producto 1: 10 - 3 = 7 tras la creación

      await repository.editSale(
        saleId: sale.id,
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 5 * 10,
        discount: 0,
        finalAmount: 5 * 10,
        date: sale.date,
        newItems: [
          {'productId': 1, 'quantity': 5, 'unitPrice': 10.0},
        ],
      );

      final p1 = await (db.select(db.products)..where((p) => p.id.equals(1))).getSingle();
      // 7 (post-create) + 3 (restored) - 5 (new quantity) = 5, i.e. 10 - 5
      expect(p1.stock, 5);

      final items = await repository.getItemsForSale(sale.id);
      expect(items, hasLength(1));
      expect(items.first.quantity, 5);
    });

    test(
      'editSale clamps stock at 0 (same as createSale) when the new '
      'quantity exceeds what is available',
      () async {
        await repository.createSale(
          clientId: null,
          locationId: null,
          eventId: null,
          totalAmount: 2 * 5,
          discount: 0,
          finalAmount: 2 * 5,
          date: DateTime(2024, 1, 1),
          items: [
            {'productId': 2, 'quantity': 2, 'unitPrice': 5.0},
          ],
        );
        final sale = (await repository.getAll()).first;
        // Producto 2: 5 - 2 = 3 tras la creación

        await repository.editSale(
          saleId: sale.id,
          clientId: null,
          locationId: null,
          eventId: null,
          totalAmount: 20 * 5,
          discount: 0,
          finalAmount: 20 * 5,
          date: sale.date,
          newItems: [
            // Muy por encima del stock disponible (3 + 2 restaurado = 5)
            {'productId': 2, 'quantity': 20, 'unitPrice': 5.0},
          ],
        );

        final p2 = await (db.select(db.products)..where((p) => p.id.equals(2))).getSingle();
        // 3 (post-create) + 2 (restored) - 20 (new quantity) = -15, clamped to 0
        expect(p2.stock, 0);
      },
    );
  });
}
