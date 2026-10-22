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
        find.widgetWithText(TextFormField, 'Contraseña'),
        '123456',
      );
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationPage), findsOneWidget);
    },
  );
}
