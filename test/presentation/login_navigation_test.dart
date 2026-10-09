import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/navigation/main_navigation_page.dart';
import 'package:offline_first_bi/presentation/pages/login_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

String _hash(String password) => sha256.convert(utf8.encode(password)).toString();

Future<AppDatabase> _openDbWithUser({
  required String username,
  required String password,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  // Fuerza la apertura para que se ejecute el seed inicial (onCreate), como
  // ocurriría en una instalación limpia real (sin --dart-define de usuario
  // semilla: el usuario se crea aquí a mano, igual que lo haría un registro).
  await db.select(db.modules).get();
  await db
      .into(db.users)
      .insert(
        UsersCompanion.insert(
          username: username,
          email: '$username@test.com',
          passwordHash: _hash(password),
        ),
      );
  return db;
}

void main() {
  testWidgets(
    'regression: logging in through the login form lands on '
    'MainNavigationPage (with its bottom bar), not a bare HomePage '
    'without one — this is the path a genuinely fresh install takes, '
    'unlike a warm reopen which restores the session before the first '
    'route ever builds',
    (tester) async {
      final db = await _openDbWithUser(username: 'usuario_prueba', password: '123456');
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(theme: lightTheme, home: const LoginPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de usuario'),
        'usuario_prueba',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tu contraseña'),
        '123456',
      );
      // En la superficie de prueba (800x600) el botón queda más abajo de lo
      // visible: se desplaza hasta él, como haría la persona.
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationPage), findsOneWidget);
      // Este ícono solo existe en el tab "Inicio" de la barra inferior de
      // MainNavigationPage: si la app hubiera navegado a un HomePage suelto
      // (el bug real), este find no encontraría nada.
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    },
  );
}
