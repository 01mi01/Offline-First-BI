import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/module_permission_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final modulePermissionRepositoryProvider =
    Provider<ModulePermissionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ModulePermissionRepository(db);
});

// Nombres de los módulos donde el usuario actual tiene permiso de lectura
final readableModulesProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  final repository = ref.watch(modulePermissionRepositoryProvider);
  return repository.getReadableModuleNames(user.id);
});
