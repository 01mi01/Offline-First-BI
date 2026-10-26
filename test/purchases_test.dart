import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/config/app_clock.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';

void main() {
  group('registering a purchase', () {
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

      expect(material.stock, 15);
      expect(material.pricePerUnit, 3.0);

      final purchases = await repository.getAll();
      expect(purchases, hasLength(1));
      expect(purchases.first.isMaterial, isTrue);

      final items = await repository.getItemsForPurchase(purchases.first.id);
      expect(items, hasLength(1));
      expect(items.first.subtotal, 15);
    });
  });

  group('a purchase dated in the future', () {
    late AppDatabase db;
    late PurchaseRepository repository;

    setUp(() async {
      setAppClockForTesting(() => DateTime(2026, 10, 25, 10));
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
      setAppClockForTesting();
      await db.close();
    });

    Future<Material> material() => (db.select(
      db.materials,
    )..where((m) => m.id.equals(1))).getSingle();

    Future<void> buy(DateTime date, double quantity, double unitPrice) =>
        repository.createPurchase(
          supplierId: null,
          isMaterial: true,
          description: null,
          totalAmount: quantity * unitPrice,
          date: date,
          locationId: null,
          eventId: null,
          items: [
            {'materialId': 1, 'quantity': quantity, 'unitPrice': unitPrice},
          ],
        );

    test('a purchase dated after today raises the stock and keeps the price', () async {
      await buy(DateTime(2026, 10, 26, 12), 5, 9);

      final m = await material();
      expect(m.stock, 15);
      expect(m.pricePerUnit, 2.0);
    });
  });

  group('editing a purchase', () {
    late AppDatabase db;
    late PurchaseRepository purchases;
    late int unitId;
    late int tela;
    late int product;

    Future<double> stockOf(int id) async => (await (db.select(
      db.materials,
    )..where((m) => m.id.equals(id))).getSingle()).stock;

    Future<List<PurchaseItem>> linesOf(int purchaseId) => (db.select(
      db.purchaseItems,
    )..where((i) => i.purchaseId.equals(purchaseId))).get();

    Future<Purchase> purchaseRow(int id) =>
        (db.select(db.purchases)..where((p) => p.id.equals(id))).getSingle();

    Map<String, dynamic> line(int materialId, double quantity, double price) => {
      'materialId': materialId,
      'quantity': quantity,
      'unitPrice': price,
    };

    Future<String?> edit(
      int purchaseId,
      List<Map<String, dynamic>> items, {
      bool isMaterial = true,
      double total = 10,
      String? description,
    }) => purchases.editPurchase(
      purchaseId: purchaseId,
      supplierId: null,
      isMaterial: isMaterial,
      description: description,
      totalAmount: total,
      date: DateTime(2024, 1, 1),
      locationId: null,
      eventId: null,
      newItems: items,
    );

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      purchases = PurchaseRepository(db);
      unitId = (await (db.select(
        db.units,
      )..where((u) => u.name.equals('unidad'))).getSingle()).id;
      tela = await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Tela',
          unitId: unitId,
          pricePerUnit: 2,
          stock: const Value(0),
        ),
      );
      product = await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Cuadro',
          priceA: 20,
          priceB: 20,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> purchaseOfFiveWithFourUsed() async {
      await purchases.createPurchase(
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 10,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: [line(tela, 5, 2)],
      );
      final id = (await purchases.getAll()).single.id;
      expect(
        await MaterialRepository(
          db,
        ).registerMaterialUsage(productId: product, materialId: tela, quantityUsed: 4),
        isNull,
      );
      expect(await stockOf(tela), 1);
      return id;
    }

    test('reducing the line below what was already used is rejected', () async {
      final id = await purchaseOfFiveWithFourUsed();

      final error = await edit(id, [line(tela, 1, 2)], total: 2);

      expect(error, PurchaseRepository.editBlockedMessage);
      expect(await stockOf(tela), 1);
      final lines = await linesOf(id);
      expect(lines.single.quantity, 5);
      expect((await purchaseRow(id)).totalAmount, 10);
    });
  });
}
