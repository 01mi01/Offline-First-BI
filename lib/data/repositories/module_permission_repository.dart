import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';

class ModulePermissionRepository {
  final AppDatabase database;

  ModulePermissionRepository(this.database);

  // Obtiene los nombres de los módulos donde el usuario tiene permiso de lectura
  Future<List<String>> getReadableModuleNames(int userId) async {
    final query = database.select(database.modulePermissions).join([
      innerJoin(
        database.modules,
        database.modules.id.equalsExp(database.modulePermissions.moduleId),
      ),
    ])..where(
      database.modulePermissions.userId.equals(userId) &
          database.modulePermissions.canRead.equals(true),
    );

    final rows = await query.get();
    return rows.map((row) => row.readTable(database.modules).name).toList();
  }
}
