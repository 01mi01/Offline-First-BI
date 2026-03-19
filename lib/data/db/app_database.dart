import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;

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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class UserRoles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get roleId => integer().references(Roles, #id)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, roleId}
      ];
}

class Modules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class ModulePermissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get moduleId => integer().references(Modules, #id)();
  BoolColumn get hasAccess => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, moduleId}
      ];
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().nullable()();
  TextColumn get image => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id).nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get image => text().nullable()();
  RealColumn get salePrice => real()();
  RealColumn get productionCost => real().nullable()();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Materials extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get stock => real().withDefault(const Constant(0))();
  RealColumn get pricePerUnit => real()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class ProductMaterials extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get materialId => integer().references(Materials, #id)();
  RealColumn get quantityUsed => real()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {productId, materialId}
      ];
}

class Locations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get city => text()();
  TextColumn get country => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get contactInfo => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get contactInfo => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get subtotal => real()();
}

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id).nullable()();
  IntColumn get locationId => integer().references(Locations, #id).nullable()();
  BoolColumn get isMaterial => boolean().withDefault(const Constant(true))();
  TextColumn get description => text().nullable()();
  RealColumn get totalAmount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
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
}

class SavedReports extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get name => text()();
  TextColumn get filters => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Base de datos

@DriftDatabase(tables: [
  Users,
  Roles,
  UserRoles,
  Modules,
  ModulePermissions,
  Categories,
  Products,
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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDatosIniciales();
    },
  );

  Future<void> _insertDatosIniciales() async {
    // Roles del sistema
    await batch((b) {
      b.insertAll(roles, [
        RolesCompanion.insert(name: 'admin'),
        RolesCompanion.insert(name: 'propietario'),
        RolesCompanion.insert(name: 'usuario'),
      ]);
    });

    // Módulos del sistema
    await batch((b) {
      b.insertAll(modules, [
        ModulesCompanion.insert(name: 'inventario'),
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

    // Contraseña de prueba: 123456
    final passwordHash = _hashPassword('123456');

    // Usuario de prueba con rol usuario
    final testUserId = await into(users).insert(
      UsersCompanion.insert(
        username: 'usuario_prueba',
        email: 'prueba@test.com',
        passwordHash: passwordHash,
      ),
    );

    // Rol usuario para el usuario de prueba
    final rolUsuario = await (select(roles)..where((r) => r.name.equals('usuario'))).getSingle();

    await into(userRoles).insert(
      UserRolesCompanion.insert(userId: testUserId, roleId: rolUsuario.id),
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
