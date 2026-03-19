// Modelo de usuario para la sesión activa
class UserModel {
  final int id;
  final String username;
  final String email;
  final String role;
  final bool mfaEnabled;
  final bool darkMode;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.mfaEnabled,
    required this.darkMode,
  });
}