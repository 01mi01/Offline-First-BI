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
        name: 'Collar',
        priceA: 10,
        priceB: 8,
        stock: const Value(5),
      ),
    );
    final unit = await (db.select(
      db.units,
    )..where((u) => u.name.equals('botella'))).getSingle();
    for (final name in ['Vidrio fino', 'Hilo']) {
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
      expect(byName['Vidrio fino']!.isCanceled, isTrue);
      expect(byName['Vidrio fino']!.canceledAt, isNotNull);
      expect(byName['Hilo']!.isCanceled, isFalse);
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

      expect(await repository.getUniqueMaterialNamesForProduct(1), ['Hilo']);
      final priced = await repository.getMaterialsWithPriceForProduct(1);
      expect(priced.map((m) => m['name']), ['Hilo']);
    });
  });
}
