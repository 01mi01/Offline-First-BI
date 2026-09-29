import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/pages/materials_page.dart';
import 'package:offline_first_bi/presentation/widgets/unit_quantity_input.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// "Registro de uso" de materiales por producto: el campo de cantidad depende
// del tipo de unidad (botella -> fracciones; unidad -> solo enteros; metro ->
// decimales), y los textos de stock/precio muestran el nombre de la unidad.
Future<void> _openUsageTab(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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

  // Elige el producto y abre la hoja "Registrar el uso de un material".
  await tester.tap(find.text('Selecciona un producto'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Acuarela').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
}

Future<void> _pickMaterial(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Acuarela',
        priceA: 55,
        priceB: 40,
        stock: const Value(10),
      ),
    );
    Future<void> material(String name, String unit, double stock) async {
      final u = await (db.select(
        db.units,
      )..where((x) => x.name.equals(unit))).getSingle();
      await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: name,
          unitId: u.id,
          pricePerUnit: 2.0,
          stock: Value(stock),
        ),
      );
    }

    await material('Botones', 'unidad', 30);
    await material('Cinta', 'metro', 10);
    await material('Pintura', 'botella', 5);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('unidad: "." is rejected with feedback, never turned into "25"', (
    tester,
  ) async {
    await _openUsageTab(tester, db);
    await _pickMaterial(tester, 'Botones');

    expect(find.text('Cantidad utilizada (unidad)'), findsOneWidget);
    // El stock disponible muestra el nombre de la unidad.
    expect(find.text('Stock disponible: 30 unidades'), findsOneWidget);

    final quantity = find.byType(WholeNumberQuantityField);
    final field = find.descendant(
      of: quantity,
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field, '2');
    await tester.pump();
    await tester.enterText(field, '2.');
    await tester.pump();

    expect(tester.widget<TextFormField>(field).controller!.text, '2');
    expect(find.text(wholeNumberOnlyMessage), findsOneWidget);
  });

  testWidgets('metro: a plain field that accepts decimals', (tester) async {
    await _openUsageTab(tester, db);
    await _pickMaterial(tester, 'Cinta');

    expect(find.byType(WholeNumberQuantityField), findsNothing);
    expect(find.byType(FractionQuantityPicker), findsNothing);

    final field = find.widgetWithText(TextFormField, '0');
    await tester.enterText(field, '1.5');
    await tester.pump();

    expect(tester.widget<TextFormField>(field).controller!.text, '1.5');
    expect(find.text('Stock disponible: 10 metros'), findsOneWidget);
  });

  testWidgets('botella: fraction picker, no free-text decimal field', (
    tester,
  ) async {
    await _openUsageTab(tester, db);
    await _pickMaterial(tester, 'Pintura');

    expect(find.byType(FractionQuantityPicker), findsOneWidget);
    expect(find.byType(WholeNumberQuantityField), findsNothing);
    expect(find.text('Stock disponible: 5 botellas'), findsOneWidget);
  });

  testWidgets(
    'unidad usage registered, and the edit sheet rejects decimals too',
    (tester) async {
      await _openUsageTab(tester, db);
      await _pickMaterial(tester, 'Botones');

      final field = find.descendant(
        of: find.byType(WholeNumberQuantityField),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(field, '3');
      await tester.pump();
      await tester.tap(find.text('Registrar').last);
      await tester.pumpAndSettle();

      // Se registró el uso y descontó el stock: 30 - 3.
      final material = await (db.select(
        db.materials,
      )..where((m) => m.name.equals('Botones'))).getSingle();
      expect(material.stock, 27);

      // El renglón del registro muestra la unidad junto a la cantidad y al
      // precio.
      expect(find.textContaining('3 unidades'), findsOneWidget);
      expect(find.textContaining('/ unidad'), findsOneWidget);

      // Edita el registro: mismo rechazo de decimales.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      final editField = find.descendant(
        of: find.byType(WholeNumberQuantityField),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(editField, '4');
      await tester.pump();
      await tester.enterText(editField, '4.');
      await tester.pump();

      expect(tester.widget<TextFormField>(editField).controller!.text, '4');
      expect(find.text(wholeNumberOnlyMessage), findsOneWidget);
      expect(find.textContaining('Máximo disponible: 30 unidades'), findsOneWidget);
    },
  );

  testWidgets('material list cards show the unit next to stock and price', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: lightTheme,
          home: const Scaffold(body: MaterialsListTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stock: 5 botellas'), findsOneWidget);
    expect(find.text('Stock: 30 unidades'), findsOneWidget);
    expect(find.text('Stock: 10 metros'), findsOneWidget);
    expect(find.text('Bs. 2.00 / botella'), findsOneWidget);
    expect(find.text('Bs. 2.00 / metro'), findsOneWidget);
    // Ya no se muestra el genérico "/u".
    expect(find.textContaining('/u'), findsNothing);
  });
}
