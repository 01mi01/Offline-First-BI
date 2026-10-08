import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/data/repositories/product_repository.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';

// Redondeo en el origen: lo que se guarda y lo que se compara ya va a dos
// decimales, sin ruido de coma flotante (72.6 - 15 = 57.599999999999994).
void main() {
  late AppDatabase db;
  late PurchaseRepository purchases;
  late MaterialRepository materials;
  late SaleRepository sales;
  late int metro;
  late int paquete;
  late int tela;
  late int paquetes;
  late int productId;

  Future<Material> material(int id) =>
      (db.select(db.materials)..where((m) => m.id.equals(id))).getSingle();

  Future<int> buy(int materialId, double quantity, double unitPrice) async {
    await purchases.createPurchase(
      supplierId: null,
      isMaterial: true,
      description: null,
      totalAmount: 0,
      date: DateTime(2024, 1, 1),
      locationId: null,
      eventId: null,
      items: [
        {'materialId': materialId, 'quantity': quantity, 'unitPrice': unitPrice},
      ],
    );
    return (await purchases.getAll()).map((p) => p.id).reduce((a, b) => a > b ? a : b);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    purchases = PurchaseRepository(db);
    materials = MaterialRepository(db);
    sales = SaleRepository(db);
    Future<int> unitId(String name) async => (await (db.select(
      db.units,
    )..where((u) => u.name.equals(name))).getSingle()).id;
    metro = await unitId('metro');
    paquete = await unitId('paquete');
    tela = await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Tela negra',
        unitId: metro,
        pricePerUnit: 2,
        stock: const Value(72.6),
      ),
    );
    paquetes = await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Bolsas',
        unitId: paquete,
        pricePerUnit: 2,
        stock: const Value(1),
      ),
    );
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

  group('purchases', () {
    test('canceling a 15 m purchase leaves exactly 57.60, not 57.599999999999994', () async {
      final id = await buy(tela, 15, 2);
      // El stock actual (72.6) ya incluye esa compra, como en los datos de ejemplo.
      await (db.update(db.materials)..where((m) => m.id.equals(tela))).write(
        const MaterialsCompanion(stock: Value(72.6)),
      );
      expect(72.6 - 15, isNot(57.6)); // la resta cruda da 57.599999999999994

      expect(await purchases.cancelPurchase(id), isNull);

      expect((await material(tela)).stock, 57.6);
    });

    test('a purchase of 15 m after 72.6 stores 87.6 exactly', () async {
      await buy(tela, 15, 2);
      expect((await material(tela)).stock, 87.6);
    });

    test('canceling is blocked, by the rounded values, when the stock was used', () async {
      final id = await buy(tela, 15, 2);
      // Se usan 80 de los 87.6: quedan 7.6 y la compra sumó 15.
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Cuadro',
          priceA: 1,
          priceB: 1,
        ),
      );
      expect(
        await materials.registerMaterialUsage(
          productId: productId,
          materialId: tela,
          quantityUsed: 80,
        ),
        isNull,
      );
      expect((await material(tela)).stock, 7.6);

      final error = await purchases.cancelPurchase(id);

      expect(error, isNotNull);
      expect((await material(tela)).stock, 7.6);
      expect((await purchases.getAll()).single.isCanceled, isFalse);
    });

    test('canceling that leaves exactly zero is allowed', () async {
      final id = await buy(tela, 15, 2);
      expect(
        await materials.registerMaterialUsage(
          productId: productId,
          materialId: tela,
          quantityUsed: 72.6,
        ),
        isNull,
      );
      expect((await material(tela)).stock, 15);

      expect(await purchases.cancelPurchase(id), isNull);

      expect((await material(tela)).stock, 0);
    });

    test('quantities with more than two decimals are stored rounded half up', () async {
      await buy(tela, 1.005, 2);
      expect((await material(tela)).stock, 73.61);
      final items = await purchases.getItemsForPurchase(
        (await purchases.getAll()).single.id,
      );
      expect(items.single.quantity, 1.01);
    });

    test('fraction units keep exact fractions', () async {
      await buy(paquetes, 1 / 3, 6);
      final stock = (await material(paquetes)).stock;
      expect(stock, closeTo(1 + 1 / 3, 1e-6));
      expect(stock, isNot(1.33));
    });

    test('calculateMaterialsTotal sums many lines on cents', () {
      final items = [
        for (var i = 0; i < 30; i++)
          {'materialId': tela, 'quantity': 0.1, 'unitPrice': 0.3},
      ];
      // 30 x (0.1 x 0.3) = 0.90 con ruido si se suma crudo.
      expect(purchases.calculateMaterialsTotal(items), 0.9);
      expect(
        purchases.calculateMaterialsTotal([
          {'materialId': tela, 'quantity': 3.0, 'unitPrice': 13.333},
        ]),
        40.0,
      );
    });

    test('editing a purchase quantity moves the stock by the rounded difference', () async {
      final id = await buy(tela, 15, 2);
      final error = await purchases.editPurchase(
        purchaseId: id,
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 20,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        newItems: [
          {'materialId': tela, 'quantity': 10.1, 'unitPrice': 2.0},
        ],
      );
      expect(error, isNull);
      expect((await material(tela)).stock, 82.7);
    });
  });

  group('material usage', () {
    test('register, edit and cancel leave stock on two decimals', () async {
      expect(
        await materials.registerMaterialUsage(
          productId: productId,
          materialId: tela,
          quantityUsed: 15,
        ),
        isNull,
      );
      expect((await material(tela)).stock, 57.6);

      final record = await db.select(db.productMaterials).getSingle();
      expect(await materials.editMaterialUsage(recordId: record.id, newQuantity: 12.3), isNull);
      expect((await material(tela)).stock, 60.3);

      expect(await materials.cancelMaterialUsage(record.id), isNull);
      expect((await material(tela)).stock, 72.6);
    });

    test('a usage typed with three decimals is rounded to two when saved', () async {
      expect(
        await materials.registerMaterialUsage(
          productId: productId,
          materialId: tela,
          quantityUsed: 2.345,
        ),
        isNull,
      );
      final record = await db.select(db.productMaterials).getSingle();
      expect(record.quantityUsed, 2.35);
      expect((await material(tela)).stock, 70.25);
    });

    test('using the rounded available stock exactly is allowed', () async {
      // 72.6 se guarda tal cual; se usa todo.
      expect(
        await materials.registerMaterialUsage(
          productId: productId,
          materialId: tela,
          quantityUsed: 72.6,
        ),
        isNull,
      );
      expect((await material(tela)).stock, 0);
    });

    test('saving a material rounds its price and stock', () async {
      await materials.save(
        name: 'Hilo',
        unitId: metro,
        stock: 10.005,
        pricePerUnit: 13.3333333,
      );
      final saved = await (db.select(db.materials)
            ..where((m) => m.name.equals('Hilo')))
          .getSingle();
      expect(saved.stock, 10.01);
      expect(saved.pricePerUnit, 13.33);
    });
  });

  group('sales and products', () {
    test('subtotal and total sum many lines and a discount on cents', () async {
      final product = (await ProductRepository(db).getActive()).single;
      final subtotal = sales.calculateSubtotal([product], {product.id: 3});
      expect(subtotal, 99.99);
      expect(sales.calculateTotal(subtotal, 0.1), 99.89);
      expect(sales.calculateTotal(72.6, 15), 57.6);
      expect(sales.calculateTotal(0.3, 0.1 + 0.2), 0);
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

    test('product prices and cost typed with extra decimals are saved on cents', () async {
      final categoryId = (await db.select(db.categories).get()).first.id;
      await ProductRepository(db).save(
        categoryId: categoryId,
        name: 'Collar',
        priceA: 13.335,
        priceB: 10.004,
        productionCost: 5.555,
        stock: 1,
      );
      final saved = await (db.select(db.products)
            ..where((p) => p.name.equals('Collar')))
          .getSingle();
      expect(saved.priceA, 13.34);
      expect(saved.priceB, 10.0);
      expect(saved.productionCost, 5.56);
    });

    test('canceling a sale returns whole units to the stock', () async {
      await sales.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 66.66,
        discount: 0,
        finalAmount: 66.66,
        date: DateTime(2024, 1, 1),
        items: [
          {'productId': productId, 'quantity': 2, 'unitPrice': 33.33},
        ],
      );
      Future<Product> product() => (db.select(db.products)
            ..where((p) => p.id.equals(productId)))
          .getSingle();
      expect((await product()).stock, 8);
      expect(await sales.cancelSale((await sales.getAll()).single.id), isNull);
      expect((await product()).stock, 10);
    });
  });
}
