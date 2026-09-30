import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import '../../config/app_config.dart';
import '../../models/default_records.dart';

part 'app_database.g.dart';

// Tablas

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().unique()();
  TextColumn get email => text().unique()();
  TextColumn get passwordHash => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get mfaEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get darkMode => boolean().withDefault(const Constant(false))();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class UserRoles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get roleId => integer().references(Roles, #id)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, roleId},
  ];
}

class Modules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class ModulePermissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get moduleId => integer().references(Modules, #id)();
  BoolColumn get canCreate => boolean().withDefault(const Constant(false))();
  BoolColumn get canRead => boolean().withDefault(const Constant(false))();
  BoolColumn get canUpdate => boolean().withDefault(const Constant(false))();
  BoolColumn get canDelete => boolean().withDefault(const Constant(false))();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, moduleId},
  ];
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().nullable()();
  TextColumn get image => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get image => text().nullable()();
  RealColumn get priceA => real()();
  RealColumn get priceB => real()();
  RealColumn get productionCost => real().nullable()();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

// Unidades de medida para materiales. "type" clasifica el comportamiento de
// entrada de cantidad: "contenedor" (contenedor, paquete, rollo, tira) admite
// fracciones simples, "medida" (metro, kg...) y "otros" (comodín) usan un
// número plano.
class Units extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get type => text()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Materials extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get unitId => integer().references(Units, #id)();
  RealColumn get stock => real().withDefault(const Constant(0))();
  RealColumn get pricePerUnit => real()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class ProductMaterials extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get materialId => integer().references(Materials, #id)();
  RealColumn get quantityUsed => real()();
  // Un registro cancelado ya no descuenta stock (se devolvió al cancelarlo)
  // pero se conserva como historial; el par producto+material sigue siendo
  // único, así que volver a registrar el uso reactiva esta misma fila.
  BoolColumn get isCanceled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get canceledAt => dateTime().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {productId, materialId},
  ];
}

