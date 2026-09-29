import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/client_model.dart';
import '../../models/default_records.dart';

class ClientRepository {
  final AppDatabase database;

  ClientRepository(this.database);

  // Convierte fila a modelo
  ClientModel _toModel(Client row) {
    return ClientModel(
      id: row.id,
      name: row.name,
      contactInfo: row.contactInfo,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  // Obtiene todos los clientes incluyendo inactivos
  Future<List<ClientModel>> getAllIncludingInactive() async {
    final rows = await (database.select(
      database.clients,
    )..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
    return rows.map(_toModel).toList();
  }

  // Obtiene solo clientes activos para dropdowns
  Future<List<ClientModel>> getActive() async {
    final rows =
        await (database.select(database.clients)
              ..where((c) => c.isActive.equals(true))
              ..orderBy([(c) => OrderingTerm.asc(c.name)]))
            .get();
    return rows.map(_toModel).toList();
  }

  // Guarda o actualiza un cliente
  Future<int> save({
    int? id,
    required String name,
    String? contactInfo,
    bool isActive = true,
  }) async {
    // El cliente predeterminado no se puede editar ni desactivar, y ningún
    // otro cliente puede usar su nombre.
    if (id != null) {
      final current = await (database.select(
        database.clients,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (current != null && DefaultRecords.isClient(current.name)) {
        throw const ProtectedRecordException();
      }
    }
    if (DefaultRecords.isClient(name)) {
      throw const ProtectedRecordException(DefaultRecords.reservedNameMessage);
    }
    // Verifica nombre único excluyendo el registro actual
    final existing = await (database.select(
      database.clients,
    )..where((c) => c.name.equals(name))).getSingleOrNull();
    if (existing != null && existing.id != id) {
      throw Exception('Ya existe un cliente con ese nombre');
    }
    final now = DateTime.now();
    return await database
        .into(database.clients)
        .insertOnConflictUpdate(
          ClientsCompanion(
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
