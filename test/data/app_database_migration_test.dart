import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v8.dart' as v8;
import '../generated_migrations/schema_v9.dart' as v9;
import '../generated_migrations/schema_v10.dart' as v10;
import '../generated_migrations/schema_v11.dart' as v11;
import '../generated_migrations/schema_v12.dart' as v12;
import '../generated_migrations/schema_v13.dart' as v13;
import '../generated_migrations/schema_v14.dart' as v14;
import '../generated_migrations/schema_v15.dart' as v15;

// Verifica la migración real (onUpgrade) contra snapshots de esquema
// generados por Drift (drift_schemas/drift_schema_v{8,9,10,11,12,13,14,15}.json vía
// `dart run drift_dev schema generate`). A diferencia del resto de la suite
// (que solo abre bases de datos en blanco vía onCreate), esto ejecuta el SQL
// de migración de verdad sobre datos con la forma exacta de cada versión.
//
// migrateAndValidate siempre migra hasta el schemaVersion actual de
// AppDatabase (ahora 15), sin importar en qué versión "lógica" se centre
// cada test — por eso los tests con datos de v8 también apuntan a 10.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test(
    'migrating a v8 database all the way to the live schema (v15) produces '
    'exactly the expected schema',
    () async {
      final connection = await verifier.startAt(8);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, 15);
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
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
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
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
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
          v15.ProductMaterialsCompanion.insert(
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
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
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

      await verifier.migrateAndValidate(db, 15);
    },
  );

  test(
    'Units: the seed list is inserted with the expected name/type pairs',
    () async {
      final connection = await verifier.startAt(9);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 15);

      final rows = await db.select(db.units).get();
      final byName = {for (final u in rows) u.name: u.type};

      expect(rows, hasLength(18));
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
      // Unidades agregadas después
      expect(byName['centímetro'], 'medida');
      expect(byName['milímetro'], 'medida');
      expect(byName['mililitro'], 'medida');
      expect(byName['metro cuadrado'], 'medida');
      expect(byName['tira'], 'contenedor');
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
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
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

  // --- v10 -> v11: el proveedor por defecto pasa de "Sin nombre" a
  // "Sin proveedor" ---
  test(
    'Suppliers: the default "Sin nombre" supplier is renamed in place to '
    '"Sin proveedor" (same id, so existing purchases keep pointing at it)',
    () async {
      final schema = await verifier.schemaAt(10);
      addTearDown(schema.close);

      final oldDb = v10.DatabaseAtV10(schema.newConnection());
      final defaultId = await oldDb
          .into(oldDb.suppliers)
          .insert(v10.SuppliersCompanion.insert(name: 'Sin nombre'));
      final otherId = await oldDb
          .into(oldDb.suppliers)
          .insert(v10.SuppliersCompanion.insert(name: 'Proveedor Andino'));
      final purchaseId = await oldDb.into(oldDb.purchases).insert(
        v10.PurchasesCompanion.insert(
          supplierId: Value(defaultId),
          totalAmount: 10,
          date: 1704067200,
        ),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(checkDb.close);

      final suppliers = await checkDb.select(checkDb.suppliers).get();
      final byId = {for (final s in suppliers) s.id: s.name};
      expect(byId[defaultId], 'Sin proveedor');
      expect(byId[otherId], 'Proveedor Andino');
      expect(byId.values.where((n) => n == 'Sin nombre'), isEmpty);

      final purchase = await (checkDb.select(
        checkDb.purchases,
      )..where((p) => p.id.equals(purchaseId))).getSingle();
      expect(purchase.supplierId, defaultId);
    },
  );

  test(
    'Suppliers: when no default supplier exists at all, "Sin proveedor" is '
    'created by the migration',
    () async {
      final schema = await verifier.schemaAt(10);
      addTearDown(schema.close);

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(checkDb.close);

      final names = (await checkDb.select(checkDb.suppliers).get())
          .map((s) => s.name)
          .toList();
      expect(names, ['Sin proveedor']);
    },
  );

  test(
    'Suppliers: an existing "Sin proveedor" is respected — a separate '
    '"Sin nombre" supplier is left untouched',
    () async {
      final schema = await verifier.schemaAt(10);
      addTearDown(schema.close);

      final oldDb = v10.DatabaseAtV10(schema.newConnection());
      await oldDb
          .into(oldDb.suppliers)
          .insert(v10.SuppliersCompanion.insert(name: 'Sin proveedor'));
      await oldDb
          .into(oldDb.suppliers)
          .insert(v10.SuppliersCompanion.insert(name: 'Sin nombre'));
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(checkDb.close);

      final names = (await checkDb.select(checkDb.suppliers).get())
          .map((s) => s.name)
          .toList();
      expect(names, unorderedEquals(['Sin proveedor', 'Sin nombre']));
    },
  );

  // --- v11 -> v12: el rol sembrado "usuario" pasa a llamarse "empleado" ---
  test(
    'Roles: the seeded "usuario" role is renamed in place to "empleado" '
    '(same id, so user_roles keep pointing at it)',
    () async {
      final schema = await verifier.schemaAt(11);
      addTearDown(schema.close);

      final oldDb = v11.DatabaseAtV11(schema.newConnection());
      final adminId = await oldDb
          .into(oldDb.roles)
          .insert(v11.RolesCompanion.insert(name: 'admin'));
      final usuarioId = await oldDb
          .into(oldDb.roles)
          .insert(v11.RolesCompanion.insert(name: 'usuario'));
      final userId = await oldDb.into(oldDb.users).insert(
        v11.UsersCompanion.insert(
          username: 'maria',
          email: 'maria@example.com',
          passwordHash: 'x',
        ),
      );
      await oldDb.into(oldDb.userRoles).insert(
        v11.UserRolesCompanion.insert(userId: userId, roleId: usuarioId),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(checkDb.close);

      final roles = await checkDb.select(checkDb.roles).get();
      final byId = {for (final r in roles) r.id: r.name};
      expect(byId[adminId], 'admin');
      expect(byId[usuarioId], 'empleado');
      expect(byId.values, isNot(contains('usuario')));

      final link = await checkDb.select(checkDb.userRoles).getSingle();
      expect(link.roleId, usuarioId);
    },
  );

  test(
    'Roles: an existing "empleado" role is respected — the migration does '
    'not violate the unique name constraint',
    () async {
      final schema = await verifier.schemaAt(11);
      addTearDown(schema.close);

      final oldDb = v11.DatabaseAtV11(schema.newConnection());
      await oldDb
          .into(oldDb.roles)
          .insert(v11.RolesCompanion.insert(name: 'usuario'));
      await oldDb
          .into(oldDb.roles)
          .insert(v11.RolesCompanion.insert(name: 'empleado'));
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(checkDb.close);

      final names = (await checkDb.select(checkDb.roles).get())
          .map((r) => r.name)
          .toList();
      expect(names, unorderedEquals(['usuario', 'empleado']));
    },
  );

  // --- v12 -> v13: cancelación de ventas y de registros de uso (columnas
  // is_canceled / canceled_at) ---
  test(
    'Cancelation columns: existing sales and usage records come through the '
    'migration as not canceled, with no canceled_at',
    () async {
      final schema = await verifier.schemaAt(12);
      addTearDown(schema.close);

      final oldDb = v12.DatabaseAtV12(schema.newConnection());
      final saleId = await oldDb.into(oldDb.sales).insert(
        v12.SalesCompanion.insert(
          totalAmount: 24,
          discount: const Value(1),
          finalAmount: 23,
          date: 1704067200,
        ),
      );
      final usageId = await oldDb.into(oldDb.productMaterials).insert(
        v12.ProductMaterialsCompanion.insert(
          productId: 1,
          materialId: 1,
          quantityUsed: 0.5,
        ),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(checkDb.close);

      final sale = await (checkDb.select(
        checkDb.sales,
      )..where((s) => s.id.equals(saleId))).getSingle();
      expect(sale.isCanceled, 0); // booleano: 0 = false
      expect(sale.canceledAt, isNull);
      expect(sale.finalAmount, 23); // el resto de la fila no cambia

      final usage = await (checkDb.select(
        checkDb.productMaterials,
      )..where((pm) => pm.id.equals(usageId))).getSingle();
      expect(usage.isCanceled, 0); // booleano: 0 = false
      expect(usage.canceledAt, isNull);
      expect(usage.quantityUsed, 0.5);
    },
  );

  test(
    'Cancelation columns: a v8 database (product_materials recreated on the '
    'way) reaches v14 with the usage record intact and not canceled',
    () async {
      final schema = await verifier.schemaAt(8);
      addTearDown(schema.close);

      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      await oldDb.into(oldDb.productMaterials).insert(
        v8.ProductMaterialsCompanion.insert(
          productId: 1,
          materialId: 1,
          quantityUsed: 3,
        ),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(checkDb.close);

      final usage = await checkDb.select(checkDb.productMaterials).getSingle();
      expect(usage.quantityUsed, 3);
      expect(usage.isCanceled, 0); // booleano: 0 = false
    },
  );

  // --- v13 -> v14: eventos con estado (events.is_active) y registros
  // predeterminados que no pueden quedar desactivados ---
  test(
    'Events: existing events come through the migration active (they had no '
    'status before)',
    () async {
      final schema = await verifier.schemaAt(13);
      addTearDown(schema.close);

      final oldDb = v13.DatabaseAtV13(schema.newConnection());
      final eventId = await oldDb.into(oldDb.events).insert(
        v13.EventsCompanion.insert(name: 'Feria', startDate: 1704067200),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(checkDb.close);

      final event = await (checkDb.select(
        checkDb.events,
      )..where((e) => e.id.equals(eventId))).getSingle();
      expect(event.isActive, 1); // booleano: 1 = true
      expect(event.name, 'Feria');
    },
  );

  test(
    'Default records: a "Sin categoría" / "Sin nombre" / "Sin proveedor" that '
    'was deactivated in an older version is re-activated, and other inactive '
    'records are left alone',
    () async {
      final schema = await verifier.schemaAt(13);
      addTearDown(schema.close);

      final oldDb = v13.DatabaseAtV13(schema.newConnection());
      await oldDb.into(oldDb.categories).insert(
        v13.CategoriesCompanion.insert(
          name: 'Sin categoría',
          isActive: const Value(0),
        ),
      );
      final otherCategoryId = await oldDb.into(oldDb.categories).insert(
        v13.CategoriesCompanion.insert(
          name: 'Bisutería',
          isActive: const Value(0),
        ),
      );
      await oldDb.into(oldDb.clients).insert(
        v13.ClientsCompanion.insert(
          name: 'Sin nombre',
          isActive: const Value(0),
        ),
      );
      await oldDb.into(oldDb.suppliers).insert(
        v13.SuppliersCompanion.insert(
          name: 'Sin proveedor',
          isActive: const Value(0),
        ),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(checkDb.close);

      final categories = {
        for (final c in await checkDb.select(checkDb.categories).get())
          c.name: c.isActive,
      };
      expect(categories['Sin categoría'], 1);
      expect(categories['Bisutería'], 0); // una inactiva cualquiera no se toca
      expect(otherCategoryId, isNonZero);

      final client = await checkDb.select(checkDb.clients).getSingle();
      expect(client.isActive, 1);
      final supplier = await checkDb.select(checkDb.suppliers).getSingle();
      expect(supplier.isActive, 1);
    },
  );

  // --- v14 -> v15: nuevas unidades sembradas ---
  test(
    'Units: an existing install gets the five new units, keeps its existing '
    'ones (same ids), and nothing is duplicated',
    () async {
      final schema = await verifier.schemaAt(14);
      addTearDown(schema.close);

      final oldDb = v14.DatabaseAtV14(schema.newConnection());
      final metroId = await oldDb.into(oldDb.units).insert(
        v14.UnitsCompanion.insert(name: 'metro', type: 'medida'),
      );
      // Una unidad que la instalación ya tenía con otra capitalización:
      // se respeta y no se vuelve a sembrar como "tira".
      final tiraId = await oldDb.into(oldDb.units).insert(
        v14.UnitsCompanion.insert(name: 'Tira', type: 'contenedor'),
      );
      await oldDb.close();

      final dbForMigration = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(dbForMigration, 15);
      await dbForMigration.close();

      final checkDb = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(checkDb.close);

      final rows = await checkDb.select(checkDb.units).get();
      final byName = {for (final u in rows) u.name: u};

      // Las existentes conservan su id.
      expect(byName['metro']!.id, metroId);
      expect(byName['Tira']!.id, tiraId);
      // "tira" no se duplicó con otra capitalización.
      expect(rows.where((u) => u.name.toLowerCase() == 'tira'), hasLength(1));
      // Las cuatro medidas nuevas se agregaron.
      for (final name in ['centímetro', 'milímetro', 'mililitro', 'metro cuadrado']) {
        expect(byName[name]?.type, 'medida', reason: name);
      }
      // Cada nombre aparece una sola vez.
      expect(rows.map((u) => u.name.toLowerCase()).toSet(), hasLength(rows.length));
    },
  );

  test('Roles: a fresh install seeds "empleado" and no "usuario" role', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final names = (await db.select(db.roles).get()).map((r) => r.name).toList();
    expect(names, unorderedEquals(['admin', 'propietario', 'empleado']));
  });
}
