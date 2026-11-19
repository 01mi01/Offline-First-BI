import 'package:drift/drift.dart' show Value;
import '../../config/app_clock.dart';
import '../db/app_database.dart';
import '../db/audit_log.dart';

class ThemePreferenceRepository {
  final AppDatabase database;

  ThemePreferenceRepository(this.database);

  Future<bool> isDarkMode(int userId) async {
    final user = await (database.select(
      database.users,
    )..where((u) => u.id.equals(userId))).getSingleOrNull();
    return user?.darkMode ?? false;
  }

  Future<void> setDarkMode(
    int userId,
    bool darkMode, {
    String? previousTheme,
    String? theme,
  }) async {
    await database.transaction(() async {
      await (database.update(
        database.users,
      )..where((u) => u.id.equals(userId))).write(
        UsersCompanion(darkMode: Value(darkMode), updatedAt: Value(appNow())),
      );
      if (theme != null && theme != previousTheme) {
        await database.recordAudit(
          module: AuditModule.ajustes,
          action: AuditAction.themeUpdate,
          entity: 'users',
          recordId: userId,
          label: database.auditActor.username,
          before: {'theme': previousTheme},
          after: {'theme': theme},
        );
      }
    });
  }
}
