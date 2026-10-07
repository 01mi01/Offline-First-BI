import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/module_permission_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/navigation/contactos_eventos_tab_page.dart';
import 'package:offline_first_bi/presentation/navigation/inventario_tab_page.dart';
import 'package:offline_first_bi/presentation/navigation/main_navigation_page.dart';
import 'package:offline_first_bi/presentation/navigation/reportes_bi_tab_page.dart';
import 'package:offline_first_bi/presentation/navigation/ventas_compras_tab_page.dart';
import 'package:offline_first_bi/presentation/pages/business_intelligence_page.dart';
import 'package:offline_first_bi/presentation/pages/clients_page.dart';
import 'package:offline_first_bi/presentation/pages/events_page.dart';
import 'package:offline_first_bi/presentation/pages/materials_page.dart';
import 'package:offline_first_bi/presentation/pages/purchases_page.dart';
import 'package:offline_first_bi/presentation/pages/reports_page.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/presentation/pages/suppliers_page.dart';
import 'package:offline_first_bi/presentation/widgets/landing_card.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

Future<AppDatabase> _openDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  // Fuerza la apertura para que se ejecute el seed inicial (onCreate).
  await db.select(db.modules).get();
  return db;
}

Widget _wrap(
  Widget child, {
  required AppDatabase db,
  required List<String> readableModules,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      readableModulesProvider.overrideWith((ref) async => readableModules),
    ],
    child: MaterialApp(theme: lightTheme, home: child),
  );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await _openDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('InventarioTabPage landing cards', () {
    testWidgets('only materiales readable shows only the Materiales card',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const InventarioTabPage(),
        db: db,
        readableModules: ['materiales'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Materiales'), findsOneWidget);
      expect(find.text('Productos'), findsNothing);
      expect(find.text('Categorías'), findsNothing);
    });

    testWidgets('only inventario readable shows Productos/Categorías, not Materiales',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const InventarioTabPage(),
        db: db,
        readableModules: ['inventario'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Productos'), findsOneWidget);
      expect(find.text('Categorías'), findsOneWidget);
      expect(find.text('Materiales'), findsNothing);
    });

    testWidgets('neither readable shows the empty state, not any cards',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const InventarioTabPage(),
        db: db,
        readableModules: [],
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes acceso a ningún módulo de inventario'),
        findsOneWidget,
      );
      expect(find.text('Productos'), findsNothing);
    });

    testWidgets('tapping the Materiales card navigates to its own 2-tab page',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const InventarioTabPage(),
        db: db,
        readableModules: ['materiales'],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Materiales'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialsPage), findsOneWidget);
      expect(find.text('Registro de uso'), findsOneWidget);
    });
  });

  group('VentasComprasTabPage landing cards', () {
    testWidgets('only compras readable shows only the Compras card',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const VentasComprasTabPage(),
        db: db,
        readableModules: ['compras'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Compras'), findsOneWidget);
      expect(find.text('Ventas'), findsNothing);
    });

    testWidgets('only ventas readable shows only the Ventas card',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const VentasComprasTabPage(),
        db: db,
        readableModules: ['ventas'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ventas'), findsOneWidget);
      expect(find.text('Compras'), findsNothing);
    });

    testWidgets('neither readable shows the empty state, not any cards',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const VentasComprasTabPage(),
        db: db,
        readableModules: [],
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes acceso a ventas ni compras'),
        findsOneWidget,
      );
      expect(find.text('Ventas'), findsNothing);
    });

    testWidgets('tapping Ventas navigates to SalesPage, tapping Compras '
        'navigates to PurchasesPage (fully independent destinations)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const VentasComprasTabPage(),
        db: db,
        readableModules: ['ventas', 'compras'],
      ));
      await tester.pumpAndSettle();

      // "Ventas" también aparece en el título del AppBar de esta pantalla.
      await tester.tap(find.widgetWithText(LandingCard, 'Ventas'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesPage), findsOneWidget);

      // La app usa un ícono de "back" propio (no el widget estándar de
      // Cupertino/Material), así que se toca directamente en vez de usar
      // tester.pageBack().
      await tester.tap(find.byIcon(Icons.arrow_back_ios));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(LandingCard, 'Compras'));
      await tester.pumpAndSettle();
      expect(find.byType(PurchasesPage), findsOneWidget);
    });
  });

  group('ContactosEventosTabPage landing cards', () {
    testWidgets('only eventos readable shows only the Eventos card', (tester) async {
      await tester.pumpWidget(_wrap(
        const ContactosEventosTabPage(),
        db: db,
        readableModules: ['eventos'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Eventos y Ubicaciones'), findsOneWidget);
      expect(find.text('Clientes'), findsNothing);
      expect(find.text('Proveedores'), findsNothing);
    });

    testWidgets('tapping the Eventos card navigates to EventsPage', (tester) async {
      await tester.pumpWidget(_wrap(
        const ContactosEventosTabPage(),
        db: db,
        readableModules: ['eventos'],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Eventos y Ubicaciones'));
      await tester.pumpAndSettle();

      expect(find.byType(EventsPage), findsOneWidget);
    });

    testWidgets('proveedores alone shows only its own card, not Clientes',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ContactosEventosTabPage(),
        db: db,
        readableModules: ['proveedores'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Proveedores'), findsOneWidget);
      expect(find.text('Clientes'), findsNothing);
      expect(find.text('Eventos y Ubicaciones'), findsNothing);
    });

    testWidgets('clientes alone shows only its own card, not Proveedores',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ContactosEventosTabPage(),
        db: db,
        readableModules: ['clientes'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Clientes'), findsOneWidget);
      expect(find.text('Proveedores'), findsNothing);
    });

    testWidgets('tapping Clientes navigates to ClientsPage, tapping Proveedores '
        'navigates to SuppliersPage (fully independent destinations)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ContactosEventosTabPage(),
        db: db,
        readableModules: ['clientes', 'proveedores'],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();
      expect(find.byType(ClientsPage), findsOneWidget);

      // La app usa un ícono de "back" propio (no el widget estándar de
      // Cupertino/Material), así que se toca directamente en vez de usar
      // tester.pageBack().
      await tester.tap(find.byIcon(Icons.arrow_back_ios));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Proveedores'));
      await tester.pumpAndSettle();
      expect(find.byType(SuppliersPage), findsOneWidget);
    });
  });

  group('ReportesBiTabPage landing cards', () {
    testWidgets('only reportes readable shows only the Reportes card',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ReportesBiTabPage(),
        db: db,
        readableModules: ['reportes'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Reportes'), findsWidgets);
      expect(find.text('Business Intelligence'), findsNothing);
    });

    testWidgets('only business_intelligence readable shows only its own card',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ReportesBiTabPage(),
        db: db,
        readableModules: ['business_intelligence'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Business Intelligence'), findsOneWidget);
    });

    testWidgets('tapping each card navigates to its own dedicated page',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ReportesBiTabPage(),
        db: db,
        readableModules: ['reportes', 'business_intelligence'],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Business Intelligence'));
      await tester.pumpAndSettle();
      expect(find.byType(BusinessIntelligencePage), findsOneWidget);
      // Ya no es un marcador "Próximamente": abre en el paso de configuración
      // (periodo e indicadores) antes de mostrar datos.
      expect(find.text('Próximamente'), findsNothing);
      expect(find.byKey(const ValueKey('bi-config-confirm')), findsOneWidget);
      expect(find.byKey(const ValueKey('bi-period')), findsNothing);

      // La app usa un ícono de "back" propio (no el widget estándar de
      // Cupertino/Material), así que se toca directamente en vez de usar
      // tester.pageBack().
      await tester.tap(find.byIcon(Icons.arrow_back_ios));
      await tester.pumpAndSettle();

      // "Reportes" también aparece en el título del AppBar de esta pantalla,
      // así que se apunta específicamente a la tarjeta, no al texto suelto.
      await tester.tap(find.widgetWithText(LandingCard, 'Reportes'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportsPage), findsOneWidget);
    });
  });

  group('MainNavigationPage adaptive bottom bar', () {
    testWidgets('single-module access shows only Inicio + that tab, no "+" button',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        const MainNavigationPage(),
        db: db,
        readableModules: ['ventas'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsWidgets);
      expect(find.text('Ventas'), findsWidgets);
      expect(find.text('Inventario'), findsNothing);
      expect(find.text('Contactos'), findsNothing);
      expect(find.text('Reportes'), findsNothing);

      // El "+" de creación rápida ya no existe en la barra inferior.
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('tapping the Ventas tab opens its landing menu, not a segmented control',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        const MainNavigationPage(),
        db: db,
        readableModules: ['ventas', 'compras'],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(LandingCard, 'Ventas'), findsOneWidget);
      expect(find.widgetWithText(LandingCard, 'Compras'), findsOneWidget);
    });

    testWidgets('zero module access shows only the Inicio tab', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        const MainNavigationPage(),
        db: db,
        readableModules: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsWidgets);
      expect(find.text('Inventario'), findsNothing);
      expect(find.text('Ventas'), findsNothing);
      expect(find.text('Contactos'), findsNothing);
      expect(find.text('Reportes'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets(
      'regression: the bottom bar renders once readableModulesProvider '
      'resolves, even when it resolves after the first build (cold-start '
      'style race between the permission query and the first frame)',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              readableModulesProvider.overrideWith((ref) async {
                // Simula la consulta de permisos resolviendo después del
                // primer frame, como puede ocurrir en un arranque en frío.
                await Future.delayed(const Duration(milliseconds: 300));
                return ['ventas', 'compras'];
              }),
            ],
            child: MaterialApp(theme: lightTheme, home: const MainNavigationPage()),
          ),
        );

        // Justo después del primer frame el future todavía no se resolvió:
        // no debe verse ningún tab todavía (solo el loader), no una barra
        // vacía o rota.
        await tester.pump();
        expect(find.text('Inicio'), findsNothing);

        // Una vez resuelto, la barra debe aparecer con sus tabs completos.
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text('Inicio'), findsWidgets);
        expect(find.text('Ventas'), findsWidgets);
      },
    );
  });
}
