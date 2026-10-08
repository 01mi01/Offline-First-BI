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
import 'package:offline_first_bi/presentation/widgets/linked_price_fields.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/presentation/widgets/unit_quantity_input.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'search_helpers.dart';

// Precio de los materiales, para TODOS los tipos de unidad (contenedor, medida
// y otros): "Precio por unidad" y "Total pagado" siempre visibles y
// enlazados; el último que se escribe manda.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pricePerWholeUnit', () {
    test('divides the total paid by the quantity', () {
      expect(pricePerWholeUnit(totalPaid: 35, quantity: 0.5), 70);
      expect(pricePerWholeUnit(totalPaid: 100, quantity: 2), 50);
      expect(pricePerWholeUnit(totalPaid: 30, quantity: 2.25), closeTo(13.3333, 1e-4));
    });

    test('no price when the quantity or the total are not positive', () {
      expect(pricePerWholeUnit(totalPaid: 35, quantity: 0), isNull);
      expect(pricePerWholeUnit(totalPaid: 0, quantity: 1), isNull);
      expect(pricePerWholeUnit(totalPaid: -5, quantity: 1), isNull);
    });
  });

  group('LinkedPriceController (live link)', () {
    late LinkedPriceController c;
    setUp(() => c = LinkedPriceController());
    tearDown(() {
      c.dispose();
      c.price.dispose();
    });

    test('typing the price calculates the total', () {
      c.setQuantity(0.5);
      c.price.text = '70';
      c.priceTyped();
      expect(c.total.text, '35.00');
      expect(c.resolvedPrice, 70);
    });

    test('typing the total calculates the price', () {
      c.setQuantity(0.5);
      c.total.text = '35';
      c.totalTyped();
      expect(c.price.text, '70.00');
      expect(c.resolvedPrice, 70);
    });

    test('the last one typed decides the saved price', () {
      c.setQuantity(0.5);
      c.price.text = '70';
      c.priceTyped();
      c.total.text = '40';
      c.totalTyped();
      expect(c.price.text, '80.00');
      expect(c.resolvedPrice, 80);
      c.price.text = '60';
      c.priceTyped();
      expect(c.total.text, '30.00');
      expect(c.resolvedPrice, 60);
    });

    test('a quantity change recalculates the field that was not typed last', () {
      c.setQuantity(1);
      c.total.text = '100';
      c.totalTyped();
      expect(c.price.text, '100.00');
      c.setQuantity(2);
      expect(c.price.text, '50.00'); // el total manda
      expect(c.total.text, '100'); // lo escrito no se toca

      c.price.text = '30';
      c.priceTyped();
      c.setQuantity(3);
      expect(c.total.text, '90.00'); // el precio manda
      expect(c.resolvedPrice, 30);
    });

    test('what was typed is never touched; the calculated field and the saved price are cents', () {
      c.setQuantity(0.75);
      c.total.text = '10';
      c.totalTyped();
      expect(c.total.text, '10'); // lo escrito, tal cual
      expect(c.price.text, '13.33');
      expect(c.resolvedPrice, 13.33); // se guarda a centavos
    });

    test('a price typed with more than two decimals is typed text, saved rounded', () {
      c.setQuantity(3);
      c.price.text = '3.3349';
      c.priceTyped();
      expect(c.price.text, '3.3349'); // el campo escrito no cambia
      expect(c.total.text, '10.00'); // 3 x 3.3349 = 10.0047
      expect(c.resolvedPrice, 3.33);
    });

    test('nothing to calculate without a quantity', () {
      c.total.text = '35';
      c.totalTyped();
      expect(c.price.text, '');
      expect(c.resolvedPrice, isNull);
      c.price.text = '70';
      c.priceTyped();
      expect(c.total.text, '');
      expect(c.resolvedPrice, 70);
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
    Size size = const Size(412, 1600),
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

  String textOf(WidgetTester tester, String label) => tester
      .widget<TextFormField>(find.widgetWithText(TextFormField, label))
      .controller!
      .text;

  Future<Material> materialNamed(String name) =>
      (db.select(db.materials)..where((m) => m.name.equals(name))).getSingle();

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

  group('Nuevo material', () {
    testWidgets('contenedor: both fields are always visible, with no info icon', (
      tester,
    ) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Resina parte B');
      await chooseUnit(tester, 'contenedor');
      expect(find.widgetWithText(TextFormField, 'Precio por unidad'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Total pagado (Bs.)'), findsOneWidget);
      // Incluso con el stock en 0.
      await type(tester, 'Stock', '0');
      expect(find.widgetWithText(TextFormField, 'Total pagado (Bs.)'), findsOneWidget);

      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('Bs. 35 paid for 0.5 shows 70 per unit and stores it', (tester) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Resina parte B');
      await chooseUnit(tester, 'contenedor');
      await type(tester, 'Stock', '0.5');
      await type(tester, 'Total pagado (Bs.)', '35');
      expect(textOf(tester, 'Precio por unidad'), '70.00');

      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      final m = await materialNamed('Resina parte B');
      expect(m.pricePerUnit, 70);
      expect(m.stock, 0.5);
      final purchase = await db.select(db.purchases).getSingle();
      expect(purchase.totalAmount, 35);
    });

    testWidgets('typing the price per unit fills in the total', (tester) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Resina parte B');
      await chooseUnit(tester, 'contenedor');
      await type(tester, 'Stock', '0.5');
      await type(tester, 'Precio por unidad', '70');
      expect(textOf(tester, 'Total pagado (Bs.)'), '35.00');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect((await materialNamed('Resina parte B')).pricePerUnit, 70);
    });

    testWidgets('whichever was typed last decides the saved price', (tester) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Resina parte B');
      await chooseUnit(tester, 'contenedor');
      await type(tester, 'Stock', '0.5');
      await type(tester, 'Precio por unidad', '70');
      await type(tester, 'Total pagado (Bs.)', '40');
      expect(textOf(tester, 'Precio por unidad'), '80.00');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect((await materialNamed('Resina parte B')).pricePerUnit, 80);
    });

    testWidgets('changing the stock recalculates the field that was not typed last', (
      tester,
    ) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Resina parte B');
      await chooseUnit(tester, 'contenedor');
      await type(tester, 'Stock', '1');
      await type(tester, 'Total pagado (Bs.)', '100');
      expect(textOf(tester, 'Precio por unidad'), '100.00');
      await type(tester, 'Stock', '2');
      expect(textOf(tester, 'Precio por unidad'), '50.00');
      expect(textOf(tester, 'Total pagado (Bs.)'), '100');
    });

    testWidgets('a price alone works without stock; a total needs the quantity', (
      tester,
    ) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Resina parte B');
      await chooseUnit(tester, 'contenedor');
      await type(tester, 'Stock', '0');
      await type(tester, 'Total pagado (Bs.)', '35');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(find.text('Indica la cantidad para calcular el precio'), findsOneWidget);
      expect(await db.select(db.materials).get(), isEmpty);

      await type(tester, 'Precio por unidad', '70');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      final m = await materialNamed('Resina parte B');
      expect(m.pricePerUnit, 70);
      expect(m.stock, 0);
    });

    testWidgets('litro: both fields are linked too (half a litro for Bs. 12)', (
      tester,
    ) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Papel holográfico para stickers');
      await chooseUnit(tester, 'litro');
      expect(find.widgetWithText(TextFormField, 'Precio por unidad'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Total pagado (Bs.)'), findsOneWidget);

      await type(tester, 'Stock', '0.5');
      await type(tester, 'Total pagado (Bs.)', '12');
      expect(textOf(tester, 'Precio por unidad'), '24.00'); // total -> precio
      await type(tester, 'Precio por unidad', '30');
      expect(textOf(tester, 'Total pagado (Bs.)'), '15.00'); // precio -> total
      await type(tester, 'Stock', '2');
      expect(textOf(tester, 'Total pagado (Bs.)'), '60.00'); // manda el precio

      await type(tester, 'Total pagado (Bs.)', '50');
      expect(textOf(tester, 'Precio por unidad'), '25.00');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      final m = await materialNamed('Papel holográfico para stickers');
      expect(m.pricePerUnit, 25);
      expect(m.stock, 2);
      expect((await db.select(db.purchases).getSingle()).totalAmount, 50);
    });

    testWidgets('a medida price typed directly is saved as is', (tester) async {
      await openSheet(tester, const MaterialDialog());
      await type(tester, 'Nombre', 'Papel para stickers');
      await chooseUnit(tester, 'metro');
      await type(tester, 'Precio por unidad', '10');
      await type(tester, 'Stock', '3.5');
      expect(textOf(tester, 'Total pagado (Bs.)'), '35.00');
      expect(textOf(tester, 'Precio por unidad'), '10');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      final m = await materialNamed('Papel para stickers');
      expect(m.pricePerUnit, 10);
      expect(m.stock, 3.5);
    });

    testWidgets('no info icon next to "Precio por unidad" for any unit type', (
      tester,
    ) async {
      await openSheet(tester, const MaterialDialog());
      for (final unit in ['contenedor', 'litro', 'otro']) {
        await chooseUnit(tester, unit);
        expect(find.byIcon(Icons.info_outline), findsNothing, reason: unit);
      }
    });

    testWidgets('otro is linked as well', (tester) async {
      await openSheet(tester, const MaterialDialog());
      await chooseUnit(tester, 'otro');
      await type(tester, 'Stock', '4');
      await type(tester, 'Total pagado (Bs.)', '20');
      expect(textOf(tester, 'Precio por unidad'), '5.00');
    });
  });

  group('Editar material', () {
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
        size: const Size(900, 2000),
      );
    }

    testWidgets('contenedor shows price, total and quantity starting at the current price', (
      tester,
    ) async {
      await openEdit(tester, await seed('Resina parte B', 'contenedor', 70));
      expect(textOf(tester, 'Precio por unidad'), '70.00');
      expect(textOf(tester, 'Total pagado (Bs.)'), '70.00');
      expect(textOf(tester, 'Cantidad (contenedor)'), '1');
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('Bs. 35 for 0.5 corrects the price to 70; stock is untouched', (
      tester,
    ) async {
      await openEdit(tester, await seed('Resina parte B', 'contenedor', 100, stock: 3));
      await type(tester, 'Cantidad (contenedor)', '0.5');
      await type(tester, 'Total pagado (Bs.)', '35');
      expect(textOf(tester, 'Precio por unidad'), '70.00');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final m = await materialNamed('Resina parte B');
      expect(m.pricePerUnit, 70);
      expect(m.stock, 3);
    });

    testWidgets('typing the price recalculates the total for the quantity', (
      tester,
    ) async {
      await openEdit(tester, await seed('Resina parte B', 'contenedor', 70));
      await type(tester, 'Cantidad (contenedor)', '2');
      expect(textOf(tester, 'Total pagado (Bs.)'), '140.00'); // el precio manda
      await type(tester, 'Precio por unidad', '90');
      expect(textOf(tester, 'Total pagado (Bs.)'), '180.00');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect((await materialNamed('Resina parte B')).pricePerUnit, 90);
    });

    testWidgets('saving without touching the price keeps it exactly', (tester) async {
      await openEdit(tester, await seed('Resina parte B', 'contenedor', 13.333333333));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      // Se guarda a centavos (dos decimales).
      expect((await materialNamed('Resina parte B')).pricePerUnit, 13.33);
    });

    testWidgets('a zero quantity is rejected when the total is what was typed', (
      tester,
    ) async {
      await openEdit(tester, await seed('Resina parte B', 'contenedor', 70));
      await type(tester, 'Total pagado (Bs.)', '35');
      await type(tester, 'Cantidad (contenedor)', '0');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa la cantidad'), findsOneWidget);
      expect((await materialNamed('Resina parte B')).pricePerUnit, 70);
    });

    testWidgets('litro: price, total and quantity too, linked both ways', (
      tester,
    ) async {
      await openEdit(tester, await seed('Papel holográfico para stickers', 'litro', 10, stock: 3));
      expect(textOf(tester, 'Precio por unidad'), '10.00');
      expect(textOf(tester, 'Total pagado (Bs.)'), '10.00');
      expect(textOf(tester, 'Cantidad (litro)'), '1');
      expect(find.byIcon(Icons.info_outline), findsNothing);

      await type(tester, 'Cantidad (litro)', '0.5');
      expect(textOf(tester, 'Total pagado (Bs.)'), '5.00'); // manda el precio
      await type(tester, 'Total pagado (Bs.)', '12');
      expect(textOf(tester, 'Precio por unidad'), '24.00');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final m = await materialNamed('Papel holográfico para stickers');
      expect(m.pricePerUnit, 24);
      expect(m.stock, 3);
    });

    testWidgets('a medida price edited directly is saved as is', (tester) async {
      await openEdit(tester, await seed('Papel para stickers', 'metro', 10, stock: 3));
      await type(tester, 'Stock', '8');
      expect(textOf(tester, 'Precio por unidad'), '10.00'); // el stock no lo toca
      await type(tester, 'Precio por unidad', '12');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final m = await materialNamed('Papel para stickers');
      expect(m.pricePerUnit, 12);
      expect(m.stock, 8);
    });
  });

  group('Compra: agregar material', () {
    setUp(() async {
      await seed('Resina parte B', 'contenedor', 80, stock: 1);
      await seed('Papel para stickers', 'metro', 4, stock: 10);
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

    testWidgets('contenedor shows price and total together, starting at the current price', (
      tester,
    ) async {
      await openLine(tester, 'Resina parte B');
      expect(textOf(tester, 'Precio por unidad (Bs.)'), '80.00');
      expect(find.widgetWithText(TextFormField, 'Total pagado (Bs.)'), findsOneWidget);
      expect(textOf(tester, 'Total pagado (Bs.)'), ''); // aún sin cantidad
      await tester.tap(find.text('La mitad'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'Total pagado (Bs.)'), '40.00');
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('half a container for Bs. 35 gives 70 per unit and stores it', (
      tester,
    ) async {
      await openLine(tester, 'Resina parte B');
      await tester.tap(find.text('La mitad'));
      await tester.pumpAndSettle();
      await type(tester, 'Total pagado (Bs.)', '35');
      expect(textOf(tester, 'Precio por unidad (Bs.)'), '70.00');

      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
      expect(find.text('Bs. 35.00'), findsOneWidget);

      await tester.ensureVisible(find.text('Registrar compra'));
      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();
      final item = await db.select(db.purchaseItems).getSingle();
      expect(item.quantity, 0.5);
      expect(item.unitPrice, 70);
      expect(item.subtotal, 35);
      final m = await materialNamed('Resina parte B');
      expect(m.pricePerUnit, 70);
      expect(m.stock, 1.5);
    });

    testWidgets('typing the price per unit fills in the total; the last one typed wins', (
      tester,
    ) async {
      await openLine(tester, 'Resina parte B');
      await tester.tap(find.text('Entera'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'Total pagado (Bs.)'), '80.00');
      await type(tester, 'Precio por unidad (Bs.)', '90');
      expect(textOf(tester, 'Total pagado (Bs.)'), '90.00');

      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
      expect(find.text('Bs. 90.00'), findsOneWidget);
    });

    testWidgets('changing the quantity keeps the typed total and recalculates the price', (
      tester,
    ) async {
      await openLine(tester, 'Resina parte B');
      await tester.tap(find.text('La mitad'));
      await tester.pumpAndSettle();
      await type(tester, 'Total pagado (Bs.)', '35');
      expect(textOf(tester, 'Precio por unidad (Bs.)'), '70.00');
      await tester.tap(find.text('Entera'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'Total pagado (Bs.)'), '35');
      expect(textOf(tester, 'Precio por unidad (Bs.)'), '35.00');
    });

    testWidgets('a quantity is required before adding a container line', (
      tester,
    ) async {
      await openLine(tester, 'Resina parte B');
      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
      expect(find.text('Selecciona una cantidad'), findsOneWidget);
      expect(find.text('Agregar material'), findsOneWidget);
    });

    testWidgets('litro/metro: price and total are linked in the purchase line too', (
      tester,
    ) async {
      await openLine(tester, 'Papel para stickers');
      expect(textOf(tester, 'Precio por unidad (Bs.)'), '4.00');
      expect(textOf(tester, 'Total pagado (Bs.)'), '');
      expect(find.byType(FractionQuantityPicker), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);

      await type(tester, 'Cantidad (metro)', '3');
      expect(textOf(tester, 'Total pagado (Bs.)'), '12.00'); // manda el precio
      expect(textOf(tester, 'Precio por unidad (Bs.)'), '4.00');
      await type(tester, 'Total pagado (Bs.)', '15');
      expect(textOf(tester, 'Precio por unidad (Bs.)'), '5.00'); // total -> precio
      await type(tester, 'Cantidad (metro)', '1.5');
      expect(textOf(tester, 'Precio por unidad (Bs.)'), '10.00'); // manda el total

      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
      expect(find.text('Bs. 15.00'), findsOneWidget);
      await tester.ensureVisible(find.text('Registrar compra'));
      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();
      final item = await db.select(db.purchaseItems).getSingle();
      expect(item.quantity, 1.5);
      expect(item.unitPrice, 10);
      expect(item.subtotal, 15);
      expect((await materialNamed('Papel para stickers')).pricePerUnit, 10);
    });

    testWidgets('a price typed directly in the line is used as is', (tester) async {
      await openLine(tester, 'Papel para stickers');
      await type(tester, 'Cantidad (metro)', '3');
      await type(tester, 'Precio por unidad (Bs.)', '5');
      expect(textOf(tester, 'Total pagado (Bs.)'), '15.00');
      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
      expect(find.text('Bs. 15.00'), findsOneWidget);
    });

    testWidgets('switching material resets the quantity and the price', (tester) async {
      await openLine(tester, 'Papel para stickers');
      await type(tester, 'Cantidad (metro)', '3');
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        'Resina parte B',
        'Resina parte B',
      );
      expect(textOf(tester, 'Precio por unidad (Bs.)'), '80.00');
      expect(textOf(tester, 'Total pagado (Bs.)'), '');
    });

  });
}
