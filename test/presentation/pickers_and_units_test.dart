import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/search_filter.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/models/material_model.dart';
import 'package:offline_first_bi/models/unit_model.dart';
import 'package:offline_first_bi/presentation/dialogs/material_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/materials_page.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/presentation/widgets/unit_quantity_input.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'search_helpers.dart';

void _phone(WidgetTester tester, {Size size = const Size(412, 915)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openSheet(
  WidgetTester tester,
  AppDatabase db,
  Widget sheet, {
  Size size = const Size(412, 915),
}) async {
  _phone(tester, size: size);
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
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Unit> unitNamed(String name) async =>
      (await (db.select(db.units)..where((u) => u.name.equals(name))).getSingle());

  group('filterByQuery (texto escrito -> coincidencias)', () {
    final names = ['Ana Martínez', 'Sarah Davis', 'Café Central', 'Cañete', 'Laura Thompson'];

    List<String> find(String q) => filterByQuery<String>(names, q, (n) => n);

    test('an empty query returns everything, in order', () {
      expect(find(''), names);
      expect(find('   '), names);
    });

    test('matches anywhere in the name, ignoring case', () {
      expect(find('sar'), ['Sarah Davis']);
      expect(find('DAV'), ['Sarah Davis']);
      expect(find('a'), ['Ana Martínez', 'Sarah Davis', 'Café Central', 'Cañete', 'Laura Thompson']);
    });

    test('ignores accents and ñ in both the text and the query', () {
      expect(find('cafe'), ['Café Central']);
      expect(find('café'), ['Café Central']);
      expect(find('canete'), ['Cañete']);
      expect(find('cañ'), ['Cañete']);
    });

    test('returns nothing when no name matches', () {
      expect(find('xyz'), isEmpty);
    });
  });

  group('SearchablePickerField', () {
    final options = [
      const PickerOption<int>(null, 'Sin nombre'),
      for (var i = 1; i <= 120; i++)
        PickerOption<int>(i, 'Cliente ${i.toString().padLeft(3, '0')}'),
      const PickerOption<int>(500, 'Café Central'),
    ];

    Future<void> pump(
      WidgetTester tester, {
      required ValueNotifier<int?> selected,
    }) async {
      _phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: ValueListenableBuilder<int?>(
              valueListenable: selected,
              builder: (context, value, _) => SearchablePickerField<int>(
                label: 'Cliente',
                searchHint: 'Buscar cliente',
                value: value,
                options: options,
                onChanged: (v) => selected.value = v,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the selected option and opens a searchable sheet', (
      tester,
    ) async {
      final selected = ValueNotifier<int?>(null);
      await pump(tester, selected: selected);
      expect(find.text('Sin nombre'), findsOneWidget);

      await tester.tap(find.byType(SearchablePickerField<int>));
      await tester.pumpAndSettle();
      expect(find.text('Buscar cliente'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('typing filters a 120+ item list down to the matches', (
      tester,
    ) async {
      final selected = ValueNotifier<int?>(null);
      await pump(tester, selected: selected);
      await tester.tap(find.byType(SearchablePickerField<int>));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '045');
      await tester.pumpAndSettle();
      expect(find.text('Cliente 045'), findsOneWidget);
      expect(find.text('Cliente 044'), findsNothing);
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('Sin nombre')),
        findsNothing,
      );

      await tester.enterText(find.byType(TextField), 'cliente 11');
      await tester.pumpAndSettle();
      // 110..119 y 011: todas contienen "cliente 11"
      expect(find.text('Cliente 110'), findsOneWidget);
      expect(find.text('Cliente 012'), findsNothing);
      // La lista de resultados se desplaza: el resto está más abajo.
      await tester.scrollUntilVisible(
        find.text('Cliente 119'),
        50,
        scrollable: find.descendant(
          of: find.descendant(
            of: find.byType(SearchablePickerField<int>),
            matching: find.byType(ListView),
          ),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Cliente 119'), findsOneWidget);
    });

    testWidgets('is accent-insensitive and shows "Sin resultados" when nothing matches', (
      tester,
    ) async {
      final selected = ValueNotifier<int?>(null);
      await pump(tester, selected: selected);
      await tester.tap(find.byType(SearchablePickerField<int>));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cafe');
      await tester.pumpAndSettle();
      expect(find.text('Café Central'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets('inside a scrolling form the results end up above the keyboard', (
      tester,
    ) async {
      _phone(tester, size: const Size(360, 640));
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Flex(
                direction: Axis.vertical,
                children: [
                  const SizedBox(height: 520),
                  SearchablePickerField<int>(
                    label: 'Cliente',
                    searchHint: 'Buscar cliente',
                    value: null,
                    options: options,
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );
      // Teclado de 300 px.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'cliente 04');
      await tester.pumpAndSettle();

      final result = tester.getRect(find.text('Cliente 040'));
      expect(result.bottom, lessThanOrEqualTo(640 - 300));
      expect(result.top, greaterThanOrEqualTo(0));
    });

    testWidgets('picking a filtered option selects it; the default (null) option is selectable too', (
      tester,
    ) async {
      final selected = ValueNotifier<int?>(null);
      await pump(tester, selected: selected);

      await tester.tap(find.byType(SearchablePickerField<int>));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '077');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente 077'));
      await tester.pumpAndSettle();

      expect(selected.value, 77);
      expect(find.text('Cliente 077'), findsOneWidget); // ahora en el campo

      await tester.tap(find.byType(SearchablePickerField<int>));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sin');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin nombre'));
      await tester.pumpAndSettle();
      expect(selected.value, isNull);
      expect(find.text('Sin nombre'), findsOneWidget);
    });

    testWidgets('closing the sheet without choosing keeps the current value', (
      tester,
    ) async {
      final selected = ValueNotifier<int?>(3);
      await pump(tester, selected: selected);

      await tester.tap(find.byType(SearchablePickerField<int>));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40)); // fuera de la hoja
      await tester.pumpAndSettle();

      expect(selected.value, 3);
    });
  });

  group('the four searchable pickers', () {
    testWidgets('Cliente (Ventas) filters by typed text and picks the match', (
      tester,
    ) async {
      for (final name in ['John Smith', 'Sarah Davis', 'David Wilson']) {
        await db.into(db.clients).insert(ClientsCompanion.insert(name: name));
      }
      await _openSheet(tester, db, const SaleDialog());

      await tester.tap(find.byType(SearchablePickerField<int>).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Buscar cliente'), 'davis');
      await tester.pumpAndSettle();
      expect(find.text('Sarah Davis'), findsOneWidget);
      expect(find.text('John Smith'), findsNothing);
      expect(find.text('David Wilson'), findsNothing);

      await tester.tap(find.text('Sarah Davis'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SearchablePickerField<int>).first,
          matching: find.text('Sarah Davis'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Producto (Ventas) is searchable by name', (tester) async {
      for (final name in ['Estuches', 'Libro', 'Miniaturas']) {
        await db.into(db.products).insert(
          ProductsCompanion.insert(
            categoryId: 1,
            name: name,
            priceA: 10,
            priceB: 10,
            stock: const Value(5),
          ),
        );
      }
      await _openSheet(tester, db, const SaleDialog());
      // Sin escribir no se muestra ninguna fila: solo la invitación a buscar.
      expect(find.text('Estuches'), findsNothing);
      expect(find.text('Miniaturas'), findsNothing);
      expect(find.text('Escribe para buscar un producto'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar producto'),
        'mini',
      );
      await tester.pumpAndSettle();
      expect(find.text('Miniaturas'), findsOneWidget);
      expect(find.text('Estuches'), findsNothing);
      expect(find.text('Libro'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar producto'),
        'nada',
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);

      // Borrar lo escrito vuelve al estado inicial: otra vez sin lista.
      await tester.enterText(find.widgetWithText(TextField, 'Buscar producto'), '');
      await tester.pumpAndSettle();
      expect(find.text('Miniaturas'), findsNothing);
      expect(find.text('Escribe para buscar un producto'), findsOneWidget);
    });

    testWidgets('Proveedor (Compras) filters by typed text and picks the match', (
      tester,
    ) async {
      for (final name in ['Riverside Supply Co.', 'Lunaris Supply', 'Veridian Trading']) {
        await db.into(db.suppliers).insert(SuppliersCompanion.insert(name: name));
      }
      await _openSheet(tester, db, const PurchaseDialog());

      await tester.tap(find.byType(SearchablePickerField<int>).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Buscar proveedor'), 'lunaris');
      await tester.pumpAndSettle();
      expect(find.text('Lunaris Supply'), findsOneWidget);
      expect(find.text('Riverside Supply Co.'), findsNothing);
      expect(find.text('Veridian Trading'), findsNothing);

      await tester.tap(find.text('Lunaris Supply'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SearchablePickerField<int>).first,
          matching: find.text('Lunaris Supply'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Material (Compras) filters by typed text, only when picking an existing one', (
      tester,
    ) async {
      final unit = await unitNamed('metro');
      for (final name in ['Resina parte B', 'Tela beige', 'Papel para stickers']) {
        await db.into(db.materials).insert(
          MaterialsCompanion.insert(
            name: name,
            unitId: unit.id,
            pricePerUnit: 2,
            stock: const Value(5),
          ),
        );
      }
      await _openSheet(tester, db, const PurchaseDialog());
      await tester.ensureVisible(find.text('Agregar'));
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      // Crear uno nuevo sigue siendo un botón aparte, sin búsqueda.
      expect(find.text('Crear nuevo material'), findsOneWidget);

      await tester.tap(find.byType(SearchablePickerField<int>).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Buscar material'), 'beige');
      await tester.pumpAndSettle();
      expect(find.text('Tela beige'), findsOneWidget);
      expect(find.text('Resina parte B'), findsNothing);
      expect(find.text('Papel para stickers'), findsNothing);

      await tester.tap(find.text('Tela beige'));
      await tester.pumpAndSettle();
      // El precio del material elegido se rellena igual que antes.
      expect(find.text('Cantidad (metro)'), findsOneWidget);
    });

    testWidgets('the "add" icon stays on the row of the search field while typing', (
      tester,
    ) async {
      await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Michael Brown'));
      await _openSheet(tester, db, const SaleDialog());

      final picker = find.byType(SearchablePickerField<int>).first;
      final field = find.descendant(of: picker, matching: find.byType(TextField));
      final add = find.byIcon(Icons.person_add_outlined);
      final before = tester.getCenter(add).dy;
      expect((tester.getCenter(field).dy - before).abs(), lessThan(1));

      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, 'mic');
      await tester.pumpAndSettle();
      // Con los resultados abiertos debajo, el icono no se mueve y sigue
      // alineado con el campo (no con campo + lista).
      expect(find.text('Michael Brown'), findsOneWidget);
      expect(tester.getCenter(add).dy, before);
      expect((tester.getCenter(field).dy - tester.getCenter(add).dy).abs(), lessThan(1));
    });

    testWidgets('Cliente, Ubicación and Evento are all inline search fields', (
      tester,
    ) async {
      await _openSheet(tester, db, const SaleDialog());

      expect(find.byType(SearchablePickerField<int>), findsNWidgets(3));
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    });

    testWidgets('a material must still be picked before adding a purchase line', (
      tester,
    ) async {
      await _openSheet(tester, db, const PurchaseDialog());
      await tester.ensureVisible(find.text('Agregar'));
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();

      expect(find.text('Selecciona un material'), findsOneWidget);
    });
  });

  group('container quantity: whole containers + a fraction', () {
    test('combine adds the whole count to the fraction into one decimal', () {
      expect(combineContainerQuantity(2, 0.25), 2.25);
      expect(combineContainerQuantity(3, 0.5), 3.5);
      expect(combineContainerQuantity(0, 0.75), 0.75);
      expect(combineContainerQuantity(4, 0), 4.0);
    });

    test('split is the inverse of combine', () {
      final parts = splitContainerQuantity(2.75);
      expect(parts.whole, 2);
      expect(parts.fraction, 0.75);
      for (final whole in [0, 1, 5]) {
        for (final f in [0.0, 0.25, 0.5, 0.75]) {
          final back = splitContainerQuantity(combineContainerQuantity(whole, f));
          expect((back.whole, back.fraction), (whole, f));
        }
      }
    });

    Future<ValueNotifier<double>> pumpPicker(
      WidgetTester tester, {
      double initial = 0,
    }) async {
      _phone(tester);
      final value = ValueNotifier<double>(initial);
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: ValueListenableBuilder<double>(
              valueListenable: value,
              builder: (context, v, _) => FractionQuantityPicker(
                unit: 'tira',
                value: v,
                onChanged: (nv) => value.value = nv,
              ),
            ),
          ),
        ),
      );
      return value;
    }

    testWidgets('"2 tiras y un cuarto" = 2.25', (tester) async {
      final value = await pumpPicker(tester);

      await tester.tap(find.byKey(const ValueKey('container-whole-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('container-whole-plus')));
      await tester.pump();
      expect(value.value, 2.0);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('container-whole-count'))).data,
        '2',
      );

      await tester.tap(find.text('Un cuarto'));
      await tester.pump();
      expect(value.value, 2.25);
      expect(find.text('Total: 2.25 tiras'), findsOneWidget);
    });

    testWidgets('the fraction keeps the whole count, and the count keeps the fraction', (
      tester,
    ) async {
      final value = await pumpPicker(tester, initial: 3.5);

      // 3 y la mitad: cambiar la fracción conserva los 3.
      await tester.tap(find.text('Tres cuartos'));
      await tester.pump();
      expect(value.value, 3.75);

      // Quitar un envase completo conserva la fracción.
      await tester.tap(find.byKey(const ValueKey('container-whole-minus')));
      await tester.pump();
      expect(value.value, 2.75);
    });

    testWidgets('the minus button stops at zero whole containers', (tester) async {
      final value = await pumpPicker(tester, initial: 0.5);

      await tester.tap(find.byKey(const ValueKey('container-whole-minus')));
      await tester.pump();
      expect(value.value, 0.5);
    });

    testWidgets('"Entera" still means one whole container, and combines with the stepper', (
      tester,
    ) async {
      final value = await pumpPicker(tester);

      await tester.tap(find.text('Entera'));
      await tester.pump();
      expect(value.value, 1.0);

      await tester.tap(find.byKey(const ValueKey('container-whole-plus')));
      await tester.pump();
      expect(value.value, 2.0);

      await tester.tap(find.text('La mitad'));
      await tester.pump();
      expect(value.value, 2.5);
    });

    testWidgets('registering "2 tiras y un cuarto" stores 2.25 and takes 2.25 from the stock', (
      tester,
    ) async {
      final unit = await unitNamed('tira');
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Tote bag negra',
          priceA: 10,
          priceB: 10,
          stock: const Value(5),
        ),
      );
      await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Base metálica pequeña para pines',
          unitId: unit.id,
          pricePerUnit: 2,
          stock: const Value(10),
        ),
      );
      _phone(tester, size: const Size(900, 1600));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: lightTheme,
            home: const Scaffold(body: MaterialsUsageTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await pickFromSearch(tester, find.byType(SearchablePickerField<int>).first, 'Tote bag negra', 'Tote bag negra');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await pickFromSearch(tester, find.byType(SearchablePickerField<int>).last, 'Base metálica pequeña para pines', 'Base metálica pequeña para pines');

      await tester.tap(find.byKey(const ValueKey('container-whole-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('container-whole-plus')));
      await tester.pump();
      await tester.tap(find.text('Un cuarto'));
      await tester.pump();
      expect(find.text('Total: 2.25 tiras'), findsOneWidget);
      await tester.tap(find.text('Registrar').last);
      await tester.pumpAndSettle();

      final record = await db.select(db.productMaterials).getSingle();
      expect(record.quantityUsed, 2.25);
      expect((await db.select(db.materials).getSingle()).stock, 7.75);
    });
  });

  group('material unit: only same-type changes when editing', () {
    List<UnitModel> all = [];

    setUp(() async {
      final rows = await (db.select(db.units)).get();
      all = [for (final r in rows) UnitModel(id: r.id, name: r.name, type: r.type)];
    });

    UnitModel unit(String name) => all.firstWhere((u) => u.name == name);

    test('selectableUnitsFor: creating offers every unit', () {
      expect(selectableUnitsFor(all).length, all.length);
    });

    test('selectableUnitsFor: a contenedor unit can only become another contenedor', () {
      final names = selectableUnitsFor(all, current: unit('tira')).map((u) => u.name);
      expect(names, containsAll(['contenedor', 'paquete', 'rollo', 'tira']));
      expect(names, isNot(contains('litro')));
      expect(names, isNot(contains('metro')));
      expect(names, isNot(contains('otro')));
    });

    test('selectableUnitsFor: a medida unit stays within medidas', () {
      final names = selectableUnitsFor(all, current: unit('litro')).map((u) => u.name);
      expect(names, containsAll(['unidad', 'metro', 'kg', 'litro']));
      expect(names, isNot(contains('tira')));
      expect(names, isNot(contains('otro')));
    });

    test('isUnitChangeAllowed compares types', () {
      expect(isUnitChangeAllowed(unit('tira'), unit('rollo')), isTrue);
      expect(isUnitChangeAllowed(unit('tira'), unit('litro')), isFalse);
      expect(isUnitChangeAllowed(unit('metro'), unit('kg')), isTrue);
      expect(isUnitChangeAllowed(unit('otro'), unit('metro')), isFalse);
    });

    Future<int> seedMaterial(String unitName) async => db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Base metálica pequeña para pines',
        unitId: (await unitNamed(unitName)).id,
        pricePerUnit: 2,
        stock: const Value(0),
      ),
    );

    test('the repository rejects editing a tira into a litro and leaves the unit alone', () async {
      final id = await seedMaterial('tira');
      final litro = await unitNamed('litro');

      await expectLater(
        MaterialRepository(db).save(
          id: id,
          name: 'Base metálica pequeña para pines',
          unitId: litro.id,
          stock: 0,
          pricePerUnit: 2,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            unitTypeChangeMessage,
          ),
        ),
      );

      final row = await db.select(db.materials).getSingle();
      expect(row.unitId, (await unitNamed('tira')).id);
    });

    test('the repository allows editing a tira into a rollo (same type)', () async {
      final id = await seedMaterial('tira');
      final rollo = await unitNamed('rollo');

      await MaterialRepository(db).save(
        id: id,
        name: 'Base metálica pequeña para pines',
        unitId: rollo.id,
        stock: 0,
        pricePerUnit: 2,
      );

      expect((await db.select(db.materials).getSingle()).unitId, rollo.id);
    });

    test('a medida can change to another medida, but not to a contenedor or otro', () async {
      final id = await seedMaterial('metro');
      final repo = MaterialRepository(db);

      await repo.save(
        id: id,
        name: 'Base metálica pequeña para pines',
        unitId: (await unitNamed('kg')).id,
        stock: 0,
        pricePerUnit: 2,
      );
      expect((await db.select(db.materials).getSingle()).unitId, (await unitNamed('kg')).id);

      for (final other in ['paquete', 'otro']) {
        await expectLater(
          repo.save(
            id: id,
            name: 'Base metálica pequeña para pines',
            unitId: (await unitNamed(other)).id,
            stock: 0,
            pricePerUnit: 2,
          ),
          throwsArgumentError,
          reason: other,
        );
      }
    });

    test('editing other fields keeping the same unit is unaffected', () async {
      final id = await seedMaterial('tira');
      await MaterialRepository(db).save(
        id: id,
        name: 'Tela para estuches',
        unitId: (await unitNamed('tira')).id,
        stock: 3,
        pricePerUnit: 5,
      );
      final row = await db.select(db.materials).getSingle();
      expect(row.name, 'Tela para estuches');
      expect(row.stock, 3.0);
    });

    test('creating a material may use any unit', () async {
      await MaterialRepository(db).save(
        name: 'Resina parte B',
        unitId: (await unitNamed('litro')).id,
        stock: 0,
        pricePerUnit: 3,
      );
      expect(await db.select(db.materials).get(), hasLength(1));
    });

    testWidgets('the edit form offers only same-type units; the create form offers all', (
      tester,
    ) async {
      final id = await seedMaterial('tira');
      final row = await (db.select(db.materials)..where((m) => m.id.equals(id))).getSingle();
      final model = MaterialModel(
        id: row.id,
        name: row.name,
        unitId: row.unitId,
        stock: row.stock,
        pricePerUnit: row.pricePerUnit,
        isActive: row.isActive,
        createdAt: row.createdAt,
      );

      await _openSheet(
        tester,
        db,
        MaterialDialog(material: model),
        size: const Size(900, 1600),
      );
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      for (final name in ['contenedor', 'paquete', 'rollo']) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      expect(find.text('litro'), findsNothing);
      expect(find.text('metro'), findsNothing);
      expect(find.text('otro'), findsNothing);
    });

    testWidgets('creating a material shows every unit in the selector', (tester) async {
      await _openSheet(tester, db, const MaterialDialog());
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      for (final name in ['contenedor', 'tira', 'metro', 'litro', 'otro']) {
        expect(find.text(name), findsWidgets, reason: name);
      }
    });
  });
}
