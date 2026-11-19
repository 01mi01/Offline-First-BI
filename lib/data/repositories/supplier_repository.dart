import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../db/audit_log.dart';
import '../../models/default_records.dart';
import '../../models/supplier_model.dart';
import '../../config/app_clock.dart';
import 'name_rules.dart';

class SupplierRepository {
  final AppDatabase database;

  SupplierRepository(this.database);

  SupplierModel _toModel(Supplier row) {
    return SupplierModel(
      id: row.id,
      name: row.name,
      contactInfo: row.contactInfo,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  Future<List<SupplierModel>> getAllIncludingInactive() async {
    final rows = await (database.select(
      database.suppliers,
    )..orderBy([(s) => OrderingTerm.asc(s.name)])).get();
    return rows.map(_toModel).toList();
  }

  Future<List<SupplierModel>> getActive() async {
    final rows =
        await (database.select(database.suppliers)
              ..where((s) => s.isActive.equals(true))
              ..orderBy([(s) => OrderingTerm.asc(s.name)]))
            .get();
    return rows.map(_toModel).toList();
  }

  Future<int> save({
    int? id,
    required String name,
    String? contactInfo,
    bool isActive = true,
  }) async {
    name = requireName(name);
    return database.transaction(() async {
      if (id != null) {
        final current = await (database.select(
          database.suppliers,
        )..where((s) => s.id.equals(id))).getSingleOrNull();
        if (current != null && DefaultRecords.isSupplier(current.name)) {
          throw const ProtectedRecordException(
            DefaultRecords.protectedSupplierMessage,
          );
        }
      }
      if (DefaultRecords.isSupplier(name)) {
        throw const ProtectedRecordException(
          DefaultRecords.reservedNameMessage,
        );
      }
      final existing = await (database.select(
        database.suppliers,
      )..where((s) => s.name.equals(name))).getSingleOrNull();
      if (existing != null && existing.id != id) {
        throw Exception('Ya existe un proveedor con ese nombre');
      }
      final before = await database.auditRow('suppliers', id);
      final now = appNow();
      final newId = await database
          .into(database.suppliers)
          .insertOnConflictUpdate(
            SuppliersCompanion(
              id: id != null ? Value(id) : const Value.absent(),
              name: Value(name),
              contactInfo: Value(contactInfo),
              isActive: Value(isActive),
              createdAt: id == null ? Value(now) : const Value.absent(),
              updatedAt: Value(now),
            ),
          );
      final savedId = id ?? newId;
      await database.recordChange(
        module: AuditModule.proveedores,
        entity: 'suppliers',
        id: savedId,
        before: before,
      );
      return savedId;
    });
  }
}
