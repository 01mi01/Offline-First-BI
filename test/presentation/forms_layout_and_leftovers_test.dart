import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/widgets/app_controls.dart';
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

  void setScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openSheet(WidgetTester tester, Widget sheet, Size size) async {
    setScreen(tester, size);
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

  group('Compras: cambiar entre "Materiales" y "Gasto general"', () {
    final selector = find.byType(AppSegmented<bool>);
    Finder option(String label) =>
        find.descendant(of: selector, matching: find.text(label));
    final description = fieldLabeled('Descripción del gasto');

    testWidgets('no muestra errores de validación antes de tocar nada', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog(), const Size(412, 915));

      for (final label in ['Gasto general', 'Materiales', 'Gasto general']) {
        await tester.tap(option(label));
        await tester.pumpAndSettle();
        expect(find.text('Campo requerido'), findsNothing, reason: label);
      }
    });

    testWidgets('tampoco los muestra al volver desde un modo con datos escritos', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog(), const Size(412, 915));

      await tester.tap(option('Gasto general'));
      await tester.pumpAndSettle();
      await tester.enterText(description, 'Pasaje de bus');
      await tester.enterText(
        fieldLabeled('Total (Bs.)'),
        '30',
      );
      await tester.pump();

      await tester.tap(option('Materiales'));
      await tester.pumpAndSettle();
      expect(find.text('Campo requerido'), findsNothing);

      await tester.tap(option('Gasto general'));
      await tester.pumpAndSettle();
      expect(find.text('Campo requerido'), findsNothing);
    });

    testWidgets('los errores sí aparecen tras un intento fallido de registrar', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog(), const Size(412, 915));

      await tester.tap(option('Gasto general'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();

      expect(find.text('Campo requerido'), findsNWidgets(2));
    });

    testWidgets('los errores aparecen tras interactuar con un campo y dejarlo vacío', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog(), const Size(412, 915));

      await tester.tap(option('Gasto general'));
      await tester.pumpAndSettle();
      await tester.enterText(description, 'a');
      await tester.pump();
      await tester.enterText(description, '');
      await tester.pump();

      expect(find.text('Campo requerido'), findsOneWidget);
    });

    testWidgets('limpia la descripción y el total del otro modo', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog(), const Size(412, 915));

      await tester.tap(option('Gasto general'));
      await tester.pumpAndSettle();
      await tester.enterText(description, 'Pasaje de bus');
      await tester.enterText(
        fieldLabeled('Total (Bs.)'),
        '30',
      );
      await tester.pump();

      await tester.tap(option('Materiales'));
      await tester.pumpAndSettle();
      await tester.tap(option('Gasto general'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextFormField>(description).controller!.text, '');
      final total = fieldLabeled('Total (Bs.)');
      expect(tester.widget<TextFormField>(total).controller!.text, '');
    });
  });

  test('MaterialRepository.getMaterialsWithPriceForProduct incluye la unidad', () async {
    final unit = await (db.select(
      db.units,
    )..where((u) => u.name.equals('metro'))).getSingle();
    final productId = await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Libro',
        priceA: 20,
        priceB: 18,
      ),
    );
    final materialId = await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Tela beige',
        unitId: unit.id,
        pricePerUnit: 12.5,
      ),
    );
    await db.into(db.productMaterials).insert(
      ProductMaterialsCompanion.insert(
        productId: productId,
        materialId: materialId,
        quantityUsed: 2,
      ),
    );

    final rows = await MaterialRepository(db).getMaterialsWithPriceForProduct(productId);
    expect(rows, hasLength(1));
    expect(rows.single['name'], 'Tela beige');
    expect(rows.single['price'], 12.5);
    expect(rows.single['unit'], 'metro');
  });
}
