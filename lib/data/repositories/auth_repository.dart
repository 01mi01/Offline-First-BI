import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'dart:convert';
import '../../data/db/app_database.dart';
import '../../models/user_model.dart';
import '../../config/app_clock.dart';
import '../../models/app_role.dart';
import 'failed_login_attempts.dart';

class AuthRepository {
  final AppDatabase database;
  final FailedLoginAttempts failedAttempts;
  final Set<String> _justLocked = {};

  AuthRepository(this.database, {FailedLoginAttempts? failedAttempts})
    : failedAttempts = failedAttempts ?? FailedLoginAttempts();

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<UserModel?> _buildUserModel(User user) async {
    final userRole = await (database.select(
      database.userRoles,
    )..where((ur) => ur.userId.equals(user.id))).getSingleOrNull();

    String role = 'empleado';
    if (userRole != null) {
      final roleData = await (database.select(
        database.roles,
      )..where((r) => r.id.equals(userRole.roleId))).getSingleOrNull();
      role = roleData?.name ?? 'empleado';
    }

    return UserModel(
      id: user.id,
      username: user.username,
      email: user.email,
      role: role,
      mfaEnabled: user.mfaEnabled,
      darkMode: user.darkMode,
      isActive: user.isActive,
    );
  }

  Future<UserModel?> login(String username, String password) async {
    try {
      final hash = _hashPassword(password);

      final user = await (database.select(
        database.users,
      )..where((u) => u.username.equals(username))).getSingleOrNull();

      if (user == null || !user.isActive) return null;
      if (user.passwordHash != hash) {
        await _registerFailure(user);
        return null;
      }

      failedAttempts.reset(user.username);

      await database.delete(database.sesionLocal).go();
      await database
          .into(database.sesionLocal)
          .insert(
            SesionLocalCompanion.insert(
              userId: user.id,
              username: user.username,
              createdAt: appNow(),
            ),
          );

      return await _buildUserModel(user);
    } catch (e) {
      return null;
    }
  }

  Future<void> _registerFailure(User user) async {
    final model = await _buildUserModel(user);
    if (model == null || model.appRole == AppRole.administrador) return;
    final count = failedAttempts.registerFailure(user.username);
    if (count < maxFailedLoginAttempts) return;
    await (database.update(database.users)..where((u) => u.id.equals(user.id)))
        .write(
          UsersCompanion(isActive: const Value(false), updatedAt: Value(appNow())),
        );
    _justLocked.add(user.username);
  }

  bool takeJustLocked(String username) => _justLocked.remove(username);

  Future<bool> isBlocked(String username, String password) async {
    final user = await (database.select(
      database.users,
    )..where((u) => u.username.equals(username))).getSingleOrNull();
    if (user == null) return false;
    return !user.isActive && user.passwordHash == _hashPassword(password);
  }

  Future<UserModel?> getSesionActual() async {
    try {
      final sesiones = await database.select(database.sesionLocal).get();
      if (sesiones.isEmpty) return null;

      final sesion = sesiones.first;

      final user =
          await (database.select(database.users)
                ..where((u) => u.id.equals(sesion.userId))
                ..where((u) => u.isActive.equals(true)))
              .getSingleOrNull();

      if (user == null) return null;

      return await _buildUserModel(user);
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    await database.delete(database.sesionLocal).go();
  }
}
