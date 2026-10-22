import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/unit_model.dart';

class UnitRepository {
  final AppDatabase database;

  UnitRepository(this.database);

  UnitModel _toModel(Unit row) {
    return UnitModel(id: row.id, name: row.name, type: row.type);
  }

  Future<List<UnitModel>> getAll() async {
    final rows = await (database.select(
      database.units,
    )..orderBy([(u) => OrderingTerm.asc(u.id)])).get();
    final order = AppDatabase.unitDisplayOrder;
    int position(Unit u) {
      final i = order.indexOf(u.name.toLowerCase());
      return i < 0 ? order.length : i;
    }

    rows.sort((a, b) {
      final byPosition = position(a).compareTo(position(b));
      return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
    });
    return rows.map(_toModel).toList();
  }
}
