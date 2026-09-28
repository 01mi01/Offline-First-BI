import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/unit_model.dart';

class UnitRepository {
  final AppDatabase database;

  UnitRepository(this.database);

  // Convierte fila de la base de datos a modelo
  UnitModel _toModel(Unit row) {
    return UnitModel(id: row.id, name: row.name, type: row.type);
  }

  // Obtiene todas las unidades (datos de referencia, sembrados por la app)
  Future<List<UnitModel>> getAll() async {
    final rows = await (database.select(
      database.units,
    )..orderBy([(u) => OrderingTerm.asc(u.name)])).get();
    return rows.map(_toModel).toList();
  }
}
