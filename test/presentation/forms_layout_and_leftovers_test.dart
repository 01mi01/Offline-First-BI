import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/product_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/products_page.dart';
import 'package:offline_first_bi/presentation/pages/reports_page.dart';
import 'package:offline_first_bi/presentation/widgets/confirm_cancel_dialog.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'search_helpers.dart';

// Correcciones tras la revisión en el dispositivo: el formulario de Compras al
// cambiar de modo, botones siempre alcanzables en Compras/Ventas, título fijo
// en Producto y pequeños defectos visuales.
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

  // Un teléfono chico: el caso en que el formulario no cabe.
  const phone = Size(412, 640);

  bool fullyOnScreen(WidgetTester tester, Finder finder, Size screen) {
    final rect = tester.getRect(finder);
    return rect.top >= 0 &&
        rect.bottom <= screen.height &&
        rect.left >= 0 &&
        rect.right <= screen.width;
  }

  group('Compras: cambiar entre "Materiales" y "Gasto general"', () {
    final selector = find.byType(SegmentedButton<bool>);
    Finder option(String label) =>
        find.descendant(of: selector, matching: find.text(label));
    final description = find.widgetWithText(
      TextFormField,
      'Descripción del gasto',
    );

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
        find.widgetWithText(TextFormField, 'Total (Bs.)'),
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
        find.widgetWithText(TextFormField, 'Total (Bs.)'),
        '30',
      );
      await tester.pump();

      await tester.tap(option('Materiales'));
      await tester.pumpAndSettle();
      await tester.tap(option('Gasto general'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextFormField>(description).controller!.text, '');
      final total = find.widgetWithText(TextFormField, 'Total (Bs.)');
      expect(tester.widget<TextFormField>(total).controller!.text, '');
    });

    testWidgets('el título y el selector no se mueven al cambiar de modo', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog(), const Size(412, 915));

      final titleBefore = tester.getTopLeft(find.text('Nueva compra'));
      final selectorBefore = tester.getRect(selector);
      final buttonBefore = tester.getRect(find.text('Registrar compra'));

      await tester.tap(option('Gasto general'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Nueva compra')), titleBefore);
      expect(tester.getRect(selector), selectorBefore);
      expect(tester.getRect(find.text('Registrar compra')), buttonBefore);

      await tester.tap(option('Materiales'));
      await tester.pumpAndSettle();
      expect(tester.getRect(selector), selectorBefore);
    });
  });

  group('botones siempre alcanzables con varios ítems', () {
    testWidgets('Compras: con 3 materiales el botón sigue a la vista', (
      tester,
    ) async {
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals('unidad'))).getSingle();
      for (final name in ['Tela negra', 'Resina parte A', 'Base metálica grande para pines']) {
        await db.into(db.materials).insert(
          MaterialsCompanion.insert(
            name: name,
            unitId: unit.id,
            pricePerUnit: 4.0,
            stock: const Value(100.0),
          ),
        );
      }
      await openSheet(tester, const PurchaseDialog(), phone);

      for (final name in ['Tela negra', 'Resina parte A', 'Base metálica grande para pines']) {
        await tester.tap(find.text('Agregar'));
        await tester.pumpAndSettle();
        await pickFromSearch(tester, find.byType(SearchablePickerField<int>).last, name, name);
        await tester.enterText(find.widgetWithText(TextFormField, '0').first, '2');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agregar').last);
        await tester.pumpAndSettle();
      }

      // El total ya sumó los tres ítems...
      expect(find.text('24'), findsWidgets);
      // ...y el botón de registrar sigue completamente visible, sin desplazar.
      final submit = find.widgetWithText(ElevatedButton, 'Registrar compra');
      expect(fullyOnScreen(tester, submit, phone), isTrue);
      expect(
        fullyOnScreen(tester, find.widgetWithText(OutlinedButton, 'Cancelar'), phone),
        isTrue,
      );
      // El título tampoco se va: solo el formulario se desplaza.
      expect(fullyOnScreen(tester, find.text('Nueva compra'), phone), isTrue);
    });

    testWidgets('Compras: el aviso de error queda junto a los botones, visible', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog(), phone);

      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();

      expect(
        fullyOnScreen(tester, find.text('Agrega al menos un material'), phone),
        isTrue,
      );
    });

    testWidgets('Ventas: con 3 productos en el carrito el botón sigue a la vista', (
      tester,
    ) async {
      for (final name in ['Estuches', 'Pines grandes', 'Stickers']) {
        await db.into(db.products).insert(
          ProductsCompanion.insert(
            categoryId: 1,
            name: name,
            priceA: 10,
            priceB: 8,
            stock: const Value(20),
          ),
        );
      }
      await openSheet(tester, const SaleDialog(), phone);

      for (final name in ['Estuches', 'Pines grandes', 'Stickers']) {
        await searchProducts(tester, name);
        final tile = find.ancestor(
          of: find.descendant(
            of: find.byType(ListTile),
            matching: find.text(name),
          ),
          matching: find.byType(ListTile),
        );
        final add = find.descendant(of: tile.first, matching: find.byIcon(Icons.add));
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
      }

      final submit = find.widgetWithText(ElevatedButton, 'Registrar venta');
      expect(fullyOnScreen(tester, submit, phone), isTrue);
      expect(fullyOnScreen(tester, find.text('Nueva venta'), phone), isTrue);
    });
  });

  group('Producto: el título queda fijo', () {
    testWidgets('al desplazar el formulario el título no se mueve', (
      tester,
    ) async {
      await openSheet(tester, const ProductDialog(), phone);

      final titleBefore = tester.getTopLeft(find.text('Nuevo producto'));
      final scrollable = find.descendant(
        of: find.byType(ProductDialog),
        matching: find.byType(Scrollable),
      );
      await tester.drag(scrollable.first, const Offset(0, -400));
      await tester.pumpAndSettle();

      // El contenido sí se desplazó...
      final position = tester.state<ScrollableState>(scrollable.first).position;
      expect(position.pixels, greaterThan(0));
      // ...pero el título sigue exactamente donde estaba, y los botones a la vista.
      expect(tester.getTopLeft(find.text('Nuevo producto')), titleBefore);
      expect(
        fullyOnScreen(tester, find.widgetWithText(ElevatedButton, 'Crear'), phone),
        isTrue,
      );
    });
  });

  group('diálogo de confirmación de cancelación', () {
    Future<void> openConfirm(WidgetTester tester, String label) async {
      setScreen(tester, phone);
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => confirmCancellation(
                  context,
                  title: '¿Cancelar registro?',
                  message: 'Se conservará como historial.',
                  confirmLabel: label,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('el texto del botón rojo se ve completo, sin puntos suspensivos', (
      tester,
    ) async {
      await openConfirm(tester, 'Cancelar registro');

      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      );
      final label = find.descendant(
        of: confirm,
        matching: find.text('Cancelar registro'),
      );
      expect(label, findsOneWidget);
      final text = tester.widget<Text>(label);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.maxLines, isNull);

      // El texto cabe dentro del botón: nada queda recortado.
      final button = tester.getRect(confirm);
      final textRect = tester.getRect(label);
      expect(textRect.left, greaterThanOrEqualTo(button.left));
      expect(textRect.right, lessThanOrEqualTo(button.right));
      // Y el botón cabe en pantalla.
      expect(fullyOnScreen(tester, confirm, phone), isTrue);
    });

    testWidgets('el botón de confirmar usa el rojo único de la app', (
      tester,
    ) async {
      await openConfirm(tester, 'Cancelar registro');

      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(
        button.style!.backgroundColor!.resolve(<WidgetState>{}),
        AppColors.error,
      );
    });
  });

  group('tarjeta de producto', () {
    Future<void> seedProduct({double priceA = 60, double priceB = 50}) async {
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals('contenedor'))).getSingle();
      final productId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Estuches',
          priceA: priceA,
          priceB: priceB,
          productionCost: const Value(30),
          stock: const Value(10),
        ),
      );
      final materialId = await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Papel holográfico para stickers',
          unitId: unit.id,
          pricePerUnit: 50,
          stock: const Value(10),
        ),
      );
      await db.into(db.productMaterials).insert(
        ProductMaterialsCompanion.insert(
          productId: productId,
          materialId: materialId,
          quantityUsed: 1,
        ),
      );
    }

    Future<void> pumpProducts(WidgetTester tester, Size size) async {
      setScreen(tester, size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(theme: lightTheme, home: const ProductsPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('las píldoras de precio A y B no se parten por la mitad', (
      tester,
    ) async {
      await seedProduct();
      // Ancho muy justo: fuerza el salto de línea.
      await pumpProducts(tester, const Size(420, 640));

      final a = find.text('A: Bs. 60.00');
      final b = find.text('B: Bs. 50.00');
      expect(a, findsOneWidget);
      expect(b, findsOneWidget);
      // Cada etiqueta ocupa una sola línea (no se parte) y mide lo mismo que
      // su vecina, aunque el ancho obligue a pasar la píldora B a la fila de abajo.
      expect(tester.getSize(b).height, tester.getSize(a).height);
      final fontSize = tester.widget<Text>(a).style!.fontSize!;
      expect(tester.getSize(a).height, lessThan(fontSize * 2));
    });

    testWidgets('el precio de cada material lleva el nombre de su unidad', (
      tester,
    ) async {
      await seedProduct();
      await pumpProducts(tester, const Size(900, 1600));

      expect(find.text('Bs. 50.00 / contenedor'), findsOneWidget);
      expect(find.textContaining('/u'), findsNothing);
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

  group('resumen de Compras', () {
    test('"1 Material" en singular y "Materiales" en los demás casos', () {
      expect(materialsSummaryLabel(1), 'Material');
      expect(materialsSummaryLabel(0), 'Materiales');
      expect(materialsSummaryLabel(2), 'Materiales');
      expect(materialsSummaryLabel(12), 'Materiales');
    });
  });
}
