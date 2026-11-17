import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/user_repository.dart';
import 'package:offline_first_bi/main.dart';
import 'package:offline_first_bi/models/app_role.dart';

const String adminName = 'james.miller';
const String adminPassword = 'admin123';
const String ownerName = 'mary.wilson';
const String ownerPassword = 'owner123';
const String employeeName = 'john.smith';
const String employeePassword = 'employee123';

AppDatabase newTestDatabase() => AppDatabase.forTesting(NativeDatabase.memory());

Future<int> addTestUser(
  AppDatabase db,
  String username,
  String password,
  AppRole role, {
  String? email,
}) => UserRepository(db).create(
  username: username,
  email: email ?? '$username@example.com',
  password: password,
  role: role,
);

Future<void> addStandardUsers(AppDatabase db) async {
  await addTestUser(db, adminName, adminPassword, AppRole.administrador);
  await addTestUser(db, ownerName, ownerPassword, AppRole.propietario);
  await addTestUser(db, employeeName, employeePassword, AppRole.empleado);
}

Future<void> pumpUserApp(
  WidgetTester tester,
  AppDatabase db, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db), ...overrides],
      child: const MyApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> loginAs(
  WidgetTester tester,
  String username,
  String password,
) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nombre de usuario'),
    username,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Contraseña'),
    password,
  );
  await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
  await tester.pumpAndSettle();
}

Future<void> openSettingsPage(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ajustes').first);
  await tester.pumpAndSettle();
}

Future<void> openUsersPage(WidgetTester tester) async {
  await openSettingsPage(tester);
  await tester.tap(find.text('Usuarios'));
  await tester.pumpAndSettle();
}

Future<void> logoutFromSettings(WidgetTester tester) async {
  final settingsOpen = find.text('Cerrar sesión').evaluate().isNotEmpty;
  if (!settingsOpen) await openSettingsPage(tester);
  await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Cerrar sesión'));
  await tester.tap(find.widgetWithText(ElevatedButton, 'Cerrar sesión'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Cerrar sesión'),
    ),
  );
  await tester.pumpAndSettle();
}

Finder userRow(String username) => find.ancestor(
  of: find.text(username),
  matching: find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('user_row_'),
  ),
);

Future<void> tapUserRow(WidgetTester tester, String username) async {
  await tester.ensureVisible(userRow(username));
  await tester.tap(userRow(username));
  await tester.pumpAndSettle();
}

Future<void> tapSheetButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(ElevatedButton, label).last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> confirmDialog(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pickRole(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Rol'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(CheckedPopupMenuItem<int>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Finder fieldError(String message) => find.byWidgetPredicate(
  (w) => w is Text && w.data == message && w.maxLines == 3,
);

Future<void> tapBack(WidgetTester tester) async {
  await tester.tap(find.text('Atrás').last);
  await tester.pumpAndSettle();
}
