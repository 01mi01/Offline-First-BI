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
import 'package:offline_first_bi/presentation/pages/products_page.dart';
import 'package:offline_first_bi/presentation/pages/purchases_page.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

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
          name: 'Tela',
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
        description: 'Transporte',
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
      expect(find.text('Transporte'), findsOneWidget);

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
          name: 'Producto Test',
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
          name: 'Tela',
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
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tela').last);
      await tester.pumpAndSettle();
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
      expect(find.text('12'), findsOneWidget); // 3 x 4 calculado

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

      expect(tester.widget<TextFormField>(totalField).controller!.text, '12');
      expect(find.byTooltip('Usar el total calculado'), findsNothing);
    });
  });

  group('Productos: catálogo con filtro de precio, búsqueda y categoría', () {
    setUp(() async {
      final cat2 = await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Papelería'),
      );
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Acuarela',
          description: const Value('Pintura'),
          priceA: 30,
          priceB: 11,
          stock: const Value(5),
        ),
      );
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: cat2,
          name: 'Cuaderno',
          priceA: 12,
          priceB: 25,
          stock: const Value(5),
        ),
      );
    });

    Future<void> openGrid(WidgetTester tester) async {
      await _pumpPage(tester, db, const ProductsPage());
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
    }

    testWidgets('cards say just "Precio" with the selected band, never A/B', (
      tester,
    ) async {
      await openGrid(tester);

      expect(find.text('Precio: Bs. 30.00'), findsOneWidget); // A
      expect(find.text('Precio: Bs. 12.00'), findsOneWidget);
      expect(find.textContaining('A: Bs.'), findsNothing);
      expect(find.textContaining('B: Bs.'), findsNothing);
      expect(find.textContaining('Precio A:'), findsNothing,
          reason: 'ninguna tarjeta lleva etiqueta A/B');
    }, skip: false);

    testWidgets('the price filter switches the whole catalogue to Precio B or hides prices', (
      tester,
    ) async {
      await openGrid(tester);

      await tester.tap(find.byIcon(Icons.sell_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Precio B').last);
      await tester.pumpAndSettle();
      expect(find.text('Precio: Bs. 11.00'), findsOneWidget);
      expect(find.text('Precio: Bs. 25.00'), findsOneWidget);
      expect(find.text('Precio: Bs. 30.00'), findsNothing);

      await tester.tap(find.byIcon(Icons.sell_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin precio').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Precio: Bs.'), findsNothing);
      expect(find.text('Acuarela'), findsOneWidget);
    });

    testWidgets('the chosen price filter is kept while switching list and catalogue', (
      tester,
    ) async {
      await openGrid(tester);
      await tester.tap(find.byIcon(Icons.sell_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Precio B').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Precio: Bs. 11.00'), findsOneWidget);
    });

    testWidgets('search by name or description narrows both views', (tester) async {
      await openGrid(tester);

      await tester.enterText(find.byType(TextField), 'pintura'); // descripción
      await tester.pumpAndSettle();
      expect(find.text('Acuarela'), findsOneWidget);
      expect(find.text('Cuaderno'), findsNothing);

      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();
      expect(find.text('Acuarela'), findsOneWidget);
      expect(find.text('Cuaderno'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nada que coincida');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets('filters by category', (tester) async {
      await openGrid(tester);

      await tester.tap(find.byIcon(Icons.category_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Papelería').last);
      await tester.pumpAndSettle();

      expect(find.text('Cuaderno'), findsOneWidget);
      expect(find.text('Acuarela'), findsNothing);
    });

    testWidgets('sorts by the selected price, low to high and high to low', (
      tester,
    ) async {
      await openGrid(tester);

      double top(String name) => tester.getTopLeft(find.text(name)).dy;

      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Precio: menor a mayor').last);
      await tester.pumpAndSettle();
      // Precio A: Cuaderno (12) antes que Acuarela (30). Con la cuadrícula de
      // dos columnas, el primero queda a la izquierda, en la misma fila.
      expect(
        tester.getTopLeft(find.text('Cuaderno')).dx,
        lessThan(tester.getTopLeft(find.text('Acuarela')).dx),
      );

      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Precio: mayor a menor').last);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Acuarela')).dx,
        lessThan(tester.getTopLeft(find.text('Cuaderno')).dx),
      );
      expect(top('Acuarela'), top('Cuaderno'));
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
          name: 'Tela',
          unitId: unit.id,
          pricePerUnit: 4,
          stock: const Value(40),
        ),
      );
      await openAddLine(tester);

      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tela').last);
      await tester.pumpAndSettle();

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
        await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Cinta');
        await tester.tap(find.byType(DropdownButtonFormField<int>).last);
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
        var cinta = await db.select(db.materials).getSingle();
        expect(cinta.stock, 5.0);

        // ...así que la línea de esta compra NO trae el 5 de relleno.
        expect(find.text('Cinta'), findsWidgets); // ya seleccionada
        expect(quantityText(tester, 'Cantidad (metro)'), isEmpty);
        expect(quantityText(tester, 'Precio por unidad (Bs.)'), '3');

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
        cinta = await db.select(db.materials).getSingle();
        expect(cinta.stock, 7.0);
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
        CategoriesCompanion.insert(name: 'Bisutería'),
      );
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Cuadernos', isActive: const Value(false)),
      );
    });

    testWidgets('search narrows the list and the status filter separates active/inactive', (
      tester,
    ) async {
      await _pumpPage(tester, db, const CategoriesPage());
      expect(find.text('Bisutería'), findsOneWidget);
      expect(find.text('Cuadernos'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'cuad');
      await tester.pumpAndSettle();
      expect(find.text('Cuadernos'), findsOneWidget);
      expect(find.text('Bisutería'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.toggle_on_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactivas').last);
      await tester.pumpAndSettle();
      expect(find.text('Cuadernos'), findsOneWidget);
      expect(find.text('Bisutería'), findsNothing);
    });
  });
}
