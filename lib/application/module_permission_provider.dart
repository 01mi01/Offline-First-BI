import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/module_permission_repository.dart';
import '../models/access_control.dart';
import '../models/app_role.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final modulePermissionRepositoryProvider =
    Provider<ModulePermissionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ModulePermissionRepository(db);
});

final accessControlProvider = Provider<AccessControl>(
  (ref) =>
      ref.watch(authProvider.select((s) => s.user?.access)) ??
      AccessControl.full,
);

final readableModulesProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  return user.access.readableModuleNames;
});

class AccessGuard {
  final AccessControl? Function() _current;

  const AccessGuard(this._current);

  static AccessControl? _nobody() => null;

  static const AccessGuard none = AccessGuard(_nobody);

  String? check(AppModule module, ModuleAction action) {
    final access = _current();
    if (access == null || access.can(module, action)) return null;
    return accessDeniedMessage;
  }

  String? checkCreate(AppModule module, {AppModule? from}) {
    final access = _current();
    if (access == null) return null;
    final allowed = from == null
        ? access.canCreate(module)
        : access.canQuickAdd(module, from);
    return allowed ? null : accessDeniedMessage;
  }

  void require(AppModule module, ModuleAction action) {
    if (check(module, action) != null) throw const AccessDeniedException();
  }

  void requireCreate(AppModule module, {AppModule? from}) {
    if (checkCreate(module, from: from) != null) {
      throw const AccessDeniedException();
    }
  }

  void requireSave(
    AppModule module, {
    required bool isNew,
    required bool activeChanged,
    AppModule? from,
  }) {
    if (isNew) {
      requireCreate(module, from: from);
      return;
    }
    require(module, ModuleAction.update);
    if (activeChanged) require(module, ModuleAction.deactivate);
  }

  String? checkSave(
    AppModule module, {
    required bool isNew,
    required bool activeChanged,
    AppModule? from,
  }) {
    try {
      requireSave(
        module,
        isNew: isNew,
        activeChanged: activeChanged,
        from: from,
      );
      return null;
    } on AccessDeniedException {
      return accessDeniedMessage;
    }
  }
}

final accessGuardProvider = Provider<AccessGuard>(
  (ref) => AccessGuard(() => ref.read(authProvider).user?.access),
);

const String permissionsAdminOnlyMessage =
    'Solo el administrador puede definir permisos';
const String permissionsEmployeeOnlyMessage =
    'Los permisos solo se definen para empleados';

class EmployeePermissionsService {
  final ModulePermissionRepository repository;
  final Ref ref;

  EmployeePermissionsService(this.repository, this.ref);

  String? _checkCaller() =>
      ref.read(authProvider).user?.isAdmin == true
          ? null
          : permissionsAdminOnlyMessage;

  Future<Map<AppModule, PermissionSet>> load(int userId) async {
    final permissions = await repository.getPermissions(userId);
    return {
      for (final module in AppModule.configurable)
        module: permissions[module] ?? PermissionSet.none,
    };
  }

  Future<String?> save({
    required int userId,
    required String role,
    required Map<AppModule, PermissionSet> permissions,
  }) async {
    final error = _checkCaller();
    if (error != null) return error;
    if (AppRole.fromDbName(role) != AppRole.empleado) {
      return permissionsEmployeeOnlyMessage;
    }
    try {
      await repository.savePermissions(userId, {
        for (final entry in permissions.entries)
          if (entry.key.commercial) entry.key: entry.value,
      });
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }
}

final employeePermissionsProvider = Provider<EmployeePermissionsService>(
  (ref) => EmployeePermissionsService(
    ref.watch(modulePermissionRepositoryProvider),
    ref,
  ),
);
