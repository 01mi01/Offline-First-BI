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

  // Obtiene todas las unidades (datos de referencia, sembrados por la app), en
  // el orden en que se sembraron (contenedor, paquete, rollo, tira, unidad...)
  // y no alfabético. En una base nueva coincide con el id; en una migrada los
  // ids conservan el orden antiguo, por eso se ordena por la posición en la
  // semilla. Una unidad que no esté en la semilla queda al final, por id.
  Future<List<UnitModel>> getAll() async {
    final rows = await (database.select(
      database.units,
    )..orderBy([(u) => OrderingTerm.asc(u.id)])).get();
    final order = AppDatabase.unitDisplayOrder;
    int position(Unit u) {
      final i = order.indexOf(u.name.toLowerCase());
      return i < 0 ? order.length : i;
    }

    // sort de Dart no es estable: el id desempata explícitamente.
    rows.sort((a, b) {
      final byPosition = position(a).compareTo(position(b));
      return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
    });
    return rows.map(_toModel).toList();
  }
}
