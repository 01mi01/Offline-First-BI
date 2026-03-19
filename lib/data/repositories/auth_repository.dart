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

  // Busca el usuario y verifica la contraseña
  Future<UserModel?> login(String username, String password) async {
    try {
      final hash = _hashPassword(password);

      final user = await (database.select(database.users)
            ..where((u) => u.username.equals(username))
            ..where((u) => u.isActive.equals(true)))
          .getSingleOrNull();

      if (user == null) return null;
      if (user.passwordHash != hash) return null;

      // Obtener el rol del usuario
      final userRole = await (database.select(database.userRoles)
            ..where((ur) => ur.userId.equals(user.id)))
          .getSingleOrNull();

      String role = 'usuario';
      if (userRole != null) {
        final roleData = await (database.select(database.roles)
              ..where((r) => r.id.equals(userRole.roleId)))
            .getSingleOrNull();
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
    } catch (e) {
      return null;
    }
  }
}