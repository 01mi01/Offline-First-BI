import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';

// Registro de uso de materiales (product_materials): editar ajusta el stock
// por diferencia; cancelar devuelve el stock y conserva el registro marcado
// como cancelado (no se borra).
void main() {
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

  group('cancelMaterialUsage', () {
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
        expect(await stockOf(1), 10); // devuelto
        final after = await recordFor(1, 1);
        expect(after.isCanceled, isTrue);
        expect(after.canceledAt, isNotNull);
        expect(after.quantityUsed, 2.5); // el registro se conserva intacto
      },
    );

    test('reverts the CURRENT quantity after an edit, not the original one', () async {
      await repository.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 2,
      );
      final record = await recordFor(1, 1);
      await repository.editMaterialUsage(recordId: record.id, newQuantity: 4);
      expect(await stockOf(1), 6); // 10 - 4

      await repository.cancelMaterialUsage(record.id);

      expect(await stockOf(1), 10);
    });

    test('canceling twice is rejected and does not return the stock twice', () async {
      await repository.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 3,
      );
      final record = await recordFor(1, 1);
      expect(await repository.cancelMaterialUsage(record.id), isNull);
      expect(await stockOf(1), 10);

      final second = await repository.cancelMaterialUsage(record.id);

      expect(second, 'El registro ya está cancelado');
      expect(await stockOf(1), 10); // no 13
    });

    test('a canceled record cannot be edited and leaves the stock alone', () async {
      await repository.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 3,
      );
      final record = await recordFor(1, 1);
      await repository.cancelMaterialUsage(record.id);

      final error = await repository.editMaterialUsage(
        recordId: record.id,
        newQuantity: 5,
      );

      expect(error, 'El registro está cancelado y no se puede editar');
      expect(await stockOf(1), 10);
      expect((await recordFor(1, 1)).quantityUsed, 3);
    });

    test('canceling a record that does not exist reports it', () async {
      expect(await repository.cancelMaterialUsage(999), 'Registro no encontrado');
    });

    test(
      'registering the same product+material again reactivates the canceled '
      'record (the pair is unique) and takes the stock again',
      () async {
        await repository.registerMaterialUsage(
          productId: 1,
          materialId: 1,
          quantityUsed: 3,
        );
        final record = await recordFor(1, 1);
        await repository.cancelMaterialUsage(record.id);
        expect(await stockOf(1), 10);

        final error = await repository.registerMaterialUsage(
          productId: 1,
          materialId: 1,
          quantityUsed: 1,
        );

        expect(error, isNull);
        final after = await recordFor(1, 1);
        expect(after.id, record.id); // misma fila
        expect(after.isCanceled, isFalse);
        expect(after.canceledAt, isNull);
        expect(after.quantityUsed, 1);
        expect(await stockOf(1), 9);
      },
    );

    test('reactivating still checks there is enough stock', () async {
      await repository.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 3,
      );
      final record = await recordFor(1, 1);
      await repository.cancelMaterialUsage(record.id);

      final error = await repository.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 99,
      );

      expect(error, startsWith('Stock insuficiente'));
      expect((await recordFor(1, 1)).isCanceled, isTrue);
      expect(await stockOf(1), 10);
    });
  });

  group('registering usage again for an already-linked product+material', () {
    Future<int> rowCount() async =>
        (await db.select(db.productMaterials).get()).length;

    test('adds to quantity_used instead of replacing it (0.25 + 0.75 = 1.0)', () async {
      expect(
        await repository.registerMaterialUsage(
          productId: 1,
          materialId: 1,
          quantityUsed: 0.25,
        ),
        isNull,
      );
      expect((await recordFor(1, 1)).quantityUsed, 0.25);

      expect(
        await repository.registerMaterialUsage(
          productId: 1,
          materialId: 1,
          quantityUsed: 0.75,
        ),
        isNull,
      );

      expect((await recordFor(1, 1)).quantityUsed, 1.0);
      expect(await rowCount(), 1, reason: 'sigue siendo una sola fila por par');
    });

    test('stock goes down only by each newly registered amount', () async {
      await repository.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 0.25,
      );
      expect(await stockOf(1), 9.75); // 10 - 0.25

      await repository.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 0.75,
      );
      // Baja 0.75 (lo nuevo), no 1.0 (el acumulado): 9.75 - 0.75.
      expect(await stockOf(1), 9.0);
    });

    test('three registrations keep accumulating', () async {
      for (final q in [1.0, 2.0, 0.5]) {
        await repository.registerMaterialUsage(
          productId: 1,
          materialId: 1,
          quantityUsed: q,
        );
      }
      expect((await recordFor(1, 1)).quantityUsed, 3.5);
      expect(await stockOf(1), 6.5);
    });

    test('other products and other materials are not affected', () async {
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Set de pines pequeños',
          priceA: 5,
          priceB: 5,
          stock: const Value(1),
        ),
      );
      await repository.registerMaterialUsage(productId: 1, materialId: 1, quantityUsed: 1);
      await repository.registerMaterialUsage(productId: 2, materialId: 1, quantityUsed: 2);
      await repository.registerMaterialUsage(productId: 1, materialId: 2, quantityUsed: 3);
      await repository.registerMaterialUsage(productId: 1, materialId: 1, quantityUsed: 1);

      expect((await recordFor(1, 1)).quantityUsed, 2); // 1 + 1
      expect((await recordFor(2, 1)).quantityUsed, 2);
      expect((await recordFor(1, 2)).quantityUsed, 3);
      expect(await stockOf(1), 6); // 10 - (1 + 2 + 1)
      expect(await stockOf(2), 7); // 10 - 3
    });

    test('still checks the stock for the newly added amount', () async {
      await repository.registerMaterialUsage(productId: 1, materialId: 1, quantityUsed: 6);

      final error = await repository.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 5, // solo quedan 4
      );

      expect(error, 'Stock insuficiente. Disponible: 4');
      expect((await recordFor(1, 1)).quantityUsed, 6); // sin cambios
      expect(await stockOf(1), 4);
    });
  });

  group('editing a usage registration is a replacement, not an addition', () {
    test('editMaterialUsage sets the quantity to the new value', () async {
      await repository.registerMaterialUsage(productId: 1, materialId: 1, quantityUsed: 2);
      final record = await recordFor(1, 1);

      expect(
        await repository.editMaterialUsage(recordId: record.id, newQuantity: 5),
        isNull,
      );

      expect((await recordFor(1, 1)).quantityUsed, 5); // no 7
      expect(await stockOf(1), 5); // 10 - 5
    });

    test('editing down also replaces, and gives the difference back', () async {
      await repository.registerMaterialUsage(productId: 1, materialId: 1, quantityUsed: 4);
      final record = await recordFor(1, 1);

      await repository.editMaterialUsage(recordId: record.id, newQuantity: 1);

      expect((await recordFor(1, 1)).quantityUsed, 1);
      expect(await stockOf(1), 9);
    });

    test('after accumulating, an edit corrects the accumulated total', () async {
      await repository.registerMaterialUsage(productId: 1, materialId: 1, quantityUsed: 0.25);
      await repository.registerMaterialUsage(productId: 1, materialId: 1, quantityUsed: 0.75);
      final record = await recordFor(1, 1);
      expect(record.quantityUsed, 1.0);

      await repository.editMaterialUsage(recordId: record.id, newQuantity: 0.5);

      expect((await recordFor(1, 1)).quantityUsed, 0.5);
      expect(await stockOf(1), 9.5);
    });

    test('registering after an edit adds on top of the edited value', () async {
      await repository.registerMaterialUsage(productId: 1, materialId: 1, quantityUsed: 2);
      await repository.editMaterialUsage(
        recordId: (await recordFor(1, 1)).id,
        newQuantity: 3,
      );

      await repository.registerMaterialUsage(productId: 1, materialId: 1, quantityUsed: 1);

      expect((await recordFor(1, 1)).quantityUsed, 4);
      expect(await stockOf(1), 6);
    });
  });

  group('listing usage records', () {
    test('getMaterialsForProduct still lists canceled records, flagged as such', () async {
      await repository.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 2,
      );
      await repository.registerMaterialUsage(
        productId: 1,
        materialId: 2,
        quantityUsed: 1,
      );
      await repository.cancelMaterialUsage((await recordFor(1, 1)).id);

      final log = await repository.getMaterialsForProduct(1);

      expect(log, hasLength(2));
      final byName = {for (final e in log) e.materialName: e};
      expect(byName['Tela beige']!.isCanceled, isTrue);
      expect(byName['Tela beige']!.canceledAt, isNotNull);
      expect(byName['Resina parte A']!.isCanceled, isFalse);
    });

    test('canceled usage no longer counts as a material of the product', () async {
      await repository.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 2,
      );
      await repository.registerMaterialUsage(
        productId: 1,
        materialId: 2,
        quantityUsed: 1,
      );
      await repository.cancelMaterialUsage((await recordFor(1, 1)).id);

      expect(await repository.getUniqueMaterialNamesForProduct(1), ['Resina parte A']);
      final priced = await repository.getMaterialsWithPriceForProduct(1);
      expect(priced.map((m) => m['name']), ['Resina parte A']);
    });
  });
}
