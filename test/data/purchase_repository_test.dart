import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';

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
        description: 'Transporte',
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
      expect(purchases.first.description, 'Transporte');

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
}
