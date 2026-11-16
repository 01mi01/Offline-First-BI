import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../../config/app_clock.dart';
import '../../data/db/app_database.dart';
import '../../models/app_role.dart';
import '../../models/user_model.dart';
import 'failed_login_attempts.dart';

class UserManagementException implements Exception {
  final String message;

  const UserManagementException(this.message);

  @override
  String toString() => message;
}

const String duplicateUsernameMessage = 'Ya existe un usuario con ese nombre';
const String duplicateEmailMessage = 'Ya existe un usuario con ese correo';
const String userNotFoundMessage = 'El usuario no existe';

String hashPassword(String password) =>
    sha256.convert(utf8.encode(password)).toString();

class UserRepository {
  final AppDatabase database;
  final FailedLoginAttempts? failedAttempts;

  UserRepository(this.database, {this.failedAttempts});

  Future<List<UserModel>> getAll() async {
    final query =
        database.select(database.users).join([
            leftOuterJoin(
              database.userRoles,
              database.userRoles.userId.equalsExp(database.users.id),
            ),
            leftOuterJoin(
              database.roles,
              database.roles.id.equalsExp(database.userRoles.roleId),
            ),
          ])
          ..orderBy([OrderingTerm.asc(database.users.username.lower())]);
    final rows = await query.get();
    final byId = <int, UserModel>{};
    for (final row in rows) {
      final user = row.readTable(database.users);
      final role = row.readTableOrNull(database.roles);
      byId.putIfAbsent(
        user.id,
        () => UserModel(
          id: user.id,
          username: user.username,
          email: user.email,
          role: role?.name ?? AppRole.empleado.dbName,
          mfaEnabled: user.mfaEnabled,
          darkMode: user.darkMode,
          isActive: user.isActive,
        ),
      );
    }
    return byId.values.toList();
  }

  Future<UserModel?> getById(int id) async {
    final users = await getAll();
    return users.where((u) => u.id == id).firstOrNull;
  }

  Future<void> _checkUnique({
    int? id,
    required String username,
    required String email,
  }) async {
    final sameUsername =
        await (database.select(database.users)..where(
              (u) => u.username.lower().equals(username.toLowerCase()),
            ))
            .get();
    if (sameUsername.any((u) => u.id != id)) {
      throw const UserManagementException(duplicateUsernameMessage);
    }
    final sameEmail =
        await (database.select(
              database.users,
            )..where((u) => u.email.lower().equals(email.toLowerCase())))
            .get();
    if (sameEmail.any((u) => u.id != id)) {
      throw const UserManagementException(duplicateEmailMessage);
    }
  }

  Future<int> _roleId(AppRole role) async {
    final row = await (database.select(
      database.roles,
    )..where((r) => r.name.equals(role.dbName))).getSingle();
    return row.id;
  }

  Future<void> _setRole(int userId, AppRole role) async {
    final roleId = await _roleId(role);
    await (database.delete(
      database.userRoles,
    )..where((ur) => ur.userId.equals(userId))).go();
    final now = appNow();
    await database
        .into(database.userRoles)
        .insert(
          UserRolesCompanion.insert(
            userId: userId,
            roleId: roleId,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> _requireUser(int id) async {
    final user = await (database.select(
      database.users,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
    if (user == null) {
      throw const UserManagementException(userNotFoundMessage);
    }
  }

  Future<int> create({
    required String username,
    required String email,
    required String password,
    required AppRole role,
  }) async {
    username = username.trim();
    email = email.trim();
    return database.transaction(() async {
      await _checkUnique(username: username, email: email);
      final now = appNow();
      final id = await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              username: username,
              email: email,
              passwordHash: hashPassword(password),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _setRole(id, role);
      final modules = await database.select(database.modules).get();
      for (final module in modules) {
        await database
            .into(database.modulePermissions)
            .insert(
              ModulePermissionsCompanion.insert(
                userId: id,
                moduleId: module.id,
                canCreate: const Value(true),
                canRead: const Value(true),
                canUpdate: const Value(true),
                canDelete: const Value(true),
              ),
            );
      }
      return id;
    });
  }

  Future<void> update({
    required int id,
    required String username,
    required String email,
    required AppRole role,
  }) async {
    username = username.trim();
    email = email.trim();
    await database.transaction(() async {
      await _requireUser(id);
      await _checkUnique(id: id, username: username, email: email);
      await (database.update(
        database.users,
      )..where((u) => u.id.equals(id))).write(
        UsersCompanion(
          username: Value(username),
          email: Value(email),
          updatedAt: Value(appNow()),
        ),
      );
      final current = await getById(id);
      if (current?.appRole != role) await _setRole(id, role);
    });
  }

  Future<void> setBlocked(int id, bool blocked) async {
    await database.transaction(() async {
      await _requireUser(id);
      await (database.update(
        database.users,
      )..where((u) => u.id.equals(id))).write(
        UsersCompanion(isActive: Value(!blocked), updatedAt: Value(appNow())),
      );
    });
    if (!blocked) {
      final user = await (database.select(
        database.users,
      )..where((u) => u.id.equals(id))).getSingle();
      failedAttempts?.reset(user.username);
    }
  }

  Future<void> resetPassword(int id, String newPassword) async {
    await database.transaction(() async {
      await _requireUser(id);
      await (database.update(
        database.users,
      )..where((u) => u.id.equals(id))).write(
        UsersCompanion(
          passwordHash: Value(hashPassword(newPassword)),
          updatedAt: Value(appNow()),
        ),
      );
    });
  }
}
