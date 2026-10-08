import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/location_model.dart';
import '../../config/app_clock.dart';

class LocationRepository {
  final AppDatabase database;

  LocationRepository(this.database);

  // Convierte fila a modelo
  LocationModel _toModel(Location row) {
    return LocationModel(
      id: row.id,
      city: row.city,
      country: row.country,
      description: row.description,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  // Obtiene todas las ubicaciones incluyendo inactivas
  Future<List<LocationModel>> getAllIncludingInactive() async {
    final rows = await (database.select(database.locations)
          ..orderBy([(l) => OrderingTerm.asc(l.city)]))
        .get();
    return rows.map(_toModel).toList();
  }

  // Obtiene solo ubicaciones activas para dropdowns
  Future<List<LocationModel>> getActive() async {
    final rows = await (database.select(database.locations)
          ..where((l) => l.isActive.equals(true))
          ..orderBy([(l) => OrderingTerm.asc(l.city)]))
        .get();
    return rows.map(_toModel).toList();
  }

  // Guarda o actualiza una ubicación
  Future<void> save({
    int? id,
    required String city,
    required String country,
    String? description,
    bool isActive = true,
  }) async {
    final now = appNow();
    await database.into(database.locations).insertOnConflictUpdate(
          LocationsCompanion(
            id: id != null ? Value(id) : const Value.absent(),
            city: Value(city),
            country: Value(country),
            description: Value(description),
            isActive: Value(isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }
}