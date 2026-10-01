import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/status_filter.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/events_page.dart';
import 'package:offline_first_bi/presentation/pages/materials_page.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'search_helpers.dart';

// Buscadores y filtros de estado de Materiales, Registro de uso, Eventos y
// Ubicaciones, y selectores que no listan nada hasta que se escribe.

void main() {
  group('StatusFilter.matches', () {
    test('all keeps everything, active/inactive split by flag', () {
      expect(StatusFilter.all.matches(true), isTrue);
      expect(StatusFilter.all.matches(false), isTrue);
      expect(StatusFilter.active.matches(true), isTrue);
      expect(StatusFilter.active.matches(false), isFalse);
      expect(StatusFilter.inactive.matches(true), isFalse);
      expect(StatusFilter.inactive.matches(false), isTrue);
    });

    test('every list filter starts on "all"', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(materialStatusFilterProvider), StatusFilter.all);
      expect(c.read(eventStatusFilterProvider), StatusFilter.all);
      expect(c.read(locationStatusFilterProvider), StatusFilter.all);
    });
  });

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(412, 915);
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

  Future<int> unitId(String name) async =>
      (await (db.select(db.units)..where((u) => u.name.equals(name))).getSingle()).id;

  Future<void> addMaterial(String name, {bool active = true}) async {
    await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: name,
        unitId: await unitId('unidad'),
        pricePerUnit: 2.0,
        stock: const Value(10),
        isActive: Value(active),
      ),
    );
  }

  Future<void> chooseStatus(WidgetTester tester, String current, String next) async {
    await tester.tap(find.text(current).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(next).last);
    await tester.pumpAndSettle();
  }

  group('Materiales', () {
    setUp(() async {
      await addMaterial('Botones');
      await addMaterial('Cinta');
      await addMaterial('Tela vieja', active: false);
    });

    testWidgets('search by name (accent/case-insensitive) narrows the list', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: MaterialsListTab()));
      expect(find.text('Botones'), findsOneWidget);
      expect(find.text('Cinta'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Buscar material'), 'BOT');
      await tester.pumpAndSettle();
      expect(find.text('Botones'), findsOneWidget);
      expect(find.text('Cinta'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Buscar material'), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets('status filter: Todos by default, then Activos / Inactivos', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: MaterialsListTab()));
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Tela vieja'), findsOneWidget);

      await chooseStatus(tester, 'Todos', 'Activos');
      expect(find.text('Botones'), findsOneWidget);
      expect(find.text('Tela vieja'), findsNothing);

      await chooseStatus(tester, 'Activos', 'Inactivos');
      expect(find.text('Tela vieja'), findsOneWidget);
      expect(find.text('Botones'), findsNothing);
    });

    testWidgets('Registro de uso: no separate "Buscar material" bar; the whole log is listed', (
      tester,
    ) async {
      final productId = await db.into(db.products).insert(
        ProductsCompanion.insert(categoryId: 1, name: 'Acuarela', priceA: 55, priceB: 40),
      );
      final materials = await db.select(db.materials).get();
      for (final m in materials.where((m) => m.name != 'Tela vieja')) {
        await db.into(db.productMaterials).insert(
          ProductMaterialsCompanion.insert(
            productId: productId,
            materialId: m.id,
            quantityUsed: 1,
          ),
        );
      }
      await pump(tester, const Scaffold(body: MaterialsUsageTab()));
      await pickFromSearch(tester, find.byType(SearchablePickerField<int>).first, 'Acuarela', 'Acuarela');
      expect(find.text('Botones'), findsOneWidget);
      expect(find.text('Cinta'), findsOneWidget);
      // La pestaña ya no tiene buscador de materiales.
      expect(find.widgetWithText(TextField, 'Buscar material'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Registro de uso: the product is picked by searching too', (
      tester,
    ) async {
      await db.into(db.products).insert(
        ProductsCompanion.insert(categoryId: 1, name: 'Acuarela', priceA: 55, priceB: 40),
      );
      await db.into(db.products).insert(
        ProductsCompanion.insert(categoryId: 1, name: 'Collar', priceA: 10, priceB: 8),
      );
      await pump(tester, const Scaffold(body: MaterialsUsageTab()));
      expect(find.byType(DropdownButton<int>), findsNothing);

      await tester.tap(find.byType(SearchablePickerField<int>));
      await tester.pumpAndSettle();
      // Sin escribir no hay lista de productos.
      expect(find.text('Escribe para buscar'), findsOneWidget);
      expect(find.text('Acuarela'), findsNothing);
      expect(find.text('Collar'), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'COL');
      await tester.pumpAndSettle();
      expect(find.text('Collar'), findsOneWidget);
      expect(find.text('Acuarela'), findsNothing);

      await tester.tap(find.text('Collar').last);
      await tester.pumpAndSettle();
      // Elegido: el campo muestra el producto y se habilita el registro.
      expect(find.text('Collar'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Registro de uso sheet: Material is a search picker like Producto', (
      tester,
    ) async {
      await db.into(db.products).insert(
        ProductsCompanion.insert(categoryId: 1, name: 'Acuarela', priceA: 55, priceB: 40),
      );
      await pump(tester, const Scaffold(body: MaterialsUsageTab()));
      await pickFromSearch(tester, find.byType(SearchablePickerField<int>).first, 'Acuarela', 'Acuarela');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Producto (pestaña, detrás de la hoja) y Material (hoja): dos buscadores.
      expect(find.byType(SearchablePickerField<int>), findsNWidgets(2));
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);

      await tester.tap(find.byType(SearchablePickerField<int>).last);
      await tester.pumpAndSettle();
      // Sin escribir no hay lista de materiales.
      expect(find.text('Escribe para buscar'), findsOneWidget);
      expect(find.text('Botones'), findsNothing);
      expect(find.text('Cinta'), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'cin');
      await tester.pumpAndSettle();
      expect(find.text('Cinta'), findsOneWidget);
      expect(find.text('Botones'), findsNothing);

      // Los inactivos nunca se ofrecen.
      await tester.enterText(find.byType(TextField).last, 'tela');
      await tester.pumpAndSettle();
      expect(find.text('Tela vieja'), findsNothing);
      expect(find.text('Sin resultados'), findsOneWidget);
    });
  });

  group('Eventos y Ubicaciones', () {
    setUp(() async {
      final activeLoc = await db.into(db.locations).insert(
        LocationsCompanion.insert(city: 'La Paz', country: 'Bolivia'),
      );
      await db.into(db.locations).insert(
        LocationsCompanion.insert(
          city: 'Sucre',
          country: 'Bolivia',
          isActive: const Value(false),
        ),
      );
      await db.into(db.events).insert(
        EventsCompanion.insert(
          name: 'Feria Activa',
          startDate: DateTime(2026, 1, 1),
          locationId: Value(activeLoc),
        ),
      );
      await db.into(db.events).insert(
        EventsCompanion.insert(
          name: 'Feria Cerrada',
          startDate: DateTime(2026, 2, 1),
          isActive: const Value(false),
        ),
      );
    });

    testWidgets('Eventos: Todos / Activos / Inactivos', (tester) async {
      await pump(tester, const EventsPage());
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Feria Activa'), findsOneWidget);
      expect(find.text('Feria Cerrada'), findsOneWidget);

      await chooseStatus(tester, 'Todos', 'Activos');
      expect(find.text('Feria Activa'), findsOneWidget);
      expect(find.text('Feria Cerrada'), findsNothing);

      await chooseStatus(tester, 'Activos', 'Inactivos');
      expect(find.text('Feria Cerrada'), findsOneWidget);
      expect(find.text('Feria Activa'), findsNothing);
    });

    testWidgets('Ubicaciones: Todas / Activas / Inactivas', (tester) async {
      await pump(tester, const EventsPage());
      await tester.tap(find.text('Ubicaciones').first);
      await tester.pumpAndSettle();
      expect(find.text('Todas'), findsOneWidget);
      expect(find.textContaining('La Paz'), findsWidgets);
      expect(find.textContaining('Sucre'), findsWidgets);

      await chooseStatus(tester, 'Todas', 'Activas');
      expect(find.textContaining('La Paz'), findsWidgets);
      expect(find.textContaining('Sucre'), findsNothing);

      await chooseStatus(tester, 'Activas', 'Inactivas');
      expect(find.textContaining('Sucre'), findsWidgets);
      expect(find.textContaining('La Paz'), findsNothing);
    });
  });

  group('Selectores sin lista hasta escribir', () {
    setUp(() async {
      await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Maria'));
      await db.into(db.suppliers).insert(SuppliersCompanion.insert(name: 'Proveedor Andino'));
      await addMaterial('Tela');
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Collar',
          priceA: 10,
          priceB: 8,
          stock: const Value(5),
        ),
      );
    });

    Future<void> openSheet(WidgetTester tester, Widget dialog) async {
      await pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => dialog,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('Ventas: Producto and Cliente show nothing until typing', (
      tester,
    ) async {
      await openSheet(tester, const SaleDialog());
      expect(find.text('Collar'), findsNothing);
      expect(find.text('Escribe para buscar un producto'), findsOneWidget);
      await searchProducts(tester, 'col');
      expect(find.text('Collar'), findsOneWidget);

      await tester.tap(find.byType(SearchablePickerField<int>).first);
      await tester.pumpAndSettle();
      expect(find.text('Maria'), findsNothing);
      expect(find.text('Escribe para buscar'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'mar');
      await tester.pumpAndSettle();
      expect(find.text('Maria'), findsOneWidget);
    });

    testWidgets('Compras: Proveedor and Material show nothing until typing', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog());
      await tester.tap(find.byType(SearchablePickerField<int>).first);
      await tester.pumpAndSettle();
      expect(find.text('Proveedor Andino'), findsNothing);
      expect(find.text('Escribe para buscar'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'and');
      await tester.pumpAndSettle();
      expect(find.text('Proveedor Andino'), findsOneWidget);
      await tester.tap(find.text('Proveedor Andino').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SearchablePickerField<int>).last);
      await tester.pumpAndSettle();
      expect(find.text('Tela'), findsNothing);
      expect(find.text('Escribe para buscar'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'tel');
      await tester.pumpAndSettle();
      expect(find.text('Tela'), findsOneWidget);
    });
  });
}
