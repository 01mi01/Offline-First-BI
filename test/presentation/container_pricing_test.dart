import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/material_pricing.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/material_model.dart';
import 'package:offline_first_bi/presentation/dialogs/material_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/presentation/widgets/unit_quantity_input.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'search_helpers.dart';

// Materiales tipo contenedor: lo que se escribe es el TOTAL pagado por la
// cantidad registrada (35 por media botella) y el precio por unidad entera se
// calcula (70). Metro, litro, etc. siguen pidiendo el precio por unidad.
void main() {
  group('pricePerWholeUnit', () {
    test('divides the total paid by the quantity', () {
      expect(pricePerWholeUnit(totalPaid: 35, quantity: 0.5), 70);
      expect(pricePerWholeUnit(totalPaid: 100, quantity: 2), 50);
      expect(pricePerWholeUnit(totalPaid: 10, quantity: 0.25), 40);
      expect(pricePerWholeUnit(totalPaid: 30, quantity: 2.25), closeTo(13.3333, 1e-4));
    });

    test('no price when the quantity or the total are not positive', () {
      expect(pricePerWholeUnit(totalPaid: 35, quantity: 0), isNull);
      expect(pricePerWholeUnit(totalPaid: 0, quantity: 1), isNull);
      expect(pricePerWholeUnit(totalPaid: -5, quantity: 1), isNull);
      expect(pricePerWholeUnit(totalPaid: 5, quantity: -1), isNull);
    });

    test('the unit price times the quantity gives the total back', () {
      final unit = pricePerWholeUnit(totalPaid: 35, quantity: 0.5)!;
      expect(totalForQuantity(pricePerUnit: unit, quantity: 0.5), 35);
    });
  });

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openSheet(
    WidgetTester tester,
    Widget sheet, {
    Size size = const Size(412, 1400),
  }) async {
    tester.view.physicalSize = size;
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
  }

  Future<void> chooseUnit(WidgetTester tester, String name) async {
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
    await tester.pumpAndSettle();
  }

  Future<Material> materialNamed(String name) =>
      (db.select(db.materials)..where((m) => m.name.equals(name))).getSingle();

  group('Nuevo material', () {
    testWidgets('contenedor: Bs. 35 for 0.5 stores 70 per whole unit', (
      tester,
    ) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Perfume');
      await chooseUnit(tester, 'contenedor');
      await type(tester, 'Stock', '0.5');
      // Con stock, el campo es lo que se pagó.
      expect(find.text('Total pagado por el stock (Bs.)'), findsOneWidget);
      expect(find.text('Precio por unidad'), findsNothing);
      await type(tester, 'Total pagado por el stock (Bs.)', '35');
      expect(find.text('Precio de 1 contenedor: Bs. 70.00'), findsOneWidget);

      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      final m = await materialNamed('Perfume');
      expect(m.pricePerUnit, 70);
      expect(m.stock, 0.5);
      // La compra del stock inicial refleja lo realmente pagado.
      final purchase = await db.select(db.purchases).getSingle();
      expect(purchase.totalAmount, 35);
      final item = await db.select(db.purchaseItems).getSingle();
      expect(item.quantity, 0.5);
      expect(item.unitPrice, 70);
      expect(item.subtotal, 35);
    });

    testWidgets('contenedor with whole stock: 100 paid for 2 stores 50', (
      tester,
    ) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Frascos');
      await chooseUnit(tester, 'contenedor');
      await type(tester, 'Stock', '2');
      await type(tester, 'Total pagado por el stock (Bs.)', '100');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect((await materialNamed('Frascos')).pricePerUnit, 50);
    });

    testWidgets('contenedor without stock still asks for the price of one', (
      tester,
    ) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Perfume');
      await chooseUnit(tester, 'contenedor');
      expect(find.text('Precio por unidad'), findsOneWidget);
      await type(tester, 'Stock', '0');
      expect(find.text('Precio por unidad'), findsOneWidget);
      await type(tester, 'Precio por unidad', '70');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      final m = await materialNamed('Perfume');
      expect(m.pricePerUnit, 70);
      expect(m.stock, 0);
    });

    testWidgets('a zero total is rejected for a container with stock', (
      tester,
    ) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Perfume');
      await chooseUnit(tester, 'contenedor');
      await type(tester, 'Stock', '0.5');
      await type(tester, 'Total pagado por el stock (Bs.)', '0');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa lo que pagaste'), findsOneWidget);
      expect(await db.select(db.materials).get(), isEmpty);
    });

    testWidgets('metro keeps the price per unit untouched', (tester) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Cinta');
      await chooseUnit(tester, 'metro');
      await type(tester, 'Stock', '3.5');
      expect(find.text('Precio por unidad'), findsOneWidget);
      expect(find.text('Total pagado por el stock (Bs.)'), findsNothing);
      await type(tester, 'Precio por unidad', '10');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      final m = await materialNamed('Cinta');
      expect(m.pricePerUnit, 10);
      expect((await db.select(db.purchases).getSingle()).totalAmount, 35);
    });
  });

  group('Editar material', () {
    Future<int> seed(String name, String unit, double price, {double stock = 0.5}) async {
      final u = await (db.select(db.units)..where((x) => x.name.equals(unit))).getSingle();
      return db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: name,
          unitId: u.id,
          pricePerUnit: price,
          stock: Value(stock),
        ),
      );
    }

    Future<void> openEdit(WidgetTester tester, int id) async {
      final row = await (db.select(db.materials)..where((m) => m.id.equals(id))).getSingle();
      await openSheet(
        tester,
        MaterialDialog(
          material: MaterialModel(
            id: row.id,
            name: row.name,
            unitId: row.unitId,
            stock: row.stock,
            pricePerUnit: row.pricePerUnit,
            isActive: row.isActive,
            createdAt: row.createdAt,
          ),
        ),
        // La tipografía de prueba es más ancha: pantalla grande para la fila
        // "Material activo".
        size: const Size(900, 1800),
      );
    }

    String textOf(WidgetTester tester, String label) => tester
        .widget<TextFormField>(find.widgetWithText(TextFormField, label))
        .controller!
        .text;

    testWidgets('a container offers total paid + quantity, starting at the current price', (
      tester,
    ) async {
      final id = await seed('Perfume', 'contenedor', 70);
      await openEdit(tester, id);
      expect(find.text('Total pagado (Bs.)'), findsOneWidget);
      expect(find.text('Cantidad (contenedor)'), findsOneWidget);
      expect(find.text('Precio por unidad'), findsNothing);
      expect(textOf(tester, 'Total pagado (Bs.)'), '70');
      expect(textOf(tester, 'Cantidad (contenedor)'), '1');
      expect(find.text('Precio de 1 contenedor: Bs. 70.00'), findsOneWidget);
    });

    testWidgets('Bs. 35 for 0.5 corrects the price to 70 per unit; stock is untouched', (
      tester,
    ) async {
      final id = await seed('Perfume', 'contenedor', 100, stock: 3);
      await openEdit(tester, id);
      await type(tester, 'Total pagado (Bs.)', '35');
      await type(tester, 'Cantidad (contenedor)', '0.5');
      expect(find.text('Precio de 1 contenedor: Bs. 70.00'), findsOneWidget);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final m = await materialNamed('Perfume');
      expect(m.pricePerUnit, 70);
      expect(m.stock, 3);
    });

    testWidgets('saving without touching the price keeps it exactly', (tester) async {
      final id = await seed('Perfume', 'contenedor', 13.333333333);
      await openEdit(tester, id);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect((await materialNamed('Perfume')).pricePerUnit, 13.333333333);
    });

    testWidgets('a zero quantity is rejected', (tester) async {
      final id = await seed('Perfume', 'contenedor', 70);
      await openEdit(tester, id);
      await type(tester, 'Total pagado (Bs.)', '35');
      await type(tester, 'Cantidad (contenedor)', '0');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa la cantidad'), findsOneWidget);
      expect((await materialNamed('Perfume')).pricePerUnit, 70);
    });

    testWidgets('metro keeps the plain price per unit when editing', (tester) async {
      final id = await seed('Cinta', 'metro', 10, stock: 3);
      await openEdit(tester, id);
      expect(find.text('Precio por unidad'), findsOneWidget);
      expect(find.text('Total pagado (Bs.)'), findsNothing);
      expect(find.text('Cantidad (metro)'), findsNothing);
      await type(tester, 'Precio por unidad', '12');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect((await materialNamed('Cinta')).pricePerUnit, 12);
    });

    group('info icon', () {
      Future<void> openInfo(WidgetTester tester) async {
        await tester.tap(find.byIcon(Icons.info_outline));
        await tester.pumpAndSettle();
      }

      testWidgets('contenedor while editing explains total paid', (tester) async {
        await openEdit(tester, await seed('Perfume', 'contenedor', 70));
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        await openInfo(tester);
        expect(find.text(totalPaidInfoMessage), findsOneWidget);
        expect(
          find.text(
            'Ingresa el total que pagaste por la cantidad indicada, y la '
            'aplicación calculará el precio por unidad completa.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
        expect(find.text(totalPaidInfoMessage), findsNothing);
      });

      testWidgets('contenedor while creating (with stock) explains total paid', (
        tester,
      ) async {
        await openSheet(tester, const MaterialDialog());
        await chooseUnit(tester, 'contenedor');
        // Sin stock el campo es el precio por unidad: aún sin explicación.
        expect(find.byIcon(Icons.info_outline), findsNothing);
        await type(tester, 'Stock', '0.5');
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        await openInfo(tester);
        expect(find.text(totalPaidInfoMessage), findsOneWidget);
      });

      testWidgets('medida explains the price is for one whole unit, creating and editing', (
        tester,
      ) async {
        await openSheet(tester, const MaterialDialog());
        await chooseUnit(tester, 'metro');
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        await openInfo(tester);
        expect(
          find.text(
            'Este precio corresponde a una unidad completa de medida, por '
            'ejemplo un metro o un litro.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('editing a medida material shows the same explanation', (tester) async {
        await openEdit(tester, await seed('Cinta', 'metro', 10, stock: 3));
        await openInfo(tester);
        expect(find.text(unitPriceInfoMessage), findsOneWidget);
      });

      testWidgets('otros has no explanation icon', (tester) async {
        await openSheet(tester, const MaterialDialog());
        await chooseUnit(tester, 'otro');
        expect(find.byIcon(Icons.info_outline), findsNothing);
      });
    });
  });

  group('Compra: agregar material', () {
    late int perfumeId;

    setUp(() async {
      final container = await (db.select(db.units)..where((u) => u.name.equals('contenedor'))).getSingle();
      final metro = await (db.select(db.units)..where((u) => u.name.equals('metro'))).getSingle();
      perfumeId = await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Perfume',
          unitId: container.id,
          pricePerUnit: 80,
          stock: const Value(1),
        ),
      );
      await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Cinta',
          unitId: metro.id,
          pricePerUnit: 4,
          stock: const Value(10),
        ),
      );
    });

    Future<void> openLine(WidgetTester tester, String material) async {
      await openSheet(tester, const PurchaseDialog());
      await tester.ensureVisible(find.text('Agregar'));
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        material,
        material,
      );
    }

    testWidgets('half a container for Bs. 35 stores 70 per whole unit', (
      tester,
    ) async {
      await openLine(tester, 'Perfume');
      expect(find.text('Total pagado (Bs.)'), findsOneWidget);
      expect(find.text('Precio por unidad (Bs.)'), findsNothing);

      await tester.tap(find.text('La mitad'));
      await tester.pumpAndSettle();
      // Se sugiere el total al precio actual (80 x 0.5 = 40)...
      expect(
        tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Total pagado (Bs.)')).controller!.text,
        '40',
      );
      // ...y se cambia por lo realmente pagado.
      await type(tester, 'Total pagado (Bs.)', '35');
      expect(find.text('Precio de 1 contenedor: Bs. 70.00'), findsOneWidget);

      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
      // La línea muestra lo pagado, no 0.5 x el precio anterior.
      expect(find.text('Bs. 35.00'), findsOneWidget);

      await tester.ensureVisible(find.text('Registrar compra'));
      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();

      final purchase = await db.select(db.purchases).getSingle();
      expect(purchase.totalAmount, 35);
      final item = await db.select(db.purchaseItems).getSingle();
      expect(item.quantity, 0.5);
      expect(item.unitPrice, 70);
      final m = await (db.select(db.materials)..where((x) => x.id.equals(perfumeId))).getSingle();
      expect(m.pricePerUnit, 70);
      expect(m.stock, 1.5);
    });

    testWidgets('whole containers plus a fraction: 2 and a quarter for Bs. 180', (
      tester,
    ) async {
      await openLine(tester, 'Perfume');
      await tester.tap(find.text('Un cuarto'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('container-whole-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('container-whole-plus')));
      await tester.pumpAndSettle();
      expect(find.text('Total: 2.25 contenedores'), findsOneWidget);
      await type(tester, 'Total pagado (Bs.)', '180');
      expect(find.text('Precio de 1 contenedor: Bs. 80.00'), findsOneWidget);
    });

    testWidgets('a quantity is required before adding a container line', (
      tester,
    ) async {
      await openLine(tester, 'Perfume');
      await type(tester, 'Total pagado (Bs.)', '35');
      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
      expect(find.text('Selecciona una cantidad'), findsOneWidget);
      expect(find.text('Agregar material'), findsOneWidget);
    });

    testWidgets('metro keeps quantity + price per unit', (tester) async {
      await openLine(tester, 'Cinta');
      expect(find.text('Precio por unidad (Bs.)'), findsOneWidget);
      expect(find.text('Total pagado (Bs.)'), findsNothing);
      expect(find.byType(FractionQuantityPicker), findsNothing);
      expect(
        tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Precio por unidad (Bs.)')).controller!.text,
        '4',
      );
    });
  });
}
