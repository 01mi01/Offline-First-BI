import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/presentation/pages/categories_page.dart';
import 'package:offline_first_bi/presentation/pages/clients_page.dart';
import 'package:offline_first_bi/presentation/pages/events_page.dart';
import 'package:offline_first_bi/presentation/pages/products_page.dart';
import 'package:offline_first_bi/presentation/pages/purchases_page.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/presentation/pages/suppliers_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'package:offline_first_bi/config/app_clock.dart';

// Cancelar una compra desde su formulario de edición, y los buscadores y
// filtros de Clientes, Proveedores, Eventos, Ubicaciones y Productos, más el
// orden de los filtros de Ventas y Compras.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: lightTheme, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('cancelar una compra desde "Editar compra"', () {
    late int materialId;

    setUp(() async {
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals('unidad'))).getSingle();
      materialId = await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Tela negra',
          unitId: unit.id,
          pricePerUnit: 2,
          stock: const Value(10),
        ),
      );
    });

    Future<double> stock() async => (await (db.select(
      db.materials,
    )..where((m) => m.id.equals(materialId))).getSingle()).stock;

    Future<void> buyMaterial() => PurchaseRepository(db).createPurchase(
      supplierId: null,
      isMaterial: true,
      description: null,
      totalAmount: 15,
      date: appNow(),
      locationId: null,
      eventId: null,
      items: [
        {'materialId': materialId, 'quantity': 5.0, 'unitPrice': 3.0},
      ],
    );

    Future<void> openEdit(WidgetTester tester) async {
      await pump(tester, const PurchasesListBody());
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Editar compra'), findsOneWidget);
    }

    testWidgets('the list has no cancel icon, and "Nueva compra" offers no cancel option', (
      tester,
    ) async {
      await buyMaterial();
      await pump(tester, const PurchasesListBody());
      expect(find.byIcon(Icons.cancel_outlined), findsNothing);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Nueva compra'), findsOneWidget);
      expect(find.text('Cancelar compra'), findsNothing);
    });

    testWidgets('confirming subtracts the stock, and the purchase stays as "Cancelada" with no edit button', (
      tester,
    ) async {
      await buyMaterial();
      expect(await stock(), 15);
      await openEdit(tester);

      await tester.ensureVisible(find.text('Cancelar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar compra'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cancelar compra?'), findsOneWidget);
      await tester.tap(find.text('Cancelar compra').last);
      await tester.pumpAndSettle();

      expect(await stock(), 10);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect((await PurchaseRepository(db).getAll()).single.isCanceled, isTrue);
    });

    testWidgets('"Volver" leaves the purchase and the stock untouched', (tester) async {
      await buyMaterial();
      await openEdit(tester);
      await tester.ensureVisible(find.text('Cancelar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(await stock(), 15);
      expect((await PurchaseRepository(db).getAll()).single.isCanceled, isFalse);
    });

    testWidgets('a cancellation that would leave negative stock is blocked with the message and changes nothing', (
      tester,
    ) async {
      await buyMaterial();
      // El material ya se usó: solo quedan 3 de los 5 comprados.
      await (db.update(db.materials)..where((m) => m.id.equals(materialId)))
          .write(const MaterialsCompanion(stock: Value(3)));
      await openEdit(tester);

      await tester.ensureVisible(find.text('Cancelar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar compra').last);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No se puede cancelar la compra porque el stock actual de uno de los '
          'materiales es menor a la cantidad comprada.',
        ),
        findsOneWidget,
      );
      expect(await stock(), 3);
      expect((await PurchaseRepository(db).getAll()).single.isCanceled, isFalse);
    });

    testWidgets('a general expense can be canceled too, with no stock effect', (tester) async {
      await PurchaseRepository(db).createPurchase(
        supplierId: null,
        isMaterial: false,
        description: 'Pasaje',
        totalAmount: 20,
        date: appNow(),
        locationId: null,
        eventId: null,
        items: const [],
      );
      await openEdit(tester);
      await tester.ensureVisible(find.text('Cancelar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar compra').last);
      await tester.pumpAndSettle();

      expect(find.text('Cancelada'), findsOneWidget);
      expect(await stock(), 10);
    });

    testWidgets('a canceled purchase still counts in the list but not in "Compras actuales" differently from a sale: it follows the same date rules', (
      tester,
    ) async {
      await PurchaseRepository(db).createPurchase(
        supplierId: null,
        isMaterial: false,
        description: 'Gasto futuro',
        totalAmount: 20,
        date: appNow().add(const Duration(days: 3)),
        locationId: null,
        eventId: null,
        items: const [],
      );
      final id = (await PurchaseRepository(db).getAll()).single.id;
      await PurchaseRepository(db).cancelPurchase(id);
      await pump(tester, const PurchasesListBody());
      // Cancelada y con fecha futura: "Compras actuales" la oculta, igual que
      // a una venta cancelada con fecha futura.
      expect(find.text('Gasto futuro'), findsNothing);
      await tester.tap(find.text('Compras actuales'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas').last);
      await tester.pumpAndSettle();
      expect(find.text('Gasto futuro'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
    });
  });

  group('orden de los filtros de Ventas y Compras', () {
    testWidgets('Ventas: "Ventas actuales" on top, then the presets, then Desde / Hasta', (
      tester,
    ) async {
      await db.into(db.sales).insert(
        SalesCompanion.insert(totalAmount: 10, finalAmount: 10, date: appNow()),
      );
      await pump(tester, const SalesListBody());
      final time = tester.getCenter(find.text('Ventas actuales'));
      final presets = tester.getCenter(find.text('Hoy'));
      final from = tester.getCenter(find.text('Desde'));
      expect(time.dy, lessThan(presets.dy));
      expect(presets.dy, lessThan(from.dy));
      expect(time.dx, greaterThan(250)); // alineado a la derecha
    });

    testWidgets('Compras: Tipo and "Compras actuales" on top, then presets, then Desde / Hasta', (
      tester,
    ) async {
      await PurchaseRepository(db).createPurchase(
        supplierId: null,
        isMaterial: false,
        description: 'Algo',
        totalAmount: 5,
        date: appNow(),
        locationId: null,
        eventId: null,
        items: const [],
      );
      await pump(tester, const PurchasesListBody());
      final tipo = tester.getCenter(find.text('Tipo'));
      final time = tester.getCenter(find.text('Compras actuales'));
      final presets = tester.getCenter(find.text('Hoy'));
      final from = tester.getCenter(find.text('Desde'));
      expect(tipo.dy, closeTo(time.dy, 4));
      expect(tipo.dy, lessThan(presets.dy));
      expect(presets.dy, lessThan(from.dy));
    });
  });

  group('Clientes y Proveedores: buscador y estado', () {
    testWidgets('Clientes: "Buscar cliente" matches the name, and the Activo filter splits active / inactive', (
      tester,
    ) async {
      await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Ana Martínez'));
      await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Michael Brown'));
      await db.into(db.clients).insert(
        ClientsCompanion.insert(name: 'Laura Inactiva', isActive: const Value(false)),
      );
      await pump(tester, const ClientsListBody());

      expect(find.text('Buscar cliente'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget); // por defecto
      expect(find.text('Ana Martínez'), findsOneWidget);
      expect(find.text('Michael Brown'), findsOneWidget);
      expect(find.text('Laura Inactiva'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'martinez');
      await tester.pumpAndSettle();
      expect(find.text('Ana Martínez'), findsOneWidget);
      expect(find.text('Michael Brown'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactivos').last);
      await tester.pumpAndSettle();
      expect(find.text('Laura Inactiva'), findsOneWidget);
      expect(find.text('Ana Martínez'), findsNothing);

      await tester.tap(find.text('Inactivos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activos').last);
      await tester.pumpAndSettle();
      expect(find.text('Laura Inactiva'), findsNothing);
      expect(find.text('Michael Brown'), findsOneWidget);
    });

    testWidgets('Proveedores: "Buscar proveedor" and the same filter', (tester) async {
      await db.into(db.suppliers).insert(SuppliersCompanion.insert(name: 'Riverside Supply Co.'));
      await db.into(db.suppliers).insert(
        SuppliersCompanion.insert(name: 'Papelera Vieja', isActive: const Value(false)),
      );
      await pump(tester, const SuppliersListBody());

      expect(find.text('Buscar proveedor'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'river');
      await tester.pumpAndSettle();
      expect(find.text('Riverside Supply Co.'), findsOneWidget);
      expect(find.text('Papelera Vieja'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactivos').last);
      await tester.pumpAndSettle();
      expect(find.text('Papelera Vieja'), findsOneWidget);
      expect(find.text('Riverside Supply Co.'), findsNothing);
    });
  });

  group('Eventos y Ubicaciones', () {
    setUp(() async {
      final lpz = await db.into(db.locations).insert(
        LocationsCompanion.insert(city: 'La Paz', country: 'Bolivia'),
      );
      await db.into(db.locations).insert(
        LocationsCompanion.insert(city: 'Santa Cruz', country: 'Bolivia'),
      );
      await db.into(db.locations).insert(
        LocationsCompanion.insert(city: 'Lima', country: 'Perú'),
      );
      await db.into(db.events).insert(
        EventsCompanion.insert(
          name: 'Feria de Arte',
          startDate: appNow(),
          locationId: Value(lpz),
        ),
      );
      await db.into(db.events).insert(
        EventsCompanion.insert(name: 'Exposición de Libros', startDate: appNow()),
      );
    });

    testWidgets('Eventos: the status filter is on top (right), then the date filter, then "Buscar evento"', (
      tester,
    ) async {
      await pump(tester, const EventsPage());
      final status = tester.getCenter(find.text('Todos'));
      final presets = tester.getCenter(find.text('Hoy'));
      final search = tester.getCenter(find.text('Buscar evento'));
      final firstEvent = tester.getCenter(find.text('Exposición de Libros'));
      expect(status.dy, lessThan(presets.dy));
      expect(status.dx, greaterThan(300));
      expect(search.dy, greaterThan(status.dy));
      expect(search.dy, lessThan(firstEvent.dy));

      await tester.enterText(find.widgetWithText(TextField, 'Buscar evento'), 'feria');
      await tester.pumpAndSettle();
      expect(find.text('Feria de Arte'), findsOneWidget);
      expect(find.text('Exposición de Libros'), findsNothing);
    });

    Future<void> openLocations(WidgetTester tester) async {
      await pump(tester, const EventsPage());
      await tester.tap(find.widgetWithText(Tab, 'Ubicaciones'));
      await tester.pumpAndSettle();
    }

    testWidgets('Ubicaciones: search plus País and Ciudad dropdowns with their defaults', (
      tester,
    ) async {
      await openLocations(tester);
      expect(find.text('Buscar ubicación'), findsOneWidget);
      expect(find.text('Todos los países'), findsOneWidget);
      expect(find.text('Todas las ciudades'), findsOneWidget);
      expect(find.text('La Paz, Bolivia'), findsOneWidget);
      expect(find.text('Lima, Perú'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'santa');
      await tester.pumpAndSettle();
      expect(find.text('Santa Cruz, Bolivia'), findsOneWidget);
      expect(find.text('La Paz, Bolivia'), findsNothing);
    });

    testWidgets('Ubicaciones: the search also finds a location by its zone (description)', (
      tester,
    ) async {
      await db.into(db.locations).insert(
        LocationsCompanion.insert(
          city: 'Santa Cruz',
          country: 'Bolivia',
          description: const Value('Las Palmas'),
        ),
      );
      await openLocations(tester);

      await tester.enterText(find.byType(TextField), 'palmas');
      await tester.pumpAndSettle();
      expect(find.text('Las Palmas'), findsOneWidget);
      expect(find.text('Santa Cruz, Bolivia'), findsOneWidget);
      expect(find.text('La Paz, Bolivia'), findsNothing);
    });

    testWidgets('Ubicaciones: the cities narrow to the chosen country and both filters combine', (
      tester,
    ) async {
      await openLocations(tester);

      await tester.tap(find.text('Todos los países'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perú').last);
      await tester.pumpAndSettle();
      expect(find.text('Lima, Perú'), findsOneWidget);
      expect(find.text('La Paz, Bolivia'), findsNothing);

      // Las ciudades ofrecidas son solo las de Perú.
      await tester.tap(find.text('Todas las ciudades'));
      await tester.pumpAndSettle();
      expect(find.text('Lima'), findsWidgets);
      expect(find.text('La Paz'), findsNothing);
      expect(find.text('Santa Cruz'), findsNothing);
      await tester.tap(find.text('Lima').last);
      await tester.pumpAndSettle();
      expect(find.text('Lima, Perú'), findsOneWidget);

      // Cambiar a Bolivia quita la ciudad elegida (ya no pertenece al país).
      await tester.tap(find.text('Perú'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bolivia').last);
      await tester.pumpAndSettle();
      expect(find.text('Todas las ciudades'), findsOneWidget);
      expect(find.text('La Paz, Bolivia'), findsOneWidget);
      expect(find.text('Santa Cruz, Bolivia'), findsOneWidget);
      expect(find.text('Lima, Perú'), findsNothing);
    });
  });

  group('Productos y Categorías', () {
    testWidgets('Productos: the Activo filter (Todos by default) shows active / inactive products', (
      tester,
    ) async {
      await db.into(db.products).insert(
        ProductsCompanion.insert(categoryId: 1, name: 'Estuches', priceA: 10, priceB: 8),
      );
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Libro viejo',
          priceA: 10,
          priceB: 8,
          isActive: const Value(false),
        ),
      );
      await pump(tester, const ProductsPage());
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Estuches'), findsOneWidget);
      expect(find.text('Libro viejo'), findsOneWidget);

      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactivos').last);
      await tester.pumpAndSettle();
      expect(find.text('Libro viejo'), findsOneWidget);
      expect(find.text('Estuches'), findsNothing);

      await tester.tap(find.text('Inactivos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activos').last);
      await tester.pumpAndSettle();
      expect(find.text('Estuches'), findsOneWidget);
      expect(find.text('Libro viejo'), findsNothing);
    });

    testWidgets('Categorías: the status filter is on top and the search and the toggle share the row below, in both views', (
      tester,
    ) async {
      await pump(tester, const CategoriesPage());
      Map<String, Offset> controls() => {
        'status': tester.getCenter(find.text('Todas')),
        'search': tester.getCenter(find.byType(TextField)),
        'list': tester.getCenter(find.byIcon(Icons.list)),
        'grid': tester.getCenter(find.byIcon(Icons.grid_view_rounded)),
      };
      final inList = controls();
      expect(inList['status']!.dy, lessThan(inList['search']!.dy));
      expect(inList['status']!.dx, greaterThan(300));
      expect(inList['search']!.dy, closeTo(inList['list']!.dy, 4));
      expect(inList['search']!.dx, lessThan(inList['list']!.dx));

      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
      final inGrid = controls();
      for (final key in inList.keys) {
        expect(inGrid[key], inList[key], reason: key);
      }
    });
  });
}
