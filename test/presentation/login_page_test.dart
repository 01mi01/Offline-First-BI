import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/auth_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/auth_repository.dart';
import 'package:offline_first_bi/models/user_model.dart';
import 'package:offline_first_bi/presentation/pages/login_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// Repositorio cuyo login() no termina hasta que el test lo decide: permite
// observar el estado "cargando" del botón.
class _SlowAuthRepository extends AuthRepository {
  _SlowAuthRepository(super.database);

  final Completer<UserModel?> gate = Completer<UserModel?>();

  @override
  Future<UserModel?> login(String username, String password) => gate.future;
}

String _hash(String password) => sha256.convert(utf8.encode(password)).toString();

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.select(db.modules).get(); // fuerza el seed inicial
    await db.into(db.users).insert(
      UsersCompanion.insert(
        username: 'usuario_prueba',
        email: 'prueba@test.com',
        passwordHash: _hash('123456'),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    AuthRepository? repository,
    Size size = const Size(360, 640),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (repository != null)
            authRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(theme: lightTheme, home: const LoginPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Los campos se identifican por su sugerencia; las etiquetas "Usuario" y
  // "Contraseña" están fuera y encima de ellos.
  Finder field(String label) => find.widgetWithText(
    TextFormField,
    label == 'Usuario' ? 'Nombre de usuario' : 'Tu contraseña',
  );
  Finder loginButton() => find.byType(ElevatedButton);

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    String user = 'usuario_prueba',
    String password = '123456',
  }) async {
    await tester.enterText(field('Usuario'), user);
    await tester.enterText(field('Contraseña'), password);
    await tester.pumpAndSettle();
    await tester.ensureVisible(loginButton());
    await tester.pumpAndSettle();
    await tester.tap(loginButton());
  }

  group('fields', () {
    testWidgets('the password is hidden and the toggle shows and hides it', (
      tester,
    ) async {
      await pumpLogin(tester);

      bool obscured() => tester
          .widget<EditableText>(
            find.descendant(of: field('Contraseña'), matching: find.byType(EditableText)),
          )
          .obscureText;

      expect(obscured(), isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(obscured(), isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(obscured(), isTrue);
    });

    testWidgets('empty fields show the existing validation message and do not sign in', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(find.text('Campo requerido'), findsNWidgets(2));
      expect(find.text('Usuario o contraseña incorrectos'), findsNothing);
    });
  });

  group('signing in', () {
    testWidgets('while signing in the button shows a progress indicator and is disabled', (
      tester,
    ) async {
      final slow = _SlowAuthRepository(db);
      await pumpLogin(tester, repository: slow);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<ElevatedButton>(loginButton()).onPressed, isNotNull);

      await fillAndSubmit(tester);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // El botón ya no muestra el texto (solo queda el título).
      expect(
        find.descendant(of: loginButton(), matching: find.text('Iniciar sesión')),
        findsNothing,
      );
      expect(tester.widget<ElevatedButton>(loginButton()).onPressed, isNull);

      // Al terminar (credenciales no válidas) el botón vuelve a estar activo.
      slow.gate.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<ElevatedButton>(loginButton()).onPressed, isNotNull);
    });

    testWidgets('wrong credentials show the existing message as plain error text', (
      tester,
    ) async {
      await pumpLogin(tester);
      expect(find.text('Usuario o contraseña incorrectos'), findsNothing);

      await fillAndSubmit(tester, password: 'incorrecta');
      await tester.pumpAndSettle();

      final message = find.text('Usuario o contraseña incorrectos');
      expect(message, findsOneWidget);
    });

  });

}
