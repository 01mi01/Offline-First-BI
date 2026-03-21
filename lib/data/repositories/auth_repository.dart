import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../data/db/app_database.dart';
import '../../models/user_model.dart';

class AuthRepository {
  final AppDatabase database;

  AuthRepository(this.database);

  // Genera hash SHA-256 de la contraseña
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Convierte fila de usuario a modelo
  Future<UserModel?> _buildUserModel(User user) async {
    final userRole = await (database.select(
      database.userRoles,
    )..where((ur) => ur.userId.equals(user.id))).getSingleOrNull();

    String role = 'usuario';
    if (userRole != null) {
      final roleData = await (database.select(
        database.roles,
      )..where((r) => r.id.equals(userRole.roleId))).getSingleOrNull();
      role = roleData?.name ?? 'usuario';
    }

    return UserModel(
      id: user.id,
      username: user.username,
      email: user.email,
      role: role,
      mfaEnabled: user.mfaEnabled,
      darkMode: user.darkMode,
    );
  }

  // Inicia sesión y persiste la sesión localmente
  Future<UserModel?> login(String username, String password) async {
    try {
      final hash = _hashPassword(password);

      final user =
          await (database.select(database.users)
                ..where((u) => u.username.equals(username))
                ..where((u) => u.isActive.equals(true)))
              .getSingleOrNull();

      if (user == null) return null;
      if (user.passwordHash != hash) return null;

      // Guarda la sesión en la tabla local
      await database.delete(database.sesionLocal).go();
      await database
          .into(database.sesionLocal)
          .insert(
            SesionLocalCompanion.insert(
              userId: user.id.toString(),
              username: user.username,
              createdAt: DateTime.now(),
            ),
          );

      return await _buildUserModel(user);
    } catch (e) {
      return null;
    }
  }

  // Recupera la sesión activa al abrir la app
  Future<UserModel?> getSesionActual() async {
    try {
      final sesiones = await database.select(database.sesionLocal).get();
      if (sesiones.isEmpty) return null;

      final sesion = sesiones.first;
      final userId = int.tryParse(sesion.userId);
      if (userId == null) return null;

      final user =
          await (database.select(database.users)
                ..where((u) => u.id.equals(userId))
                ..where((u) => u.isActive.equals(true)))
              .getSingleOrNull();

      if (user == null) return null;

      return await _buildUserModel(user);
    } catch (e) {
      return null;
    }
  }

  // Cierra sesión eliminando el registro local
  Future<void> logout() async {
    await database.delete(database.sesionLocal).go();
  }
}
