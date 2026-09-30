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
import 'package:offline_first_bi/presentation/pages/login_page.dart';
import 'package:offline_first_bi/presentation/pages/settings_page.dart';

// Repositorio real que además cuenta cuántas veces se llama a logout(): así
// se comprueba que el botón usa el logout() que ya existía, no otro camino.
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

void main() {
  late AppDatabase db;
  late _SpyAuthRepository spy;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    spy = _SpyAuthRepository(db);
    await db.select(db.modules).get(); // fuerza el seed inicial
    final userId = await db.into(db.users).insert(
      UsersCompanion.insert(
        username: 'usuario_prueba',
        email: 'prueba@test.com',
        passwordHash: _hash('123456'),
      ),
    );
    // Permiso de lectura sobre todos los módulos: aparecen todas las pestañas.
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

    // Sin sesión guardada: aparece el inicio de sesión. Se entra por el
    // formulario, igual que en una instalación real.
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de usuario'),
      'usuario_prueba',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tu contraseña'),
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

  group('entry point', () {
    testWidgets('every main tab has the settings button in its top bar', (
      tester,
    ) async {
      await pumpAppLoggedIn(tester);

      for (final tab in ['Inicio', 'Inventario', 'Ventas', 'Contactos', 'Reportes']) {
        // La barra inferior es el último widget con esa etiqueta.
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Ajustes'),
          findsWidgets,
          reason: 'la pestaña "$tab" debe ofrecer Ajustes',
        );
      }
    });

    testWidgets('the settings page shows the account and a reserved, disabled dark-mode spot', (
      tester,
    ) async {
      await pumpAppLoggedIn(tester);
      await openSettings(tester);

      expect(find.text('Ajustes'), findsWidgets);
      expect(find.text('usuario_prueba'), findsOneWidget);
      expect(find.text('prueba@test.com'), findsOneWidget);

      // Preferencias: "Tema oscuro" reservado, marcado "Próximamente" y sin
      // efecto (el interruptor está desactivado).
      expect(find.text('Preferencias'), findsOneWidget);
      expect(find.text('Tema oscuro'), findsOneWidget);
      expect(find.text('Próximamente'), findsOneWidget);
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.onChanged, isNull);
      expect(toggle.value, isFalse);
    });
  });

  group('logout', () {
    testWidgets(
      'confirming calls the existing logout(), clears the saved session and '
      'returns to the login screen',
      (tester) async {
        await pumpAppLoggedIn(tester);
        // El inicio de sesión guardó la sesión local.
        expect(await db.select(db.sesionLocal).get(), hasLength(1));
        expect(spy.logoutCalls, 0);

        await openSettings(tester);
        await tester.tap(find.byIcon(Icons.logout));
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
        // De vuelta al inicio de sesión: ni el shell ni Ajustes quedan apilados.
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(SettingsPage), findsNothing);
        expect(find.byType(MainNavigationPage), findsNothing);
        expect(container(tester).read(authProvider).user, isNull);
      },
    );

    testWidgets('the person can log in again after logging out', (tester) async {
      await pumpAppLoggedIn(tester);
      await openSettings(tester);
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Cerrar sesión'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de usuario'),
        'usuario_prueba',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tu contraseña'),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationPage), findsOneWidget);
    });

    testWidgets(
      'also works when the app was reopened with a saved session (the shell is '
      'the home route, not a replaced login route)',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await spy.login('usuario_prueba', '123456'); // deja una sesión guardada
        spy.logoutCalls = 0;

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
        expect(find.byType(MainNavigationPage), findsOneWidget); // sesión restaurada

        await openSettings(tester);
        await tester.tap(find.byIcon(Icons.logout));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(ElevatedButton, 'Cerrar sesión'),
          ),
        );
        await tester.pumpAndSettle();

        expect(spy.logoutCalls, 1);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(MainNavigationPage), findsNothing);
        expect(await db.select(db.sesionLocal).get(), isEmpty);
      },
    );

    testWidgets('choosing "Cancelar" keeps the session and stays in Ajustes', (
      tester,
    ) async {
      await pumpAppLoggedIn(tester);
      await openSettings(tester);

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(OutlinedButton, 'Cancelar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(spy.logoutCalls, 0);
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(await db.select(db.sesionLocal).get(), hasLength(1));
    });
  });
}

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MyApp)));
