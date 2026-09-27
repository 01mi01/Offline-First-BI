import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v8.dart' as v8;
import '../generated_migrations/schema_v9.dart' as v9;

// Verifica la migración real (onUpgrade) de v8 -> v9 contra snapshots de
// esquema generados por Drift (drift_schemas/drift_schema_v{8,9}.json vía
// `dart run drift_dev schema generate`). A diferencia del resto de la suite
// (que solo abre bases de datos en blanco vía onCreate), esto ejecuta el SQL
// de migración de verdad sobre datos con la forma exacta de v8.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test(
    'migrating a v8 database to v9 produces exactly the expected v9 schema',
    () async {
      final connection = await verifier.startAt(8);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, 9);
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
      await verifier.migrateAndValidate(dbForMigration, 9);
      await dbForMigration.close();

      final checkDb = v9.DatabaseAtV9(schema.newConnection());
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
      await verifier.migrateAndValidate(dbForMigration, 9);
      await dbForMigration.close();

      final checkDb = v9.DatabaseAtV9(schema.newConnection());
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
          v9.ProductMaterialsCompanion.insert(
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
      await verifier.migrateAndValidate(dbForMigration, 9);
      await dbForMigration.close();

      final checkDb = v9.DatabaseAtV9(schema.newConnection());
      addTearDown(checkDb.close);

      final session = await (checkDb.select(
        checkDb.sesionLocal,
      )..where((s) => s.id.equals(sessionRowId))).getSingle();

      expect(session.userId, 7);
      expect(session.username, 'usuario_prueba');
    },
  );
}
