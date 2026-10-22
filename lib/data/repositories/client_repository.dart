import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/client_model.dart';
import '../../models/default_records.dart';
import '../../config/app_clock.dart';
import 'name_rules.dart';

class ClientRepository {
  final AppDatabase database;

  ClientRepository(this.database);

  ClientModel _toModel(Client row) {
    return ClientModel(
      id: row.id,
      name: row.name,
      contactInfo: row.contactInfo,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  Future<List<ClientModel>> getAllIncludingInactive() async {
    final rows = await (database.select(
      database.clients,
    )..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
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
          database.clients,
        )..where((c) => c.id.equals(id))).getSingleOrNull();
        if (current != null && DefaultRecords.isClient(current.name)) {
          throw const ProtectedRecordException(DefaultRecords.protectedClientMessage);
        }
      }
      if (DefaultRecords.isClient(name)) {
        throw const ProtectedRecordException(DefaultRecords.reservedNameMessage);
      }
      final existing = await (database.select(
        database.clients,
      )..where((c) => c.name.equals(name))).getSingleOrNull();
      if (existing != null && existing.id != id) {
        throw Exception('Ya existe un cliente con ese nombre');
      }
      final now = appNow();
      return await database
          .into(database.clients)
          .insertOnConflictUpdate(
            ClientsCompanion(
              id: id != null ? Value(id) : const Value.absent(),
              name: Value(name),
              contactInfo: Value(contactInfo),
              isActive: Value(isActive),
              createdAt: id == null ? Value(now) : const Value.absent(),
              updatedAt: Value(now),
            ),
          );
    });
  }
}
