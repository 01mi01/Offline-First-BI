import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/supplier_model.dart';

class SupplierRepository {
  final AppDatabase database;

  SupplierRepository(this.database);

  // Convierte fila a modelo
  SupplierModel _toModel(Supplier row) {
    return SupplierModel(
      id: row.id,
      name: row.name,
      contactInfo: row.contactInfo,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  // Obtiene todos los proveedores incluyendo inactivos
  Future<List<SupplierModel>> getAllIncludingInactive() async {
    final rows = await (database.select(
      database.suppliers,
    )..orderBy([(s) => OrderingTerm.asc(s.name)])).get();
    return rows.map(_toModel).toList();
  }

  // Obtiene solo proveedores activos para dropdowns
  Future<List<SupplierModel>> getActive() async {
    final rows =
        await (database.select(database.suppliers)
              ..where((s) => s.isActive.equals(true))
              ..orderBy([(s) => OrderingTerm.asc(s.name)]))
            .get();
    return rows.map(_toModel).toList();
  }

  // Guarda o actualiza un proveedor
  Future<int> save({
    int? id,
    required String name,
    String? contactInfo,
    bool isActive = true,
  }) async {
    // Verifica nombre único excluyendo el registro actual
    final existing = await (database.select(
      database.suppliers,
    )..where((s) => s.name.equals(name))).getSingleOrNull();
    if (existing != null && existing.id != id) {
      throw Exception('Ya existe un proveedor con ese nombre');
    }
    final now = DateTime.now();
    return await database
        .into(database.suppliers)
        .insertOnConflictUpdate(
          SuppliersCompanion(
            id: id != null ? Value(id) : const Value.absent(),
            name: Value(name),
            contactInfo: Value(contactInfo),
            isActive: Value(isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }
}
