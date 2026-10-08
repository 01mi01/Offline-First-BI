import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/categories_page.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/presentation/pages/products_page.dart';
import 'package:offline_first_bi/presentation/pages/purchases_page.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'search_helpers.dart';

void _phone(WidgetTester tester, {Size size = const Size(412, 915)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester,
  AppDatabase db,
  Widget page, {
  Size size = const Size(412, 915),
}) async {
  _phone(tester, size: size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: lightTheme, home: page),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester, AppDatabase db, Widget sheet) async {
  _phone(tester);
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

  group('Compras: filtro Material / Gasto', () {
    setUp(() async {
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals('unidad'))).getSingle();
      final materialId = await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Tela negra',
          unitId: unit.id,
          pricePerUnit: 4,
          stock: const Value(10),
        ),
      );
      final repo = PurchaseRepository(db);
      await repo.createPurchase(
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 12,
        date: DateTime(2026, 1, 1),
        locationId: null,
        eventId: null,
        items: [
          {'materialId': materialId, 'quantity': 3.0, 'unitPrice': 4.0},
        ],
      );
      await repo.createPurchase(
        supplierId: null,
        isMaterial: false,
        description: 'Pasaje de bus',
        totalAmount: 30,
        date: DateTime(2026, 1, 2),
        locationId: null,
        eventId: null,
        items: const [],
      );
    });

    Future<void> pick(WidgetTester tester, String option) async {
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    testWidgets('shows both by default, then only Gastos, only Materiales, and both again', (
      tester,
    ) async {
      await _pumpPage(tester, db, const PurchasesListBody());

      expect(find.text('Material'), findsOneWidget);
      expect(find.text('Gasto'), findsOneWidget);

      await pick(tester, 'Gastos');
      expect(find.text('Gasto'), findsOneWidget);
      expect(find.text('Material'), findsNothing);
      expect(find.text('Pasaje de bus'), findsOneWidget);

      await pick(tester, 'Materiales');
      expect(find.text('Material'), findsOneWidget);
      expect(find.text('Gasto'), findsNothing);

      await pick(tester, 'Ambos tipos');
      expect(find.text('Material'), findsOneWidget);
      expect(find.text('Gasto'), findsOneWidget);
    });

    testWidgets('the "Gasto" pill uses the neutral text color, not green or red', (
      tester,
    ) async {
      await _pumpPage(tester, db, const PurchasesListBody());

      final pill = tester.widget<Text>(find.text('Gasto'));
      expect(pill.style!.color, AppColors.textPrimary);
      expect(pill.style!.color, isNot(AppColors.success));
      expect(pill.style!.color, isNot(AppColors.error));
    });
  });

  group('Ventas: descuento', () {
    setUp(() async {
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Libro',
          priceA: 20,
          priceB: 20,
          stock: const Value(50),
        ),
      );
    });

    TextEditingController? discountController(WidgetTester tester) =>
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, '0'),
            )
            .controller;

    testWidgets('a minus sign cannot be typed or pasted into the discount', (
      tester,
    ) async {
      await _openSheet(tester, db, const SaleDialog());

      await tester.enterText(find.widgetWithText(TextFormField, '0'), '-5');
      await tester.pumpAndSettle();

      expect(discountController(tester)!.text, '5');
      expect(find.textContaining('-5'), findsNothing);
    });

    testWidgets('the "Descuento" line is always shown, including 0', (
      tester,
    ) async {
      await _openSheet(tester, db, const SaleDialog());

      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Descuento'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);

      await searchProducts(tester, 'Libro');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '0'), '5');
      await tester.pumpAndSettle();

      expect(find.text('Descuento'), findsOneWidget);
      expect(find.text('- Bs. 5.00'), findsOneWidget);
      expect(find.text('Bs. 15.00'), findsOneWidget);
    });

    testWidgets('the receipt of a sale lists Subtotal, Descuento and Total', (
      tester,
    ) async {
      await SaleRepository(db).createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 20,
        discount: 0,
        finalAmount: 20,
        date: DateTime(2026, 1, 1),
        items: [
          {'productId': 1, 'quantity': 1, 'unitPrice': 20.0, 'priceType': 'A'},
        ],
      );
      await SaleRepository(db).createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 20,
        discount: 4,
        finalAmount: 16,
        date: DateTime(2026, 1, 2),
        items: [
          {'productId': 1, 'quantity': 1, 'unitPrice': 20.0, 'priceType': 'A'},
        ],
      );
      // Pantalla ancha: la fuente de prueba es más ancha que Roboto.
      await _pumpPage(tester, db, const SalesListBody(), size: const Size(900, 1600));

      // La más reciente (con descuento de 4)...
      await tester.tap(find.text('Sin nombre').first);
      await tester.pumpAndSettle();
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Descuento'), findsOneWidget);
      expect(find.text('- Bs. 4.00'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // ...y la que no tuvo descuento: la línea está, en cero.
      await tester.tap(find.text('Sin nombre').last);
      await tester.pumpAndSettle();
      expect(find.text('Descuento'), findsOneWidget);
      expect(find.text('- Bs. 4.00'), findsNothing);
    });
  });

  group('Compras: total editable a mano', () {
    setUp(() async {
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals('unidad'))).getSingle();
      await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Tela negra',
          unitId: unit.id,
          pricePerUnit: 4,
          stock: const Value(100),
        ),
      );
    });

    Future<void> addTela(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Agregar'));
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await pickFromSearch(tester, find.byType(SearchablePickerField<int>).last, 'Tela negra', 'Tela negra');
      await tester.enterText(find.widgetWithText(TextFormField, '0').first, '3');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
    }

    final totalField = find.byKey(const ValueKey('purchase-total-materials'));

    testWidgets('the calculated total can be overridden and is what gets saved', (
      tester,
    ) async {
      await _openSheet(tester, db, const PurchaseDialog());
      await addTela(tester);
      expect(find.text('12.00'), findsOneWidget); // 3 x 4 calculado

      await tester.ensureVisible(totalField);
      await tester.enterText(totalField, '50');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Registrar compra'));
      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();

      final purchase = (await PurchaseRepository(db).getAll()).single;
      expect(purchase.totalAmount, 50.0);

      // El stock y el precio del material salen de los ítems, no del total.
      final material = await db.select(db.materials).getSingle();
      expect(material.stock, 103.0);
      expect(material.pricePerUnit, 4.0);
    });

    testWidgets('once overridden, changing the lines no longer rewrites the total', (
      tester,
    ) async {
      await _openSheet(tester, db, const PurchaseDialog());
      await addTela(tester);

      await tester.ensureVisible(totalField);
      await tester.enterText(totalField, '50');
      await tester.pumpAndSettle();

      // "+" de la línea de Tela: la cantidad sube a 4, el total sigue en 50.
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(totalField);
      expect(tester.widget<TextFormField>(totalField).controller!.text, '50');
    });

    testWidgets('the reset button goes back to the calculated total', (
      tester,
    ) async {
      await _openSheet(tester, db, const PurchaseDialog());
      await addTela(tester);

      await tester.ensureVisible(totalField);
      await tester.enterText(totalField, '50');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Usar el total calculado'), findsOneWidget);

      await tester.tap(find.byTooltip('Usar el total calculado'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextFormField>(totalField).controller!.text, '12.00');
      expect(find.byTooltip('Usar el total calculado'), findsNothing);
    });
  });

  group('Productos: filtro de precio (lista), búsqueda y categoría', () {
    setUp(() async {
      final cat2 = await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Papelería'),
      );
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Estuches',
          description: const Value('Pintura'),
          priceA: 30,
          priceB: 11,
          stock: const Value(5),
        ),
      );
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: cat2,
          name: 'Miniaturas',
          priceA: 12,
          priceB: 25,
          stock: const Value(5),
        ),
      );
    });

    Future<void> openList(WidgetTester tester) =>
        _pumpPage(tester, db, const ProductsPage());

    Future<void> toGrid(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
    }

    Future<void> toList(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();
    }

    // El filtro de precio solo se controla desde la vista de lista.
    Future<void> pickPrice(WidgetTester tester, String option) async {
      await tester.tap(find.byIcon(Icons.sell_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    // Posiciones de los controles de arriba (centros) en la vista actual.
    Map<String, Offset> topControls(WidgetTester tester) => {
      'price': tester.getCenter(find.byIcon(Icons.sell_outlined)),
      'category': tester.getCenter(find.byIcon(Icons.category_outlined)),
      'status': tester.getCenter(find.text('Todos')),
      'search': tester.getCenter(find.byType(TextField)),
      'list': tester.getCenter(find.byIcon(Icons.list)),
      'grid': tester.getCenter(find.byIcon(Icons.grid_view_rounded)),
    };

    testWidgets('layout: the three filters on top aligned right, search below filling the width next to the toggle', (
      tester,
    ) async {
      await openList(tester);
      final c = topControls(tester);

      // Arriba: precio, categoría y estado, en ese orden y pegados a la
      // derecha. Si no caben en una línea (412 de ancho), el último pasa a la
      // siguiente, también a la derecha.
      expect(c['price']!.dy, closeTo(c['category']!.dy, 4));
      expect(c['price']!.dx, lessThan(c['category']!.dx));
      expect(c['status']!.dy, greaterThanOrEqualTo(c['category']!.dy));
      expect(c['status']!.dx, greaterThan(300));
      // Debajo: el buscador y, a su derecha, el toggle lista/catálogo.
      expect(c['search']!.dy, greaterThan(c['status']!.dy + 20));
      expect(c['search']!.dy, closeTo(c['list']!.dy, 4));
      expect(c['search']!.dx, lessThan(c['list']!.dx));
      expect(c['grid']!.dx, greaterThan(c['list']!.dx));
      expect(c['grid']!.dx, greaterThan(350));
      // El buscador ocupa el ancho disponible (hasta el toggle).
      final searchRect = tester.getRect(find.byType(TextField));
      expect(searchRect.width, greaterThan(250));
    });

    testWidgets('filters, search and buttons are in exactly the same place in the catalogue view', (
      tester,
    ) async {
      await openList(tester);
      final inList = topControls(tester);

      await toGrid(tester);
      final inGrid = topControls(tester);
      for (final key in inList.keys) {
        expect(inGrid[key], inList[key], reason: key);
      }
    });

    testWidgets('the name and price sorters are gone', (tester) async {
      await openList(tester);

      expect(find.byIcon(Icons.swap_vert), findsNothing);
      expect(find.text('Nombre'), findsNothing);
      expect(find.textContaining('menor a mayor'), findsNothing);
      // El orden de siempre (alfabético) se mantiene.
      expect(
        tester.getTopLeft(find.text('Estuches')).dy,
        lessThan(tester.getTopLeft(find.text('Miniaturas')).dy),
      );
    });

    testWidgets('the price control is in both views, in the same place', (
      tester,
    ) async {
      await openList(tester);
      expect(find.byIcon(Icons.sell_outlined), findsOneWidget);

      await toGrid(tester);
      expect(find.byIcon(Icons.sell_outlined), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert), findsNothing);
    });

    testWidgets('cards say just "Precio" with a single band chosen, never A/B', (
      tester,
    ) async {
      await openList(tester);
      await pickPrice(tester, 'Precio A');
      await toGrid(tester);

      expect(find.text('Precio: Bs. 30.00'), findsOneWidget); // A
      expect(find.text('Precio: Bs. 12.00'), findsOneWidget);
      expect(find.textContaining('A: Bs.'), findsNothing);
      expect(find.textContaining('B: Bs.'), findsNothing);
    });

    testWidgets('the price filter has four options, including "Ambos"', (
      tester,
    ) async {
      await openList(tester);

      await tester.tap(find.byIcon(Icons.sell_outlined));
      await tester.pumpAndSettle();
      for (final option in ['Precio A', 'Precio B', 'Ambos', 'Sin precio']) {
        expect(find.text(option), findsWidgets, reason: option);
      }
      // Orden del menú: Ambos, Precio A, Precio B, Sin precio.
      double top(String t) => tester.getTopLeft(find.text(t).last).dy;
      expect(top('Ambos'), lessThan(top('Precio A')));
      expect(top('Precio A'), lessThan(top('Precio B')));
      expect(top('Precio B'), lessThan(top('Sin precio')));
      expect(find.text('Ambos'), findsNWidgets(2)); // la etiqueta del chip (valor por defecto de la lista) y la opción
    });

    testWidgets('the catalogue reflects the price chosen in the list: B, none, both', (
      tester,
    ) async {
      await openList(tester);

      await pickPrice(tester, 'Precio B');
      await toGrid(tester);
      expect(find.text('Precio: Bs. 11.00'), findsOneWidget);
      expect(find.text('Precio: Bs. 25.00'), findsOneWidget);
      expect(find.text('Precio: Bs. 30.00'), findsNothing);

      await toList(tester);
      await pickPrice(tester, 'Sin precio');
      await toGrid(tester);
      expect(find.textContaining('Precio: Bs.'), findsNothing);
      expect(find.text('Estuches'), findsOneWidget);

      await toList(tester);
      await pickPrice(tester, 'Ambos');
      await toGrid(tester);
      expect(find.text('A: Bs. 30.00'), findsOneWidget);
      expect(find.text('B: Bs. 11.00'), findsOneWidget);
      expect(find.text('A: Bs. 12.00'), findsOneWidget);
      expect(find.text('B: Bs. 25.00'), findsOneWidget);
      expect(find.textContaining('Precio: Bs.'), findsNothing);

      await tester.tap(find.text('Estuches'));
      await tester.pumpAndSettle();
      expect(find.text('Precio A: Bs. 30.00'), findsOneWidget);
      expect(find.text('Precio B: Bs. 11.00'), findsOneWidget);
    });

    testWidgets('list view follows the filter: A only, B only, none, both', (
      tester,
    ) async {
      await openList(tester);

      // Sin elegir nada, la lista sigue mostrando ambos precios.
      expect(find.text('A: Bs. 30.00'), findsOneWidget);
      expect(find.text('B: Bs. 11.00'), findsOneWidget);

      await pickPrice(tester, 'Precio B');
      expect(find.text('B: Bs. 11.00'), findsOneWidget);
      expect(find.text('B: Bs. 25.00'), findsOneWidget);
      expect(find.text('A: Bs. 30.00'), findsNothing);
      expect(find.text('A: Bs. 12.00'), findsNothing);

      await pickPrice(tester, 'Precio A');
      expect(find.text('A: Bs. 30.00'), findsOneWidget);
      expect(find.text('B: Bs. 11.00'), findsNothing);

      await pickPrice(tester, 'Sin precio');
      expect(find.textContaining('Bs. 30.00'), findsNothing);
      expect(find.textContaining('Bs. 11.00'), findsNothing);
      expect(find.text('Estuches'), findsOneWidget);

      await pickPrice(tester, 'Ambos');
      expect(find.text('A: Bs. 30.00'), findsOneWidget);
      expect(find.text('B: Bs. 11.00'), findsOneWidget);
    });

    testWidgets('the chosen price is kept while switching list, catalogue and list', (
      tester,
    ) async {
      await openList(tester);
      await pickPrice(tester, 'Precio B');

      await toGrid(tester);
      await toList(tester);

      // Sigue en "Precio B": solo la píldora B.
      expect(find.text('B: Bs. 11.00'), findsOneWidget);
      expect(find.text('A: Bs. 30.00'), findsNothing);
    });

    testWidgets('search by name or description narrows both views', (tester) async {
      await openList(tester);

      await tester.enterText(find.byType(TextField), 'pintura'); // descripción
      await tester.pumpAndSettle();
      expect(find.text('Estuches'), findsOneWidget);
      expect(find.text('Miniaturas'), findsNothing);

      await toGrid(tester);
      expect(find.text('Estuches'), findsOneWidget);
      expect(find.text('Miniaturas'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nada que coincida');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets('filters by category', (tester) async {
      await openList(tester);

      await tester.tap(find.byIcon(Icons.category_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Papelería').last);
      await tester.pumpAndSettle();

      expect(find.text('Miniaturas'), findsOneWidget);
      expect(find.text('Estuches'), findsNothing);
    });
  });

  group('Compras: la cantidad de una línea nueva no se rellena con el stock', () {
    Future<void> openAddLine(WidgetTester tester) async {
      await _openSheet(tester, db, const PurchaseDialog());
      await tester.ensureVisible(find.text('Agregar'));
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
    }

    String quantityText(WidgetTester tester, String label) => tester
        .widget<TextFormField>(find.widgetWithText(TextFormField, label))
        .controller!
        .text;

    testWidgets('picking an existing material that has stock leaves the quantity blank', (
      tester,
    ) async {
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals('metro'))).getSingle();
      await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Tela negra',
          unitId: unit.id,
          pricePerUnit: 4,
          stock: const Value(40),
        ),
      );
      await openAddLine(tester);

      await pickFromSearch(tester, find.byType(SearchablePickerField<int>).last, 'Tela negra', 'Tela negra');

      expect(quantityText(tester, 'Cantidad (metro)'), isEmpty);
    });

    testWidgets(
      'a material created from the form with initial stock starts blank, and '
      'the purchased quantity adds to its stock instead of replacing it',
      (tester) async {
        await openAddLine(tester);

        // "Crear nuevo material" con stock inicial 5 a Bs. 3 el metro.
        await tester.tap(find.text('Crear nuevo material'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Papel para stickers');
        // La unidad es un desplegable corto, no un buscador.
        await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Unidad'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('metro').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, 'Stock'), '5');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Precio por unidad'),
          '3',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Crear'));
        await tester.tap(find.text('Crear'));
        await tester.pumpAndSettle();

        // Su stock inicial ya quedó como su propia compra...
        expect(await PurchaseRepository(db).getAll(), hasLength(1));
        var papelStickers = await db.select(db.materials).getSingle();
        expect(papelStickers.stock, 5.0);

        // ...así que la línea de esta compra NO trae el 5 de relleno.
        expect(find.text('Papel para stickers'), findsWidgets); // ya seleccionada
        expect(quantityText(tester, 'Cantidad (metro)'), isEmpty);
        expect(quantityText(tester, 'Precio por unidad (Bs.)'), '3.00');

        // Se compra lo de esta ocasión: 2 metros.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Cantidad (metro)'),
          '2',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Agregar').last);
        await tester.tap(find.text('Agregar').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Registrar compra'));
        await tester.tap(find.text('Registrar compra'));
        await tester.pumpAndSettle();

        // El stock suma (5 + 2), no se reemplaza ni se duplica (5 + 5).
        papelStickers = await db.select(db.materials).getSingle();
        expect(papelStickers.stock, 7.0);
        final purchases = await PurchaseRepository(db).getAll();
        expect(purchases, hasLength(2));
        expect(
          purchases.map((p) => p.totalAmount).toList()..sort(),
          [6.0, 15.0], // la compra de 2 x 3 y la del stock inicial 5 x 3
        );
      },
    );
  });

  group('Categorías: búsqueda y estado', () {
    setUp(() async {
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Pines'),
      );
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Libros', isActive: const Value(false)),
      );
    });

    testWidgets('search narrows the list and the status filter separates active/inactive', (
      tester,
    ) async {
      await _pumpPage(tester, db, const CategoriesPage());
      expect(find.text('Pines'), findsOneWidget);
      expect(find.text('Libros'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'libr');
      await tester.pumpAndSettle();
      expect(find.text('Libros'), findsOneWidget);
      expect(find.text('Pines'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      // El filtro de estado: sin icono, con el texto "Todas" (valor por defecto).
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactivas').last);
      await tester.pumpAndSettle();
      expect(find.text('Libros'), findsOneWidget);
      expect(find.text('Pines'), findsNothing);
    });
  });
}
