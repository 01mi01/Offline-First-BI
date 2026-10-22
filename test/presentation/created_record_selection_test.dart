import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/client_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/location_provider.dart';
import 'package:offline_first_bi/application/material_provider.dart';
import 'package:offline_first_bi/application/supplier_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/dialogs/event_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'form_finders.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openSheet(WidgetTester tester, Widget sheet) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => sheet,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Open')),
    );
    await container.read(clientProvider.notifier).load();
    await container.read(supplierProvider.notifier).load();
    await container.read(locationProvider.notifier).load();
    await container.read(materialProvider.notifier).load();
    await tester.pumpAndSettle();
  }

  int? selectedId(WidgetTester tester, String label) => tester
      .widget<SearchablePickerField<int>>(
        find.byWidgetPredicate(
          (w) => w is SearchablePickerField<int> && w.label == label,
        ),
      )
      .value;

  Future<int> unitId(String name) async =>
      (await db.select(db.units).get()).firstWhere((u) => u.name == name).id;

  Future<int> newestId(String table) async {
    final rows = await db
        .customSelect('SELECT MAX(id) AS id FROM $table')
        .get();
    return rows.single.read<int>('id');
  }

  testWidgets('a client created from the sale form is the one selected', (
    tester,
  ) async {
    await openSheet(tester, const SaleDialog());
    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldLabeled('Nombre'), 'Cliente nuevo');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    final newId = await newestId('clients');
    expect(selectedId(tester, 'Cliente'), newId);
    expect(newId, isNot(1));
  });

  testWidgets('a supplier created from the purchase form is the one selected', (
    tester,
  ) async {
    await openSheet(tester, const PurchaseDialog());
    await tester.tap(find.text('Nuevo proveedor'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldLabeled('Nombre'), 'Proveedor nuevo');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    final newId = await newestId('suppliers');
    expect(selectedId(tester, 'Proveedor'), newId);
    expect(newId, isNot(1));
  });

  testWidgets('a location in a new city is selected from the event form', (
    tester,
  ) async {
    await openSheet(tester, const EventDialog());
    await tester.tap(find.text('Nueva ubicación'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldLabeled('Ciudad'), 'Oruro');
    await tester.enterText(fieldLabeled('País'), 'Bolivia');
    await tester.tap(find.text('Crear').last);
    await tester.pumpAndSettle();

    expect(selectedId(tester, 'Ubicación'), await newestId('locations'));
  });

  testWidgets(
    'a location in a city that already has one selects the new location',
    (tester) async {
      final oldId = await db
          .into(db.locations)
          .insert(
            LocationsCompanion.insert(
              city: 'Cochabamba',
              country: 'Bolivia',
              description: const Value('Norte'),
            ),
          );
      await openSheet(tester, const EventDialog());
      await tester.tap(find.text('Nueva ubicación'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldLabeled('Ciudad'), 'Cochabamba');
      await tester.enterText(fieldLabeled('País'), 'Bolivia');
      await tester.enterText(fieldLabeled('Descripción'), 'Sur');
      await tester.tap(find.text('Crear').last);
      await tester.pumpAndSettle();

      final newId = await newestId('locations');
      expect(newId, isNot(oldId));
      expect(selectedId(tester, 'Ubicación'), newId);
    },
  );

  Future<void> createMaterialFromPurchaseLine(
    WidgetTester tester, {
    required String name,
    required String stock,
    required String price,
  }) async {
    await tester.tap(materialsAddButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo material'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldLabeled('Nombre'), name);
    await tester.tap(find.byTooltip('Unidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<int>, 'unidad'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldLabeled('Stock'), stock);
    await tester.enterText(fieldLabeled('Precio por unidad'), price);
    await tester.tap(find.text('Crear').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a material with the name of an existing one selects the new material',
    (tester) async {
      final oldId = await db
          .into(db.materials)
          .insert(
            MaterialsCompanion.insert(
              name: 'Tela',
              unitId: await unitId('unidad'),
              stock: const Value(5),
              pricePerUnit: 2,
            ),
          );
      await openSheet(tester, const PurchaseDialog());
      await createMaterialFromPurchaseLine(
        tester,
        name: 'Tela',
        stock: '3',
        price: '4',
      );

      final newId = await newestId('materials');
      expect(newId, isNot(oldId));
      expect(selectedId(tester, 'Material'), newId);
      expect(find.widgetWithText(TextField, '4.00'), findsOneWidget);
      expect(find.widgetWithText(TextField, '2.00'), findsNothing);
    },
  );

  testWidgets('a material with a new name is selected with an empty quantity', (
    tester,
  ) async {
    await openSheet(tester, const PurchaseDialog());
    await createMaterialFromPurchaseLine(
      tester,
      name: 'Hilo',
      stock: '3',
      price: '4',
    );

    expect(selectedId(tester, 'Material'), await newestId('materials'));
    expect(find.widgetWithText(TextField, '4.00'), findsOneWidget);
    final quantity = tester.widget<TextField>(
      find.widgetWithText(TextField, '0'),
    );
    expect(quantity.controller!.text, isEmpty);
  });

  test('the save methods return the id of the record they saved', () async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final first = await container
        .read(locationProvider.notifier)
        .save(city: 'La Paz', country: 'Bolivia', description: 'Centro');
    final second = await container
        .read(locationProvider.notifier)
        .save(city: 'La Paz', country: 'Bolivia', description: 'Sur');
    expect(second, isNot(first));
    final edited = await container
        .read(locationProvider.notifier)
        .save(
          id: first,
          city: 'La Paz',
          country: 'Bolivia',
          description: 'Norte',
        );
    expect(edited, first);

    final unit = await unitId('unidad');
    final oldMaterial = await container
        .read(materialProvider.notifier)
        .save(name: 'Tela', unitId: unit, stock: 0, pricePerUnit: 2);
    final newMaterial = await container
        .read(materialProvider.notifier)
        .save(name: 'Tela', unitId: unit, stock: 3, pricePerUnit: 4);
    expect(newMaterial, isNot(oldMaterial));
    final stored = await db.select(db.materials).get();
    expect(stored.firstWhere((m) => m.id == newMaterial).pricePerUnit, 4);

    final client = await container
        .read(clientProvider.notifier)
        .saveWithId(name: 'Ana');
    expect(client.error, isNull);
    expect(client.id, isNotNull);
    final duplicate = await container
        .read(clientProvider.notifier)
        .saveWithId(name: 'Ana');
    expect(duplicate.id, isNull);
    expect(duplicate.error, isNotNull);
  });
}
