import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v8.dart' as v8;
import '../generated_migrations/schema_v9.dart' as v9;
import '../generated_migrations/schema_v10.dart' as v10;

// Verifica la migración real (onUpgrade) contra snapshots de esquema
// generados por Drift (drift_schemas/drift_schema_v{8,9,10}.json vía
// `dart run drift_dev schema generate`). A diferencia del resto de la suite
// (que solo abre bases de datos en blanco vía onCreate), esto ejecuta el SQL
// de migración de verdad sobre datos con la forma exacta de cada versión.
//
// migrateAndValidate siempre migra hasta el schemaVersion actual de
// AppDatabase (ahora 10), sin importar en qué versión "lógica" se centre
// cada test — por eso los tests con datos de v8 también apuntan a 10.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test(
    'migrating a v8 database all the way to the live schema (v10) produces '
    'exactly the expected schema',
    () async {
      final connection = await verifier.startAt(8);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, 10);
    },
  );

  test(
    'Products: a null category_id is backfilled to "Sin categoría", and the '
    'old single sale_price is preserved as both price_a and price_b',
    () async {
      final schema = await verifier.schemaAt(8);
      addTearDown(schema.close);

      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      final categoryId = await oldDb
          .into(oldDb.categories)
          .insert(v8.CategoriesCompanion.insert(name: 'Bisutería'));
      final withCategoryId = await oldDb.into(oldDb.products).insert(
        v8.ProductsCompanion.insert(
          categoryId: Value(categoryId),
          name: 'Con categoría',
          salePrice: 25.5,
        ),
      );
      final withoutCategoryId = await oldDb.into(oldDb.products).insert(
        v8.ProductsCompanion.insert(
          name: 'Sin categoría asignada',
          salePrice: 42.0,
        ),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 10);
      await dbForMigration.close();

      final checkDb = v10.DatabaseAtV10(schema.newConnection());
      addTearDown(checkDb.close);

      final productWithCategory = await (checkDb.select(
        checkDb.products,
      )..where((p) => p.id.equals(withCategoryId))).getSingle();
      expect(productWithCategory.categoryId, categoryId);
      expect(productWithCategory.priceA, 25.5);
      expect(productWithCategory.priceB, 25.5);

      final sinCategoria = await (checkDb.select(
        checkDb.categories,
      )..where((c) => c.name.equals('Sin categoría'))).getSingle();

      final productWithoutCategory = await (checkDb.select(
        checkDb.products,
      )..where((p) => p.id.equals(withoutCategoryId))).getSingle();
      expect(productWithoutCategory.categoryId, sinCategoria.id);
      expect(productWithoutCategory.priceA, 42.0);
      expect(productWithoutCategory.priceB, 42.0);
    },
  );

  test(
    'ProductMaterials: duplicate rows for the same product+material pair are '
    'collapsed to the most recent one before the unique index is applied, '
    'and the index then rejects new duplicates',
    () async {
      final schema = await verifier.schemaAt(8);
      addTearDown(schema.close);

      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      // Mismo par (1,1): dos filas, la más nueva por created_at debe sobrevivir.
      await oldDb.into(oldDb.productMaterials).insert(
        v8.ProductMaterialsCompanion.insert(
          productId: 1,
          materialId: 1,
          quantityUsed: 2,
          createdAt: const Value(1000),
        ),
      );
      final newerRowId = await oldDb.into(oldDb.productMaterials).insert(
        v8.ProductMaterialsCompanion.insert(
          productId: 1,
          materialId: 1,
          quantityUsed: 5,
          createdAt: const Value(2000),
        ),
      );
      // Par distinto (1,2): no debe verse afectado por la deduplicación.
      final unrelatedPairRowId = await oldDb.into(oldDb.productMaterials).insert(
        v8.ProductMaterialsCompanion.insert(
          productId: 1,
          materialId: 2,
          quantityUsed: 9,
          createdAt: const Value(1000),
        ),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 10);
      await dbForMigration.close();

      final checkDb = v10.DatabaseAtV10(schema.newConnection());
      addTearDown(checkDb.close);

      final allRows = await checkDb.select(checkDb.productMaterials).get();
      expect(allRows, hasLength(2));

      final survivingPair = allRows.singleWhere(
        (r) => r.productId == 1 && r.materialId == 1,
      );
      expect(survivingPair.id, newerRowId);
      expect(survivingPair.quantityUsed, 5);

      final untouchedPair = allRows.singleWhere(
        (r) => r.productId == 1 && r.materialId == 2,
      );
      expect(untouchedPair.id, unrelatedPairRowId);
      expect(untouchedPair.quantityUsed, 9);

      // El índice único ya está activo: otra fila para el mismo par (1,1)
      // debe ser rechazada por la base de datos.
      await expectLater(
        checkDb.into(checkDb.productMaterials).insert(
          v10.ProductMaterialsCompanion.insert(
            productId: 1,
            materialId: 1,
            quantityUsed: 1,
          ),
        ),
        throwsA(anything),
      );
    },
  );

  test(
    'SesionLocal: a text user_id is cast to an int referencing Users(id)',
    () async {
      final schema = await verifier.schemaAt(8);
      addTearDown(schema.close);

      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      final sessionRowId = await oldDb.into(oldDb.sesionLocal).insert(
        v8.SesionLocalCompanion.insert(
          userId: '7',
          username: 'usuario_prueba',
          createdAt: 1717000000,
        ),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 10);
      await dbForMigration.close();

      final checkDb = v10.DatabaseAtV10(schema.newConnection());
      addTearDown(checkDb.close);

      final session = await (checkDb.select(
        checkDb.sesionLocal,
      )..where((s) => s.id.equals(sessionRowId))).getSingle();

      expect(session.userId, 7);
      expect(session.username, 'usuario_prueba');
    },
  );

  test(
    'migrating a v9 database to v10 produces exactly the expected v10 schema',
    () async {
      final connection = await verifier.startAt(9);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, 10);
    },
  );

  test(
    'Units: the seed list is inserted with the expected name/type pairs',
    () async {
      final connection = await verifier.startAt(9);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 10);

      final rows = await db.select(db.units).get();
      final byName = {for (final u in rows) u.name: u.type};

      expect(rows, hasLength(13));
      expect(byName['botella'], 'contenedor');
      expect(byName['bolsa'], 'contenedor');
      expect(byName['paquete'], 'contenedor');
      expect(byName['caja'], 'contenedor');
      expect(byName['frasco'], 'contenedor');
      expect(byName['lata'], 'contenedor');
      expect(byName['rollo'], 'contenedor');
      expect(byName['unidad'], 'medida');
      expect(byName['metro'], 'medida');
      expect(byName['litro'], 'medida');
      expect(byName['kg'], 'medida');
      expect(byName['gramo'], 'medida');
      expect(byName['otro'], 'otros');
    },
  );

  test(
    'Materials: the old free-text unit is mapped case-insensitively to the '
    'matching seeded Units row, falling back to "otro" when there is no '
    'match',
    () async {
      final schema = await verifier.schemaAt(9);
      addTearDown(schema.close);

      final oldDb = v9.DatabaseAtV9(schema.newConnection());
      // Mayúsculas distintas a propósito: el mapeo debe ser insensible.
      final matchedRowId = await oldDb.into(oldDb.materials).insert(
        v9.MaterialsCompanion.insert(
          name: 'Cerveza artesanal',
          unit: const Value('Botella'),
          pricePerUnit: 12.0,
        ),
      );
      final unmatchedRowId = await oldDb.into(oldDb.materials).insert(
        v9.MaterialsCompanion.insert(
          name: 'Material raro',
          unit: const Value('unidad-inventada-xyz'),
          pricePerUnit: 3.0,
        ),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 10);
      await dbForMigration.close();

      final checkDb = v10.DatabaseAtV10(schema.newConnection());
      addTearDown(checkDb.close);

      final botellaUnit = await (checkDb.select(
        checkDb.units,
      )..where((u) => u.name.equals('botella'))).getSingle();
      final otroUnit = await (checkDb.select(
        checkDb.units,
      )..where((u) => u.name.equals('otro'))).getSingle();

      final matchedMaterial = await (checkDb.select(
        checkDb.materials,
      )..where((m) => m.id.equals(matchedRowId))).getSingle();
      expect(matchedMaterial.unitId, botellaUnit.id);

      final unmatchedMaterial = await (checkDb.select(
        checkDb.materials,
      )..where((m) => m.id.equals(unmatchedRowId))).getSingle();
      expect(unmatchedMaterial.unitId, otroUnit.id);
    },
  );
}
