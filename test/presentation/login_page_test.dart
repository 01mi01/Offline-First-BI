import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  final cardRadius = BorderRadius.circular(AppSpacing.s28);
  Finder card() => find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color == AppColors.surface &&
        (w.decoration as BoxDecoration).borderRadius == cardRadius,
  );

  group('layout', () {
    testWidgets('only the "Iniciar sesión" title (and the button text): no subtitle, no headline', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(find.text('Iniciar sesión'), findsNWidgets(2));
      expect(
        find.descendant(of: loginButton(), matching: find.text('Iniciar sesión')),
        findsOneWidget,
      );
      expect(find.text('Ingresa tus datos para acceder a tu cuenta'), findsNothing);
      expect(find.text('Bienvenido de nuevo'), findsNothing);
      expect(find.text('Inicia sesión para continuar'), findsNothing);
      expect(find.byType(SvgPicture), findsOneWidget);

      final title = tester.widget<Text>(find.text('Iniciar sesión').first);
      expect(title.style!.fontWeight, FontWeight.bold);
      expect(title.style!.color, AppColors.textPrimary);
      expect(title.textAlign, TextAlign.center);
    });

    testWidgets('there are no labels outside the fields: hints and icons are enough', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(find.text('Usuario'), findsNothing);
      expect(find.text('Contraseña'), findsNothing);
      expect(find.text('Nombre de usuario'), findsOneWidget);
      expect(find.text('Tu contraseña'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('the logo, the title and the card are horizontally centered', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(tester.getCenter(find.byType(SvgPicture)).dx, closeTo(180, 0.5));
      expect(tester.getCenter(find.text('Iniciar sesión').first).dx, closeTo(180, 0.5));
      expect(tester.getCenter(card()).dx, closeTo(180, 0.5));
    });

    testWidgets('the logo keeps its original size and colors (no tint)', (
      tester,
    ) async {
      await pumpLogin(tester);

      final logo = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(logo.width, 360 * 0.6);
      expect(logo.fit, BoxFit.contain);
      expect(logo.colorFilter, isNull);
    });

    testWidgets('the white card floats: side margins, not on the bottom edge, rounded on all four corners, with the theme shadow', (
      tester,
    ) async {
      await pumpLogin(tester, size: const Size(360, 640));

      expect(card(), findsOneWidget);
      final rect = tester.getRect(card());
      expect(rect.left, greaterThan(0));
      expect(rect.right, lessThan(360));
      expect(rect.top, greaterThan(0));
      expect(rect.bottom, lessThan(640));
      // Centrada también en vertical.
      expect(rect.center.dy, closeTo(320, 1));

      final decoration = tester.widget<Container>(card()).decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(AppSpacing.s28));
      expect(decoration.boxShadow, AppShadows.card);

      // Todo el contenido vive dentro de la tarjeta; nada queda fuera.
      for (final inside in [
        find.byType(SvgPicture),
        find.text('Iniciar sesión').first,
        field('Usuario'),
        field('Contraseña'),
        loginButton(),
      ]) {
        expect(find.descendant(of: card(), matching: inside), findsOneWidget);
      }
      expect(
        find.descendant(of: card(), matching: find.byType(Text)).evaluate().length,
        find.byType(Text).evaluate().length,
        reason: 'ningún texto queda fuera de la tarjeta',
      );
    });

    testWidgets('the card fades in on first build', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(theme: lightTheme, home: const LoginPage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final opacity = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(opacity.any((o) => o.opacity > 0 && o.opacity < 1), isTrue);

      await tester.pumpAndSettle();
      expect(tester.widgetList<Opacity>(find.byType(Opacity)).every((o) => o.opacity == 1), isTrue);
    });

    testWidgets('the background is solid and does not move with the keyboard', (
      tester,
    ) async {
      await pumpLogin(tester, size: const Size(360, 640));

      final scaffold = find.byType(Scaffold);
      expect(
        tester.widget<Scaffold>(scaffold).backgroundColor,
        AppColors.background,
      );
      expect(tester.getSize(scaffold), const Size(360, 640));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(scaffold), Offset.zero);
      expect(tester.getSize(scaffold), const Size(360, 640));
    });

    testWidgets('the primary button is 50 high, fully rounded, soft white on dark cyan', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(tester.getSize(loginButton()).height, 50);
      final style = tester.widget<ElevatedButton>(loginButton()).style!;
      final theme = lightTheme.elevatedButtonTheme.style!;
      expect(
        (theme.shape!.resolve({}) as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(50),
      );
      expect(style.backgroundColor!.resolve({}), AppColors.primaryDark);
      expect(style.backgroundColor!.resolve({WidgetState.disabled}), AppColors.primaryDark);
      expect(style.foregroundColor!.resolve({WidgetState.disabled}), AppColors.surface);

      final label = tester.widget<Text>(
        find.descendant(of: loginButton(), matching: find.text('Iniciar sesión')),
      );
      expect(label.style!.color, AppColors.surface);
    });

    testWidgets('the password toggle is at least 48 dp', (tester) async {
      await pumpLogin(tester);

      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

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

    testWidgets('the leading icons are dark cyan at rest and while focused', (
      tester,
    ) async {
      await pumpLogin(tester);

      Color? iconColor(IconData icon) =>
          IconTheme.of(tester.element(find.byIcon(icon))).color;

      expect(iconColor(Icons.person_outline), AppColors.primaryDark);
      expect(iconColor(Icons.lock_outline), AppColors.primaryDark);

      await tester.tap(field('Usuario'));
      await tester.pumpAndSettle();
      expect(iconColor(Icons.person_outline), AppColors.primaryDark);
      expect(iconColor(Icons.lock_outline), AppColors.primaryDark);
    });

    testWidgets('empty fields show the existing validation message and do not sign in', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(find.text('Campo requerido'), findsNWidgets(2));
      for (final f in tester.widgetList<InputDecorator>(find.byType(InputDecorator))) {
        expect(f.decoration.errorBorder, f.decoration.enabledBorder);
        expect(f.decoration.focusedErrorBorder, f.decoration.focusedBorder);
        expect(f.decoration.prefixIconColor, AppColors.primaryDark);
      }
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
      expect(tester.getSize(loginButton()).height, 50);

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
      expect(tester.widget<Text>(message).style!.color, AppColors.error);
      expect(find.byIcon(Icons.error_outline), findsNothing);

      // El mensaje queda entre los campos y el botón.
      final fieldBottom = tester.getBottomLeft(field('Contraseña')).dy;
      expect(tester.getTopLeft(message).dy, greaterThan(fieldBottom));
      expect(tester.getBottomLeft(message).dy, lessThan(tester.getTopLeft(loginButton()).dy));
    });

    testWidgets('the error message animates in instead of popping', (tester) async {
      await pumpLogin(tester);

      await fillAndSubmit(tester, password: 'incorrecta');
      await tester.pump(); // arranca el inicio de sesión
      await tester.pump(const Duration(milliseconds: 50));
      // A mitad de camino todavía no es del todo opaca.
      final fade = tester.widgetList<FadeTransition>(find.byType(FadeTransition));
      expect(fade.any((f) => f.opacity.value > 0 && f.opacity.value < 1), isTrue);

      await tester.pumpAndSettle();
      expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);
    });
  });

  group('keyboard on a small screen', () {
    testWidgets('360x640 with the keyboard open: no overflow, the button stays reachable', (
      tester,
    ) async {
      await pumpLogin(tester, size: const Size(360, 640));

      // Teclado de 300 dp abierto.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      // Con el teclado abierto la pantalla se desplaza hasta el campo.
      await tester.ensureVisible(field('Contraseña'));
      await tester.pumpAndSettle();
      await tester.tap(field('Contraseña'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Contraseña'), '123456');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Con el error visible y el teclado abierto tampoco hay desbordes.
      await fillAndSubmit(tester, password: 'incorrecta');
      await tester.pumpAndSettle();
      expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // El botón se puede desplazar hasta quedar dentro de la zona visible.
      await tester.ensureVisible(loginButton());
      await tester.pumpAndSettle();
      final bottom = tester.getBottomLeft(loginButton()).dy;
      expect(bottom, lessThanOrEqualTo(640 - 300));
    });

    testWidgets('typing does not move the fields', (tester) async {
      await pumpLogin(tester, size: const Size(360, 640));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      await tester.ensureVisible(field('Usuario'));
      await tester.pumpAndSettle();
      await tester.tap(field('Usuario'));
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(field('Usuario'));

      await tester.enterText(field('Usuario'), 'usuario_prueba');
      await tester.pump();
      await tester.enterText(field('Usuario'), 'usuario_pruebas');
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(field('Usuario')), before);
    });

    testWidgets('a short landscape-like screen scrolls instead of overflowing', (
      tester,
    ) async {
      await pumpLogin(tester, size: const Size(640, 360));

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(loginButton());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
