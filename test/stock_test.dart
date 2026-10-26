import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';

void main() {
  group('purchase cancellation', () {
    late AppDatabase db;
    late PurchaseRepository repository;

    Future<double> stockOf(int materialId) async => (await (db.select(
      db.materials,
    )..where((m) => m.id.equals(materialId))).getSingle()).stock;

    Future<int> createMaterialPurchase(
      List<Map<String, dynamic>> items, {
      int? locationId,
      DateTime? date,
    }) async {
      await repository.createPurchase(
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: repository.calculateMaterialsTotal(items),
        date: date ?? DateTime(2024, 1, 1),
        locationId: locationId,
        eventId: null,
        items: items,
      );
      final all = await repository.getAll();
      return all.map((p) => p.id).reduce((a, b) => a > b ? a : b);
    }

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = PurchaseRepository(db);
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals('unidad'))).getSingle();
      for (final (name, stock) in [('Material 1', 10.0), ('Material 2', 4.0)]) {
        await db.into(db.materials).insert(
          MaterialsCompanion.insert(
            name: name,
            unitId: unit.id,
            pricePerUnit: 2.0,
            stock: Value(stock),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'is blocked, changing nothing, when a material no longer has the '
      'quantity that was bought (it was already used)',
      () async {
        final id = await createMaterialPurchase([
          {'materialId': 1, 'quantity': 5.0, 'unitPrice': 3.0},
          {'materialId': 2, 'quantity': 2.0, 'unitPrice': 4.0},
        ]);
        await (db.update(db.materials)..where((m) => m.id.equals(2)))
            .write(const MaterialsCompanion(stock: Value(1)));

        final error = await repository.cancelPurchase(id);

        expect(
          error,
          'No se puede cancelar la compra porque el stock actual de uno de '
          'los materiales es menor a la cantidad comprada.',
        );
        expect(await stockOf(1), 15);
        expect(await stockOf(2), 1);
        expect((await repository.getAll()).single.isCanceled, isFalse);
      },
    );
  });

  group('material usage', () {
    late AppDatabase db;
    late MaterialRepository repository;

    Future<double> stockOf(int materialId) async => (await (db.select(
      db.materials,
    )..where((m) => m.id.equals(materialId))).getSingle()).stock;

    Future<ProductMaterial> recordFor(int productId, int materialId) => (db.select(
      db.productMaterials,
    )..where(
          (pm) => pm.productId.equals(productId) & pm.materialId.equals(materialId),
        ))
        .getSingle();

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = MaterialRepository(db);

      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Tote bag negra',
          priceA: 10,
          priceB: 8,
          stock: const Value(5),
        ),
      );
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals('contenedor'))).getSingle();
      for (final name in ['Tela beige', 'Resina parte A']) {
        await db.into(db.materials).insert(
          MaterialsCompanion.insert(
            name: name,
            unitId: unit.id,
            pricePerUnit: 3.5,
            stock: const Value(10),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'gives the used quantity back to the material and marks the record as '
      'canceled, keeping it as history',
      () async {
        await repository.registerMaterialUsage(
          productId: 1,
          materialId: 1,
          quantityUsed: 2.5,
        );
        expect(await stockOf(1), 7.5);
        final record = await recordFor(1, 1);
        expect(record.isCanceled, isFalse);
        expect(record.canceledAt, isNull);

        final error = await repository.cancelMaterialUsage(record.id);

        expect(error, isNull);
        expect(await stockOf(1), 10);
        final after = await recordFor(1, 1);
        expect(after.isCanceled, isTrue);
        expect(after.canceledAt, isNotNull);
        expect(after.quantityUsed, 2.5);
      },
    );
  });

  group('stock precision', () {
    late AppDatabase db;
    late PurchaseRepository purchases;
    late int metro;
    late int tela;

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
      metro = (await (db.select(
        db.units,
      )..where((u) => u.name.equals('metro'))).getSingle()).id;
      tela = await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Tela negra',
          unitId: metro,
          pricePerUnit: 2,
          stock: const Value(72.6),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('canceling a 15 m purchase leaves exactly 57.60, not 57.599999999999994', () async {
      final id = await buy(tela, 15, 2);
      await (db.update(db.materials)..where((m) => m.id.equals(tela))).write(
        const MaterialsCompanion(stock: Value(72.6)),
      );
      expect(72.6 - 15, isNot(57.6));

      expect(await purchases.cancelPurchase(id), isNull);

      expect((await material(tela)).stock, 57.6);
    });
  });
}
