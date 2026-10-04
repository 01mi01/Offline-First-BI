import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/data/repositories/supplier_repository.dart';

void main() {
  group('PurchaseRepository pure calculations (no database needed)', () {
    late AppDatabase db;
    late PurchaseRepository repository;

    setUpAll(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = PurchaseRepository(db);
    });

    tearDownAll(() async {
      await db.close();
    });

    test('calculateMaterialsTotal sums quantity * unitPrice for every item', () {
      final items = [
        {'quantity': 3.0, 'unitPrice': 10.0},
        {'quantity': 2.0, 'unitPrice': 5.0},
      ];

      expect(repository.calculateMaterialsTotal(items), 40); // 30 + 10
    });

    test('calculateMaterialsTotal returns 0 for an empty item list', () {
      expect(repository.calculateMaterialsTotal(const []), 0);
    });

    test('calculateMaterialsTotal handles a single item', () {
      final items = [
        {'quantity': 4.0, 'unitPrice': 2.5},
      ];
      expect(repository.calculateMaterialsTotal(items), 10);
    });

    test('calculateMaterialsTotal handles fractional quantities', () {
      final items = [
        {'quantity': 1.5, 'unitPrice': 4.0},
      ];
      expect(repository.calculateMaterialsTotal(items), 6);
    });
  });

  group('PurchaseRepository stock updates (in-memory database)', () {
    late AppDatabase db;
    late PurchaseRepository repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = PurchaseRepository(db);
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals('unidad'))).getSingle();
      await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Material 1',
          unitId: unit.id,
          pricePerUnit: 2.0,
          stock: const Value(10.0),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('createPurchase of materials increases stock and updates the unit price', () async {
      await repository.createPurchase(
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 5 * 3.0,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: [
          {'materialId': 1, 'quantity': 5.0, 'unitPrice': 3.0},
        ],
      );

      final material = await (db.select(
        db.materials,
      )..where((m) => m.id.equals(1))).getSingle();

      expect(material.stock, 15); // 10 + 5
      expect(material.pricePerUnit, 3.0); // updated from the purchase

      final purchases = await repository.getAll();
      expect(purchases, hasLength(1));
      expect(purchases.first.isMaterial, isTrue);

      final items = await repository.getItemsForPurchase(purchases.first.id);
      expect(items, hasLength(1));
      expect(items.first.subtotal, 15);
    });

    test('a general expense purchase (isMaterial: false) does not touch material stock', () async {
      await repository.createPurchase(
        supplierId: null,
        isMaterial: false,
        description: 'Pasaje de bus',
        totalAmount: 50,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: const [],
      );

      final material = await (db.select(
        db.materials,
      )..where((m) => m.id.equals(1))).getSingle();

      expect(material.stock, 10); // unchanged

      final purchases = await repository.getAll();
      expect(purchases, hasLength(1));
      expect(purchases.first.isMaterial, isFalse);
      expect(purchases.first.description, 'Pasaje de bus');

      final items = await repository.getItemsForPurchase(purchases.first.id);
      expect(items, isEmpty);
    });

    test('editPurchase reverts the old quantity before applying the new one', () async {
      await repository.createPurchase(
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 5 * 2.0,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: [
          {'materialId': 1, 'quantity': 5.0, 'unitPrice': 2.0},
        ],
      );
      final purchase = (await repository.getAll()).first;
      // stock tras la creación: 10 + 5 = 15

      await repository.editPurchase(
        purchaseId: purchase.id,
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 2 * 4.0,
        date: purchase.date,
        locationId: null,
        eventId: null,
        newItems: [
          {'materialId': 1, 'quantity': 2.0, 'unitPrice': 4.0},
        ],
      );

      final material = await (db.select(
        db.materials,
      )..where((m) => m.id.equals(1))).getSingle();
      // 15 (post-create) - 5 (revert old) + 2 (new quantity) = 12
      expect(material.stock, 12);
      expect(material.pricePerUnit, 4.0);

      final items = await repository.getItemsForPurchase(purchase.id);
      expect(items, hasLength(1));
      expect(items.first.quantity, 2);
    });
  });

  group('PurchaseRepository default supplier "Sin proveedor" (in-memory database)', () {
    late AppDatabase db;
    late PurchaseRepository repository;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = PurchaseRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> defaultSupplierId() async => (await (db.select(
      db.suppliers,
    )..where((s) => s.name.equals('Sin proveedor'))).getSingle()).id;

    test('a fresh database seeds "Sin proveedor" (and no "Sin nombre" supplier)', () async {
      final names = (await db.select(db.suppliers).get()).map((s) => s.name);
      expect(names, ['Sin proveedor']);
    });

    test('createPurchase with no supplier is assigned to "Sin proveedor"', () async {
      await repository.createPurchase(
        supplierId: null,
        isMaterial: false,
        description: 'Pasaje de bus',
        totalAmount: 25,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: const [],
      );

      final purchases = await repository.getAll();
      expect(purchases, hasLength(1));
      expect(purchases.single.supplierId, await defaultSupplierId());
    });

    test('createPurchase with a real supplier keeps that supplier', () async {
      final chosen = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'Riverside Supply Co.'));

      await repository.createPurchase(
        supplierId: chosen,
        isMaterial: false,
        description: 'Pasaje de bus',
        totalAmount: 25,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: const [],
      );

      expect((await repository.getAll()).single.supplierId, chosen);
    });

    test('editPurchase with no supplier falls back to "Sin proveedor" too', () async {
      final chosen = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'Riverside Supply Co.'));
      await repository.createPurchase(
        supplierId: chosen,
        isMaterial: false,
        description: 'Pasaje de bus',
        totalAmount: 25,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: const [],
      );
      final purchaseId = (await repository.getAll()).single.id;

      await repository.editPurchase(
        purchaseId: purchaseId,
        supplierId: null,
        isMaterial: false,
        description: 'Pasaje de bus',
        totalAmount: 25,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        newItems: const [],
      );

      expect((await repository.getAll()).single.supplierId, await defaultSupplierId());
    });

    test('if the default supplier row is missing it is recreated on demand, once', () async {
      await (db.delete(db.suppliers)
            ..where((s) => s.name.equals('Sin proveedor')))
          .go();

      for (var i = 0; i < 2; i++) {
        await repository.createPurchase(
          supplierId: null,
          isMaterial: false,
          description: 'Gasto $i',
          totalAmount: 10,
          date: DateTime(2024, 1, 1),
          locationId: null,
          eventId: null,
          items: const [],
        );
      }

      final defaults = await (db.select(
        db.suppliers,
      )..where((s) => s.name.equals('Sin proveedor'))).get();
      expect(defaults, hasLength(1));
      final purchases = await repository.getAll();
      expect(purchases.map((p) => p.supplierId), everyElement(defaults.single.id));
    });

    test('"Sin proveedor" behaves as a normal supplier in the active-suppliers list', () async {
      final active = await SupplierRepository(db).getActive();
      expect(active.map((s) => s.name), contains('Sin proveedor'));
    });
  });
}
