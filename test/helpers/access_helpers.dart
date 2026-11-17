import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_first_bi/application/auth_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/module_permission_repository.dart';
import 'package:offline_first_bi/models/access_control.dart';

const PermissionSet readOnly = PermissionSet(read: true);
const PermissionSet readCreate = PermissionSet(read: true, create: true);

Future<int> userIdOf(AppDatabase db, String username) async =>
    (await (db.select(
      db.users,
    )..where((u) => u.username.equals(username))).getSingle()).id;

Map<AppModule, PermissionSet> permissions(
  Map<AppModule, PermissionSet> overrides, {
  PermissionSet base = PermissionSet.none,
}) => {
  for (final module in AppModule.configurable)
    module: overrides[module] ?? base,
};

Future<void> setPermissionsFor(
  AppDatabase db,
  String username,
  Map<AppModule, PermissionSet> overrides, {
  PermissionSet base = PermissionSet.none,
}) async {
  await ModulePermissionRepository(
    db,
  ).savePermissions(await userIdOf(db, username), permissions(overrides, base: base));
}

Future<void> signInContainer(
  ProviderContainer container,
  String username,
  String password,
) async {
  while (container.read(authProvider).isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
  await container.read(authProvider.notifier).login(username, password);
}
