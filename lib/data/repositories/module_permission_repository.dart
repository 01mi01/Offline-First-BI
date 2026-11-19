import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../db/audit_log.dart';
import '../../config/app_clock.dart';
import '../../models/access_control.dart';

class ModulePermissionRepository {
  final AppDatabase database;

  ModulePermissionRepository(this.database);

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

  Future<Map<AppModule, PermissionSet>> getPermissions(int userId) async {
    final query = database.select(database.modulePermissions).join([
      innerJoin(
        database.modules,
        database.modules.id.equalsExp(database.modulePermissions.moduleId),
      ),
    ])..where(database.modulePermissions.userId.equals(userId));
    final rows = await query.get();
    final result = <AppModule, PermissionSet>{};
    for (final row in rows) {
      final module = AppModule.fromDbName(
        row.readTable(database.modules).name,
      );
      if (module == null) continue;
      final p = row.readTable(database.modulePermissions);
      result[module] = PermissionSet(
        create: p.canCreate,
        read: p.canRead,
        update: p.canUpdate,
        deactivate: p.canDelete,
      );
    }
    return result;
  }

  Future<void> savePermissions(
    int userId,
    Map<AppModule, PermissionSet> permissions,
  ) async {
    await database.transaction(() async {
      final before = await database.auditPermissions(userId);
      final modules = await database.select(database.modules).get();
      final moduleIds = {for (final m in modules) m.name: m.id};
      final now = appNow();
      for (final entry in permissions.entries) {
        final module = entry.key;
        if (!module.commercial) continue;
        final moduleId = moduleIds[module.dbName];
        if (moduleId == null) continue;
        final p = entry.value;
        final companion = ModulePermissionsCompanion(
          canRead: Value(p.read),
          canCreate: module.readOnly ? const Value.absent() : Value(p.create),
          canUpdate: module.readOnly ? const Value.absent() : Value(p.update),
          canDelete: module.readOnly
              ? const Value.absent()
              : Value(p.deactivate),
          updatedAt: Value(now),
        );
        final updated =
            await (database.update(database.modulePermissions)..where(
                  (mp) =>
                      mp.userId.equals(userId) & mp.moduleId.equals(moduleId),
                ))
                .write(companion);
        if (updated == 0) {
          await database
              .into(database.modulePermissions)
              .insert(
                companion.copyWith(
                  userId: Value(userId),
                  moduleId: Value(moduleId),
                ),
              );
        }
      }
      await database.recordChange(
        module: AuditModule.usuarios,
        entity: 'module_permissions',
        id: userId,
        before: before,
        action: AuditAction.permissionsUpdate,
        label: (await (database.select(
          database.users,
        )..where((u) => u.id.equals(userId))).getSingleOrNull())?.username,
        after: () => database.auditPermissions(userId),
      );
    });
  }
}
