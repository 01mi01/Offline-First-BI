import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'dart:convert';
import '../../data/db/app_database.dart';
import '../../models/user_model.dart';
import '../../config/app_clock.dart';
import '../../models/access_control.dart';
import '../../models/app_role.dart';
import 'module_permission_repository.dart';
import 'failed_login_attempts.dart';
import '../services/totp.dart';
import '../db/audit_log.dart';

class TwoFactorChallenge {
  final int userId;
  final String username;

  const TwoFactorChallenge({required this.userId, required this.username});
}

class AuthRepository {
  final AppDatabase database;
  final FailedLoginAttempts failedAttempts;
  final FailedLoginAttempts failedCodeAttempts;
  final Set<String> _justLocked = {};
  final Map<String, TwoFactorChallenge> _challenges = {};

  AuthRepository(
    this.database, {
    FailedLoginAttempts? failedAttempts,
    FailedLoginAttempts? failedCodeAttempts,
  }) : failedAttempts = failedAttempts ?? FailedLoginAttempts(),
       failedCodeAttempts = failedCodeAttempts ?? FailedLoginAttempts();

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

    final access = AppRole.fromDbName(role) == AppRole.empleado
        ? AccessControl.restricted(
            await ModulePermissionRepository(database).getPermissions(user.id),
          )
        : AccessControl.full;

    return UserModel(
      id: user.id,
      username: user.username,
      email: user.email,
      role: role,
      mfaEnabled: user.mfaEnabled,
      darkMode: user.darkMode,
      isActive: user.isActive,
      access: access,
    );
  }

  Future<UserModel?> login(String username, String password) async {
    try {
      final hash = _hashPassword(password);

      final user = await (database.select(
        database.users,
      )..where((u) => u.username.equals(username))).getSingleOrNull();

      if (user == null || !user.isActive) {
        await _recordFailure(
          user?.id,
          user?.username,
          user == null ? 'unknown_user' : 'blocked_user',
        );
        return null;
      }
      if (user.passwordHash != hash) {
        await _recordFailure(user.id, user.username, 'wrong_password');
        await _registerFailure(user);
        return null;
      }

      failedAttempts.reset(user.username);

      if (user.mfaEnabled && user.mfaSecret != null) {
        _challenges[user.username] = TwoFactorChallenge(
          userId: user.id,
          username: user.username,
        );
        return null;
      }

      return await _startSession(user);
    } catch (e) {
      return null;
    }
  }

  Future<void> _recordFailure(int? userId, String? username, String reason) =>
      database.recordAudit(
        module: AuditModule.sesion,
        action: AuditAction.loginFailed,
        entity: 'users',
        recordId: userId,
        label: username,
        after: {'username': ?username, 'reason': reason},
        userId: userId,
        actorName: username,
        always: true,
      );

  Future<UserModel?> _startSession(User user) async {
    final model = await database.transaction(() async {
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
      final model = await _buildUserModel(user);
      if (model != null) {
        await database.recordAudit(
          module: AuditModule.sesion,
          action: AuditAction.login,
          entity: 'users',
          recordId: user.id,
          label: user.username,
          after: {
            'username': user.username,
            'role': model.appRole.dbName,
            'two_factor': user.mfaEnabled ? 1 : 0,
          },
          userId: user.id,
          actorName: user.username,
          always: true,
        );
      }
      return model;
    });
    if (model != null) _openSession(user, model);
    return model;
  }

  void _openSession(User user, UserModel model) {
    database.auditActor.set(user.id, user.username);
    database.sensitiveData.openSession(
      canReadAudit:
          model.appRole == AppRole.administrador ||
          model.appRole == AppRole.propietario,
    );
  }

  TwoFactorChallenge? takeTwoFactorChallenge(String username) =>
      _challenges.remove(username);

  Future<UserModel?> verifyCode(int userId, String code) async {
    try {
      final user = await (database.select(
        database.users,
      )..where((u) => u.id.equals(userId))).getSingleOrNull();
      if (user == null ||
          !user.isActive ||
          !user.mfaEnabled ||
          user.mfaSecret == null) {
        return null;
      }
      if (verifyTotp(user.mfaSecret!, code, appNow())) {
        failedCodeAttempts.reset(user.username);
        return await _startSession(user);
      }
      await _recordFailure(user.id, user.username, 'wrong_code');
      await _registerCodeFailure(user);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _registerFailure(User user) async {
    final model = await _buildUserModel(user);
    if (model == null || model.appRole == AppRole.administrador) return;
    final count = failedAttempts.registerFailure(user.username);
    if (count < maxFailedLoginAttempts) return;
    await _block(user, 'password');
  }

  Future<void> _registerCodeFailure(User user) async {
    final model = await _buildUserModel(user);
    if (model == null || model.appRole == AppRole.administrador) return;
    final count = failedCodeAttempts.registerFailure(user.username);
    if (count < maxFailedLoginAttempts) return;
    await _block(user, 'verification_code');
  }

  Future<void> _block(User user, String cause) async {
    await database.transaction(() async {
      await (database.update(
        database.users,
      )..where((u) => u.id.equals(user.id))).write(
        UsersCompanion(isActive: const Value(false), updatedAt: Value(appNow())),
      );
      await database.recordAudit(
        module: AuditModule.sesion,
        action: AuditAction.lockout,
        entity: 'users',
        recordId: user.id,
        label: user.username,
        before: {'username': user.username, 'is_active': 1},
        after: {'username': user.username, 'is_active': 0, 'cause': cause},
        userId: user.id,
        actorName: user.username,
        always: true,
      );
    });
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
      if (sesiones.isEmpty) {
        database.sensitiveData.closeSession();
        database.auditActor.clear();
        return null;
      }

      final sesion = sesiones.first;

      final user =
          await (database.select(database.users)
                ..where((u) => u.id.equals(sesion.userId))
                ..where((u) => u.isActive.equals(true)))
              .getSingleOrNull();

      if (user == null) {
        database.sensitiveData.closeSession();
        database.auditActor.clear();
        return null;
      }

      final model = await _buildUserModel(user);
      if (model != null) _openSession(user, model);
      return model;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    final actor = database.auditActor.userId;
    final actorName = database.auditActor.username;
    database.sensitiveData.closeSession();
    await database.transaction(() async {
      final sesiones = await database.select(database.sesionLocal).get();
      await database.delete(database.sesionLocal).go();
      final userId = actor ?? sesiones.firstOrNull?.userId;
      final username = actorName ?? sesiones.firstOrNull?.username;
      if (userId != null) {
        await database.recordAudit(
          module: AuditModule.sesion,
          action: AuditAction.logout,
          entity: 'users',
          recordId: userId,
          label: username,
          after: {'username': ?username},
          userId: userId,
          actorName: username,
          always: true,
        );
      }
    });
    database.auditActor.clear();
  }
}