class Locations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get city => text()();
  TextColumn get country => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get contactInfo => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get contactInfo => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get locationId => integer().references(Locations, #id).nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id).nullable()();
  IntColumn get locationId => integer().references(Locations, #id).nullable()();
  IntColumn get eventId => integer().references(Events, #id).nullable()();
  RealColumn get totalAmount => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get finalAmount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  // Una venta cancelada se conserva como historial: su stock ya fue devuelto
  // y no cuenta como ingreso ni se puede seguir editando.
  BoolColumn get isCanceled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get canceledAt => dateTime().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  TextColumn get priceType => text().withDefault(const Constant('A'))();
  RealColumn get subtotal => real()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id).nullable()();
  IntColumn get locationId => integer().references(Locations, #id).nullable()();
  IntColumn get eventId => integer().references(Events, #id).nullable()();
  BoolColumn get isMaterial => boolean().withDefault(const Constant(true))();
  TextColumn get description => text().nullable()();
  RealColumn get totalAmount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().references(Purchases, #id)();
  IntColumn get materialId => integer().references(Materials, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get subtotal => real()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class SavedReports extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get name => text()();
  TextColumn get filters => text()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get moduleName => text()();
  TextColumn get action => text()();
  TextColumn get entityType => text().nullable()();
  IntColumn get recordId => integer().nullable()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get supabaseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

// Tablas que se agregaron para el desarrollo
class SesionLocal extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get username => text()();
  BoolColumn get activa => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
}

// Base de datos

@DriftDatabase(
  tables: [
    Users,
    Roles,
    UserRoles,
    Modules,
    ModulePermissions,
    Categories,
    Products,
    Units,
    Materials,
    ProductMaterials,
    Locations,
    Suppliers,
    Clients,
    Events,
    Sales,
    SaleItems,
    Purchases,
    PurchaseItems,
    SavedReports,
    AuditLogs,
    SesionLocal,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Constructor para pruebas: permite inyectar un QueryExecutor (p. ej. NativeDatabase.memory())
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 16;

  // Nombre del proveedor por defecto: las compras sin proveedor elegido se
  // asignan a él (mismo patrón que la categoría "Sin categoría" de productos).
  static const String defaultSupplierName = DefaultRecords.supplier;

  // Semilla de unidades vigente: nombre + tipo ("contenedor" admite fracciones
  // simples en la UI, "medida"/"otros" usan un número plano). Se usa al crear
  // la base desde cero y al migrar a la versión 16.
  static const List<(String, String)> _unitSeeds = [
    ('contenedor', 'contenedor'),
    ('paquete', 'contenedor'),
    ('rollo', 'contenedor'),
    ('tira', 'contenedor'),
    ('unidad', 'medida'),
    ('metro', 'medida'),
    ('centímetro', 'medida'),
    ('kg', 'medida'),
    ('gramo', 'medida'),
    ('litro', 'medida'),
    ('mililitro', 'medida'),
    ('otro', 'otros'),
  ];

  // Lista que se sembraba hasta la versión 15. Los pasos de migración
  // antiguos (versiones 10 y 15) siguen usándola para dejar la base como estaba
  // en su momento; el paso a la versión 16 la reduce a [_unitSeeds].
  static const List<(String, String)> _legacyUnitSeeds = [
    ('botella', 'contenedor'),
    ('bolsa', 'contenedor'),
    ('paquete', 'contenedor'),
    ('caja', 'contenedor'),
    ('frasco', 'contenedor'),
    ('lata', 'contenedor'),
    ('rollo', 'contenedor'),
    ('unidad', 'medida'),
    ('metro', 'medida'),
    ('litro', 'medida'),
    ('kg', 'medida'),
    ('gramo', 'medida'),
    ('centímetro', 'medida'),
    ('milímetro', 'medida'),
    ('mililitro', 'medida'),
    ('metro cuadrado', 'medida'),
    ('tira', 'contenedor'),
    ('otro', 'otros'),
  ];

  // Unidades retiradas en la versión 16 y la unidad que las reemplaza. Solo
  // cambia el unitId de los materiales; las compras, ventas y usos que los
  // referencian no se tocan.
  static const Map<String, String> _retiredUnitReplacements = {
    'botella': 'contenedor',
    'frasco': 'contenedor',
    'lata': 'contenedor',
    'bolsa': 'contenedor',
    'caja': 'contenedor',
    'milímetro': 'centímetro',
    'metro cuadrado': 'metro',
  };

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDatosIniciales();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.deleteTable('product_materials');
        await m.createTable(productMaterials);
      }
      if (from < 3) {
        await m.createTable(sesionLocal);
      }
      if (from < 4) {
        final existing = await (select(
          clients,
        )..where((c) => c.name.equals('Sin nombre'))).getSingleOrNull();
        if (existing == null) {
          await into(clients).insert(
            ClientsCompanion.insert(
              name: 'Sin nombre',
              isActive: const Value(true),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
      if (from < 5) {
        final existing = await (select(
          suppliers,
        )..where((s) => s.name.equals('Sin nombre'))).getSingleOrNull();
        if (existing == null) {
          await into(suppliers).insert(
            SuppliersCompanion.insert(
              name: 'Sin nombre',
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
      if (from < 6) {
        await (update(suppliers)..where((s) => s.name.equals('Sin proveedor')))
            .write(SuppliersCompanion(name: const Value('Sin nombre')));
      }
      if (from < 8) {
        // El módulo "materiales" antes vivía solo dentro de "inventario";
        // ahora es su propio módulo independiente.
        final existingMateriales = await (select(
          modules,
        )..where((mo) => mo.name.equals('materiales'))).getSingleOrNull();
        if (existingMateriales == null) {
          await into(modules).insert(ModulesCompanion.insert(name: 'materiales'));
        }

        // module_permissions pasa de un único booleano hasAccess a cuatro
        // banderas CRUD; la tabla nunca llegó a usarse, así que se recrea
        // igual que product_materials en la migración de la versión 2.
        await m.deleteTable('module_permissions');
        await m.createTable(modulePermissions);

        // Otorga acceso CRUD completo a todos los usuarios existentes sobre
        // todos los módulos (incluyendo el nuevo "materiales"), preservando
        // el acceso total que tenían implícitamente antes de que el sistema
        // de permisos empezara a aplicarse.
        final allUsers = await select(users).get();
        final allModules = await select(modules).get();
        await batch((b) {
          b.insertAll(modulePermissions, [
            for (final u in allUsers)
              for (final mod in allModules)
                ModulePermissionsCompanion.insert(
                  userId: u.id,
                  moduleId: mod.id,
                  canCreate: const Value(true),
                  canRead: const Value(true),
                  canUpdate: const Value(true),
                  canDelete: const Value(true),
                ),
          ]);
        });
      }
      if (from < 9) {
        // --- sincronizado + supabaseId en todas las tablas excepto
        // SesionLocal (preparación de esquema para una futura sincronización
        // con Supabase; todavía no hay lógica de sync, solo las columnas) ---
        await m.addColumn(users, users.sincronizado);
        await m.addColumn(users, users.supabaseId);
        await m.addColumn(roles, roles.sincronizado);
        await m.addColumn(roles, roles.supabaseId);
        await m.addColumn(userRoles, userRoles.sincronizado);
        await m.addColumn(userRoles, userRoles.supabaseId);
        await m.addColumn(modules, modules.sincronizado);
        await m.addColumn(modules, modules.supabaseId);
        await m.addColumn(categories, categories.sincronizado);
        await m.addColumn(categories, categories.supabaseId);
        await m.addColumn(products, products.sincronizado);
        await m.addColumn(products, products.supabaseId);
        await m.addColumn(materials, materials.sincronizado);
        await m.addColumn(materials, materials.supabaseId);
        await m.addColumn(locations, locations.sincronizado);
        await m.addColumn(locations, locations.supabaseId);
        await m.addColumn(suppliers, suppliers.sincronizado);
        await m.addColumn(suppliers, suppliers.supabaseId);
        await m.addColumn(clients, clients.sincronizado);
        await m.addColumn(clients, clients.supabaseId);
        await m.addColumn(events, events.sincronizado);
        await m.addColumn(events, events.supabaseId);
        await m.addColumn(sales, sales.sincronizado);
        await m.addColumn(sales, sales.supabaseId);
        await m.addColumn(saleItems, saleItems.sincronizado);
        await m.addColumn(saleItems, saleItems.supabaseId);
        await m.addColumn(purchases, purchases.sincronizado);
        await m.addColumn(purchases, purchases.supabaseId);
        await m.addColumn(purchaseItems, purchaseItems.sincronizado);
        await m.addColumn(purchaseItems, purchaseItems.supabaseId);
        await m.addColumn(savedReports, savedReports.sincronizado);
        await m.addColumn(savedReports, savedReports.supabaseId);
        await m.addColumn(auditLogs, auditLogs.sincronizado);
        await m.addColumn(auditLogs, auditLogs.supabaseId);
        // product_materials y module_permissions ya nacieron con estas
        // columnas si el dispositivo pasó por la recreación de tabla de la
        // migración de versión 2 u 8 respectivamente (ambas usan la
        // definición Dart actual al recrear); solo hace falta agregarlas
        // aquí si la tabla viene de antes de esa recreación.
        if (from >= 2) {
          await m.addColumn(productMaterials, productMaterials.sincronizado);
          await m.addColumn(productMaterials, productMaterials.supabaseId);
        }
        if (from >= 8) {
          await m.addColumn(modulePermissions, modulePermissions.sincronizado);
          await m.addColumn(modulePermissions, modulePermissions.supabaseId);
        }

        // --- created_at / updated_at faltantes ---
        await m.addColumn(roles, roles.createdAt);
        await m.addColumn(roles, roles.updatedAt);
        await m.addColumn(userRoles, userRoles.createdAt);
        await m.addColumn(userRoles, userRoles.updatedAt);
        await m.addColumn(modules, modules.createdAt);
        await m.addColumn(modules, modules.updatedAt);
        await m.addColumn(saleItems, saleItems.createdAt);
        await m.addColumn(saleItems, saleItems.updatedAt);
        await m.addColumn(purchaseItems, purchaseItems.createdAt);
        await m.addColumn(purchaseItems, purchaseItems.updatedAt);
        await m.addColumn(savedReports, savedReports.updatedAt);
        await m.addColumn(auditLogs, auditLogs.updatedAt);
        if (from >= 8) {
          await m.addColumn(modulePermissions, modulePermissions.createdAt);
          await m.addColumn(modulePermissions, modulePermissions.updatedAt);
        }
        if (from >= 2) {
          await m.addColumn(productMaterials, productMaterials.updatedAt);
        }

        // --- Materials.unit ---
        // Se referencia por SQL crudo (no como materials.unit) porque esa
        // columna dejó de existir en la clase Dart: la migración de v10 la
        // reemplaza por materials.unitId (ver el bloque `if (from < 10)`).
        await customStatement(
          "ALTER TABLE materials ADD COLUMN unit TEXT NOT NULL DEFAULT 'unidad'",
        );

        // --- SaleItems.priceType (siempre "A" por ahora: todavía no existe
        // una UI para elegir entre precio A/B al momento de la venta) ---
        await m.addColumn(saleItems, saleItems.priceType);

        // --- Products: categoría obligatoria + price_a/price_b ---
        // Toda venta previa a este cambio usaba un único precio; se preserva
        // ese valor como price_a y price_b hasta que exista una UI para
        // diferenciarlos.
        final sinCategoria = await (select(
          categories,
        )..where((c) => c.name.equals('Sin categoría'))).getSingleOrNull();
        final sinCategoriaId =
            sinCategoria?.id ??
            await into(
              categories,
            ).insert(CategoriesCompanion.insert(name: 'Sin categoría'));

        await customStatement(
          'UPDATE products SET category_id = ? WHERE category_id IS NULL',
          [sinCategoriaId],
        );

        await m.alterTable(
          TableMigration(
            products,
            newColumns: [products.priceA, products.priceB],
            columnTransformer: {
              products.priceA: const CustomExpression<double>('sale_price'),
              products.priceB: const CustomExpression<double>('sale_price'),
            },
          ),
        );

        // --- ProductMaterials: índice único (productId, materialId) ---
        // La tabla dejó de ser un historial de uso (ver la vinculación en
        // MaterialRepository.registerMaterialUsage, que ahora actualiza la
        // fila existente en vez de insertar una nueva); antes de aplicar el
        // índice único se conserva solo la fila más reciente por par
        // producto+material y se descartan los duplicados.
        if (from >= 2) {
          await customStatement('''
            DELETE FROM product_materials
            WHERE id NOT IN (
              SELECT id FROM (
                SELECT id, ROW_NUMBER() OVER (
                  PARTITION BY product_id, material_id
                  ORDER BY COALESCE(updated_at, created_at) DESC, id DESC
                ) AS rn
                FROM product_materials
              ) WHERE rn = 1
            );
          ''');
        }
        await m.alterTable(
          TableMigration(
            productMaterials,
            newColumns: [
              productMaterials.isCanceled,
              productMaterials.canceledAt,
            ],
          ),
        );

        // --- SesionLocal.userId: de TextColumn a IntColumn con FK a Users ---
        await m.alterTable(
          TableMigration(
            sesionLocal,
            columnTransformer: {
              sesionLocal.userId: const CustomExpression<int>(
                'CAST(user_id AS INTEGER)',
              ),
            },
          ),
        );
      }
      if (from < 10) {
        // --- Materials.unit (texto libre) -> Materials.unitId (FK a Units) ---
        await m.createTable(units);
        await batch((b) {
          b.insertAll(units, [
            for (final (name, type) in _legacyUnitSeeds)
              UnitsCompanion.insert(name: name, type: type),
          ]);
        });

        // Cada material se mapea a la unidad sembrada cuyo nombre coincide
        // (sin distinguir mayúsculas) con su texto libre anterior; si no hay
        // coincidencia, cae en la unidad comodín "otro".
        await m.alterTable(
          TableMigration(
            materials,
            newColumns: [materials.unitId],
            columnTransformer: {
              materials.unitId: const CustomExpression<int>(
                "COALESCE("
                "(SELECT id FROM units WHERE LOWER(name) = LOWER(unit)), "
                "(SELECT id FROM units WHERE name = 'otro')"
                ")",
              ),
            },
          ),
        );
      }
      if (from < 11) {
        // El proveedor por defecto pasa de llamarse "Sin nombre" a
        // "Sin proveedor". Si el usuario ya tiene uno con el nombre nuevo se
        // respeta y no se toca nada; si no existe ninguno se crea.
        final alreadyRenamed = await (select(
          suppliers,
        )..where((s) => s.name.equals(defaultSupplierName))).getSingleOrNull();
        if (alreadyRenamed == null) {
          final legacyDefault =
              await (select(suppliers)
                    ..where((s) => s.name.equals('Sin nombre'))
                    ..orderBy([(s) => OrderingTerm.asc(s.id)])
                    ..limit(1))
                  .getSingleOrNull();
          if (legacyDefault != null) {
            await (update(suppliers)
                  ..where((s) => s.id.equals(legacyDefault.id)))
                .write(
                  SuppliersCompanion(
                    name: Value(defaultSupplierName),
                    updatedAt: Value(DateTime.now()),
                  ),
                );
          } else {
            await into(suppliers).insert(
              SuppliersCompanion.insert(
                name: defaultSupplierName,
                createdAt: Value(DateTime.now()),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }
      }
      if (from < 12) {
        // El rol sembrado "usuario" pasa a llamarse "empleado". Se renombra
        // en el mismo registro (mismo id) para que user_roles siga apuntando
        // a él. Roles.name es único: si ya existe un "empleado" no se toca
        // nada, para no violar la restricción.
        final alreadyRenamed = await (select(
          roles,
        )..where((r) => r.name.equals('empleado'))).getSingleOrNull();
        if (alreadyRenamed == null) {
          await (update(roles)..where((r) => r.name.equals('usuario'))).write(
            RolesCompanion(
              name: const Value('empleado'),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
      if (from < 13) {
        // Cancelación de ventas y de registros de uso de material (en vez de
        // borrarlos): se conservan como historial con su estado.
        await m.addColumn(sales, sales.isCanceled);
        await m.addColumn(sales, sales.canceledAt);
        // Desde la versión 9 product_materials se recrea con la definición
        // vigente (ya trae estas columnas); solo hace falta agregarlas si la
        // tabla viene de una versión 9 o posterior.
        if (from >= 9) {
          await m.addColumn(productMaterials, productMaterials.isCanceled);
          await m.addColumn(productMaterials, productMaterials.canceledAt);
        }
      }
      if (from < 14) {
        // Los eventos ahora se pueden desactivar (antes no tenían estado).
        await m.addColumn(events, events.isActive);

        // Los registros predeterminados ya no se pueden desactivar. Si en una
        // versión anterior alguien desactivó alguno, se reactiva para que la
        // protección valga también para instalaciones existentes.
        await (update(categories)
              ..where((c) => c.name.equals(DefaultRecords.category)))
            .write(const CategoriesCompanion(isActive: Value(true)));
        await (update(clients)
              ..where((c) => c.name.equals(DefaultRecords.client)))
            .write(const ClientsCompanion(isActive: Value(true)));
        await (update(suppliers)
              ..where((s) => s.name.equals(DefaultRecords.supplier)))
            .write(const SuppliersCompanion(isActive: Value(true)));
      }
      if (from < 15) {
        // Nuevas unidades sembradas (centímetro, milímetro, mililitro, metro
        // cuadrado y tira). Solo se agregan las que faltan, para no chocar
        // con el nombre único ni duplicar las que ya existen.
        final existing = (await select(units).get())
            .map((u) => u.name.toLowerCase())
            .toSet();
        await batch((b) {
          b.insertAll(units, [
            for (final (name, type) in _legacyUnitSeeds)
              if (!existing.contains(name.toLowerCase()))
                UnitsCompanion.insert(name: name, type: type),
          ]);
        });
      }
      if (from < 16) {
        // Lista de unidades simplificada (12 en total). Primero se agregan las
        // que faltan (p. ej. "contenedor"); luego cada unidad retirada se
        // reemplaza en los materiales que la usan y se elimina.
        final existing = (await select(units).get())
            .map((u) => u.name.toLowerCase())
            .toSet();
        await batch((b) {
          b.insertAll(units, [
            for (final (name, type) in _unitSeeds)
              if (!existing.contains(name.toLowerCase()))
                UnitsCompanion.insert(name: name, type: type),
          ]);
        });

        final all = await select(units).get();
        int? idOf(String name) {
          for (final u in all) {
            if (u.name.toLowerCase() == name) return u.id;
          }
          return null;
        }

        for (final entry in _retiredUnitReplacements.entries) {
          final retiredId = idOf(entry.key);
          final replacementId = idOf(entry.value);
          if (retiredId == null || replacementId == null) continue;
          await (update(materials)..where((m) => m.unitId.equals(retiredId)))
              .write(MaterialsCompanion(unitId: Value(replacementId)));
          await (delete(units)..where((u) => u.id.equals(retiredId))).go();
        }
      }
    },
  );

  Future<void> _insertDatosIniciales() async {
    // Roles del sistema
    await batch((b) {
      b.insertAll(roles, [
        RolesCompanion.insert(name: 'admin'),
        RolesCompanion.insert(name: 'propietario'),
        RolesCompanion.insert(name: 'empleado'),
      ]);
    });

    // Módulos del sistema
    await batch((b) {
      b.insertAll(modules, [
        ModulesCompanion.insert(name: 'inventario'),
        ModulesCompanion.insert(name: 'materiales'),
        ModulesCompanion.insert(name: 'ventas'),
        ModulesCompanion.insert(name: 'compras'),
        ModulesCompanion.insert(name: 'clientes'),
        ModulesCompanion.insert(name: 'proveedores'),
        ModulesCompanion.insert(name: 'eventos'),
        ModulesCompanion.insert(name: 'reportes'),
        ModulesCompanion.insert(name: 'business_intelligence'),
        ModulesCompanion.insert(name: 'auditoria'),
        ModulesCompanion.insert(name: 'usuarios'),
      ]);
    });

    // Usuario de prueba (opcional), definido vía --dart-define-from-file.
    // Ver config/dev.json y config/prod.json.example.
    if (AppConfig.seedUsername.isNotEmpty &&
        AppConfig.seedUserEmail.isNotEmpty &&
        AppConfig.seedUserPassword.isNotEmpty) {
      final passwordHash = _hashPassword(AppConfig.seedUserPassword);

      final testUserId = await into(users).insert(
        UsersCompanion.insert(
          username: AppConfig.seedUsername,
          email: AppConfig.seedUserEmail,
          passwordHash: passwordHash,
        ),
      );

      // Rol empleado para el usuario de prueba
      final rolEmpleado = await (select(
        roles,
      )..where((r) => r.name.equals('empleado'))).getSingle();

      await into(userRoles).insert(
        UserRolesCompanion.insert(userId: testUserId, roleId: rolEmpleado.id),
      );

      // Permisos CRUD completos para el usuario de prueba en todos los módulos
      final allModules = await select(modules).get();
      await batch((b) {
        b.insertAll(modulePermissions, [
          for (final mod in allModules)
            ModulePermissionsCompanion.insert(
              userId: testUserId,
              moduleId: mod.id,
              canCreate: const Value(true),
              canRead: const Value(true),
              canUpdate: const Value(true),
              canDelete: const Value(true),
            ),
        ]);
      });
    }

    // Categoría por defecto para productos sin categoría asignada
    await into(categories).insert(
      CategoriesCompanion.insert(name: DefaultRecords.category),
    );

    // Unidades de medida para materiales
    await batch((b) {
      b.insertAll(units, [
        for (final (name, type) in _unitSeeds)
          UnitsCompanion.insert(name: name, type: type),
      ]);
    });

    // Cliente por defecto para ventas sin identificar
    await into(clients).insert(
      ClientsCompanion.insert(
        name: DefaultRecords.client,
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    // Proveedor por defecto para compras sin proveedor elegido
    await into(suppliers).insert(
      SuppliersCompanion.insert(
        name: defaultSupplierName,
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Genera hash SHA-256 de la contraseña
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Abre la conexión con la base de datos local
  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'offline_first_bi.db'));
      return NativeDatabase(file);
    });
  }
}
