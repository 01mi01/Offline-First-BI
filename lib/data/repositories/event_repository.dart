import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/event_model.dart';
import '../../config/app_clock.dart';

class EventRepository {
  final AppDatabase database;

  EventRepository(this.database);

  // Convierte fila a modelo
  EventModel _toModel(Event row) {
    return EventModel(
      id: row.id,
      name: row.name,
      locationId: row.locationId,
      startDate: row.startDate,
      endDate: row.endDate,
      notes: row.notes,
      createdAt: row.createdAt,
      isActive: row.isActive,
    );
  }

  // Obtiene todos los eventos (incluyendo inactivos) ordenados por fecha
  // descendente: la lista y los reportes los necesitan todos; los selectores
  // de ventas y compras filtran por isActive.
  Future<List<EventModel>> getAll() async {
    final rows = await (database.select(database.events)
          ..orderBy([(e) => OrderingTerm.desc(e.startDate)]))
        .get();
    return rows.map(_toModel).toList();
  }

  // Guarda o actualiza un evento
  Future<void> save({
    int? id,
    required String name,
    int? locationId,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
    bool isActive = true,
  }) async {
    final now = appNow();
    await database.into(database.events).insertOnConflictUpdate(
          EventsCompanion(
            id: id != null ? Value(id) : const Value.absent(),
            name: Value(name),
            locationId: Value(locationId),
            startDate: Value(startDate),
            endDate: Value(endDate),
            notes: Value(notes),
            isActive: Value(isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }
}