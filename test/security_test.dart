import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/auth_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/auth_repository.dart';
import 'package:offline_first_bi/main.dart';
import 'package:offline_first_bi/presentation/navigation/main_navigation_page.dart';
import 'package:offline_first_bi/presentation/navigation/nav_resolver.dart';
import 'package:offline_first_bi/presentation/pages/login_page.dart';
import 'package:offline_first_bi/presentation/pages/settings_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

class _SpyAuthRepository extends AuthRepository {
  _SpyAuthRepository(super.database);

  int logoutCalls = 0;

  @override
  Future<void> logout() {
    logoutCalls++;
    return super.logout();
  }
}

String _hash(String password) => sha256.convert(utf8.encode(password)).toString();

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MyApp)));

void main() {
  late AppDatabase db;
  late _SpyAuthRepository spy;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    spy = _SpyAuthRepository(db);
    await db.select(db.modules).get();
    final userId = await db.into(db.users).insert(
      UsersCompanion.insert(
        username: 'usuario_prueba',
        email: 'prueba@test.com',
        passwordHash: _hash('123456'),
      ),
    );
    for (final module in await db.select(db.modules).get()) {
      await db.into(db.modulePermissions).insert(
        ModulePermissionsCompanion.insert(
          userId: userId,
          moduleId: module.id,
          canRead: const Value(true),
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: lightTheme, home: const LoginPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(
    TextFormField,
    label == 'Usuario' ? 'Nombre de usuario' : 'Contraseña',
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

  Future<void> pumpAppLoggedIn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(spy),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de usuario'),
      'usuario_prueba',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      '123456',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(MainNavigationPage), findsOneWidget);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Ajustes').first);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  }

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

  test('zero module access still shows only Home', () {
    expect(resolveVisibleGroups([]), [NavGroupId.home]);
  });

  testWidgets(
    'confirming calls the existing logout(), clears the saved session and '
    'returns to the login screen',
    (tester) async {
      await pumpAppLoggedIn(tester);
      expect(await db.select(db.sesionLocal).get(), hasLength(1));
      expect(spy.logoutCalls, 0);

      await openSettings(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Cerrar sesión'),
        ),
      );
      await tester.pumpAndSettle();

      expect(spy.logoutCalls, 1);
      expect(await db.select(db.sesionLocal).get(), isEmpty);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SettingsPage), findsNothing);
      expect(find.byType(MainNavigationPage), findsNothing);
      expect(container(tester).read(authProvider).user, isNull);
    },
  );
}
