import 'access_control.dart';
import 'app_role.dart';

class UserModel {
  final int id;
  final String username;
  final String email;
  final String role;
  final bool mfaEnabled;
  final bool darkMode;
  final bool isActive;
  final AccessControl access;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.mfaEnabled,
    required this.darkMode,
    this.isActive = true,
    this.access = AccessControl.full,
  });

  AppRole get appRole => AppRole.fromDbName(role);

  bool get isAdmin => appRole == AppRole.administrador;

  bool get isBlocked => !isActive;
}
