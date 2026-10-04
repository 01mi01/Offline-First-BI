import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/models/product_model.dart';
import 'package:offline_first_bi/models/sale_model.dart';

ProductModel _product({
  required int id,
  double price = 10,
  double? priceB,
  int stock = 100,
}) {
  return ProductModel(
    id: id,
    categoryId: 1,
    name: 'Producto $id',
    priceA: price,
    priceB: priceB ?? price,
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
      final products = [_product(id: 1, price: 10), _product(id: 2, price: 5)];
      final cart = {1: 3, 2: 2}; // 3*10 + 2*5 = 40

      expect(repository.calculateSubtotal(products, cart), 40);
    });

    test('calculateSubtotal ignores cart entries with no matching product', () {
      final products = [_product(id: 1, price: 10)];
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

  group('SaleRepository price bands A vs B with DISTINCT prices', () {
    late AppDatabase db;
    late SaleRepository repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = SaleRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    final estuches = _product(id: 1, price: 55, priceB: 40);
    final pinesGrandes = _product(id: 2, price: 8, priceB: 6.5);

    test('calculateSubtotal charges Precio A when the band is A (or unspecified)', () {
      expect(repository.calculateSubtotal([estuches], {1: 2}), 110);
      expect(
        repository.calculateSubtotal([estuches], {1: 2}, priceTypes: {1: 'A'}),
        110,
      );
    });

    test('calculateSubtotal charges Precio B when the band is B', () {
      expect(
        repository.calculateSubtotal([estuches], {1: 2}, priceTypes: {1: 'B'}),
        80,
      );
    });

    test('calculateSubtotal mixes bands per item: one at A and another at B', () {
      final subtotal = repository.calculateSubtotal(
        [estuches, pinesGrandes],
        {1: 2, 2: 3},
        priceTypes: {1: 'A', 2: 'B'},
      );
      expect(subtotal, 2 * 55 + 3 * 6.5); // 129.5
    });

    test('calculateSubtotal: bands are independent per product', () {
      final subtotal = repository.calculateSubtotal(
        [estuches, pinesGrandes],
        {1: 1, 2: 1},
        priceTypes: {1: 'B'}, // pinesGrandes sin banda -> A
      );
      expect(subtotal, 40 + 8);
    });

    test('createSale persists the distinct unit price and band of each line', () async {
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Estuches',
          priceA: 55,
          priceB: 40,
          stock: const Value(10),
        ),
      );
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Pines grandes',
          priceA: 8,
          priceB: 6.5,
          stock: const Value(20),
        ),
      );

      await repository.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 2 * 55 + 3 * 6.5,
        discount: 0,
        finalAmount: 2 * 55 + 3 * 6.5,
        date: DateTime(2024, 1, 1),
        items: [
          {'productId': 1, 'quantity': 2, 'unitPrice': 55.0, 'priceType': 'A'},
          {'productId': 2, 'quantity': 3, 'unitPrice': 6.5, 'priceType': 'B'},
        ],
      );

      final sale = (await repository.getAll()).single;
      expect(sale.finalAmount, 129.5);

      final items = await repository.getItemsForSale(sale.id);
      final byName = {for (final i in items) i.productName: i};
      expect(byName['Estuches']!.priceType, 'A');
      expect(byName['Estuches']!.unitPrice, 55);
      expect(byName['Estuches']!.subtotal, 110);
      expect(byName['Pines grandes']!.priceType, 'B');
      expect(byName['Pines grandes']!.unitPrice, 6.5);
      expect(byName['Pines grandes']!.subtotal, 19.5);
    });
  });

  group('SaleRepository: stock offered while editing, and canceling', () {
    late AppDatabase db;
    late SaleRepository repository;

    Future<int> stockOf(int productId) async => (await (db.select(
      db.products,
    )..where((p) => p.id.equals(productId))).getSingle()).stock;

    Future<SaleModel> createSaleOf(int productId, int quantity) async {
      await repository.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: quantity * 10.0,
        discount: 0,
        finalAmount: quantity * 10.0,
        date: DateTime(2024, 1, 1),
        items: [
          {'productId': productId, 'quantity': quantity, 'unitPrice': 10.0},
        ],
      );
      return (await repository.getAll()).first;
    }

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = SaleRepository(db);
      // Producto 1 con 5 en stock; producto 2 con 4.
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
      'while editing, the stock offered is the current stock PLUS what the '
      'sale itself already holds (3 in stock + 2 in the sale = 5, not 3)',
      () async {
        final sale = await createSaleOf(1, 2); // stock 5 -> 3
        expect(await stockOf(1), 3);

        final reserved = await repository.getReservedQuantities(sale.id);
        expect(reserved, {1: 2});

        expect(
          repository.availableStock(
            currentStock: 3,
            reservedByThisSale: reserved[1] ?? 0,
          ),
          5,
        );
        // Una venta nueva no tiene nada apartado: solo el stock actual.
        expect(repository.availableStock(currentStock: 3), 3);
        // Un producto que la venta no incluye tampoco suma nada.
        expect(
          repository.availableStock(
            currentStock: 4,
            reservedByThisSale: reserved[2] ?? 0,
          ),
          4,
        );
      },
    );

    test(
      'editing up to that offered maximum works: the net difference leaves '
      'the stock at exactly 0, never negative',
      () async {
        final sale = await createSaleOf(1, 2); // stock 3
        final available = repository.availableStock(
          currentStock: await stockOf(1),
          reservedByThisSale:
              (await repository.getReservedQuantities(sale.id))[1] ?? 0,
        );
        expect(available, 5);

        final error = await repository.editSale(
          saleId: sale.id,
          clientId: null,
          locationId: null,
          eventId: null,
          totalAmount: available * 10.0,
          discount: 0,
          finalAmount: available * 10.0,
          date: sale.date,
          newItems: [
            {'productId': 1, 'quantity': available, 'unitPrice': 10.0},
          ],
        );

        expect(error, isNull);
        expect(await stockOf(1), 0); // 3 + 2 devueltos - 5 nuevos
        final items = await repository.getItemsForSale(sale.id);
        expect(items.single.quantity, 5);
      },
    );

    test('editing down returns the difference to the stock', () async {
      final sale = await createSaleOf(1, 4); // stock 1
      await repository.editSale(
        saleId: sale.id,
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 10,
        discount: 0,
        finalAmount: 10,
        date: sale.date,
        newItems: [
          {'productId': 1, 'quantity': 1, 'unitPrice': 10.0},
        ],
      );
      expect(await stockOf(1), 4); // 5 - 1
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
        expect(await stockOf(1), 2); // 5 - 3
        expect(await stockOf(2), 2); // 4 - 2

        final error = await repository.cancelSale(sale.id);

        expect(error, isNull);
        expect(await stockOf(1), 5);
        expect(await stockOf(2), 4);

        // La venta sigue en la lista, marcada como cancelada y con sus montos.
        final all = await repository.getAll();
        expect(all, hasLength(1));
        expect(all.single.isCanceled, isTrue);
        expect(all.single.canceledAt, isNotNull);
        expect(all.single.finalAmount, 45);
        expect(all.single.discount, 5);
        // Y conserva sus ítems para la auditoría.
        expect(await repository.getItemsForSale(sale.id), hasLength(2));
      },
    );

    test('canceling twice is rejected and does not return the stock twice', () async {
      final sale = await createSaleOf(1, 2);
      expect(await repository.cancelSale(sale.id), isNull);
      expect(await stockOf(1), 5);

      final second = await repository.cancelSale(sale.id);

      expect(second, 'La venta ya está cancelada');
      expect(await stockOf(1), 5); // no 7
    });

    test('a canceled sale can no longer be edited, and the stock is untouched', () async {
      final sale = await createSaleOf(1, 2);
      await repository.cancelSale(sale.id);
      expect(await stockOf(1), 5);

      final error = await repository.editSale(
        saleId: sale.id,
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 30,
        discount: 0,
        finalAmount: 30,
        date: sale.date,
        newItems: [
          {'productId': 1, 'quantity': 3, 'unitPrice': 10.0},
        ],
      );

      expect(error, 'La venta está cancelada y no se puede editar');
      expect(await stockOf(1), 5);
      final items = await repository.getItemsForSale(sale.id);
      expect(items.single.quantity, 2); // los ítems originales siguen igual
    });

    test('canceling a sale that does not exist reports it', () async {
      expect(await repository.cancelSale(999), 'Venta no encontrada');
    });
  });
}
