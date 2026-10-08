import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/product_repository.dart';
import 'package:offline_first_bi/models/product_model.dart';
import 'package:offline_first_bi/presentation/dialogs/product_dialog.dart';
import 'package:offline_first_bi/presentation/widgets/unit_quantity_input.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

Future<void> _openProductDialog(
  WidgetTester tester,
  AppDatabase db, {
  ProductModel? product,
}) async {
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
                builder: (_) => ProductDialog(product: product),
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

Future<void> _type(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
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

  testWidgets(
    'Precio A and Precio B are two independent inputs and are saved as '
    'different values',
    (tester) async {
      await _openProductDialog(tester, db);

      expect(find.widgetWithText(TextFormField, 'Precio A'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Precio B'), findsOneWidget);

      await _type(tester, 'Nombre', 'Estuches');
      await _type(tester, 'Precio A', '55');
      await _type(tester, 'Precio B', '40');
      await _type(tester, 'Stock', '10');

      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      final products = await ProductRepository(db).getAllIncludingInactive();
      expect(products, hasLength(1));
      expect(products.single.priceA, 55.0);
      expect(products.single.priceB, 40.0);
    },
  );

  testWidgets('the price fields carry no "same value if left empty" hint', (
    tester,
  ) async {
    await _openProductDialog(tester, db);

    expect(find.textContaining('Igual al'), findsNothing);
    expect(find.textContaining('si se deja vacío'), findsNothing);

    // Al enfocar un precio vacío, el hint es el "0.00" de siempre.
    await tester.tap(find.widgetWithText(TextFormField, 'Precio A'));
    await tester.pumpAndSettle();
    expect(find.text('0.00'), findsWidgets);
    expect(find.textContaining('Igual al'), findsNothing);
  });

  Future<void> create(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Crear'));
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'only Precio A is enough: Precio B is saved with the same value',
    (tester) async {
      await _openProductDialog(tester, db);

      await _type(tester, 'Nombre', 'Estuches');
      await _type(tester, 'Precio A', '55');
      await _type(tester, 'Stock', '10');
      await create(tester);

      expect(find.byType(ProductDialog), findsNothing);
      final product = (await ProductRepository(db).getAllIncludingInactive())
          .single;
      expect(product.priceA, 55.0);
      expect(product.priceB, 55.0);
    },
  );

  testWidgets(
    'only Precio B is enough: Precio A is saved with the same value',
    (tester) async {
      await _openProductDialog(tester, db);

      await _type(tester, 'Nombre', 'Estuches');
      await _type(tester, 'Precio B', '40');
      await _type(tester, 'Stock', '10');
      await create(tester);

      final product = (await ProductRepository(db).getAllIncludingInactive())
          .single;
      expect(product.priceA, 40.0);
      expect(product.priceB, 40.0);
    },
  );

  testWidgets('at least one price is required: with none the form does not save', (
    tester,
  ) async {
    await _openProductDialog(tester, db);

    await _type(tester, 'Nombre', 'Estuches');
    await _type(tester, 'Stock', '10');
    await create(tester);

    expect(find.text('Indica al menos un precio'), findsNWidgets(2));
    expect(find.byType(ProductDialog), findsOneWidget);
    expect(await ProductRepository(db).getAllIncludingInactive(), isEmpty);
  });

  testWidgets(
    'the cost check updates live while typing the prices, before saving',
    (tester) async {
      await _openProductDialog(tester, db);

      const error = 'Debe ser menor a los precios de venta';
      await _type(tester, 'Precio A', '55');
      await _type(tester, 'Precio B', '40');
      await _type(tester, 'Costo de producción', '30');
      expect(find.text(error), findsNothing);

      // Bajar el Precio B por debajo del costo marca el error al instante...
      await _type(tester, 'Precio B', '20');
      expect(find.text(error), findsOneWidget);

      // ...y subirlo de nuevo lo quita, sin pulsar "Crear" en ningún momento.
      await _type(tester, 'Precio B', '35');
      expect(find.text(error), findsNothing);
    },
  );

  testWidgets(
    'with a single price typed, the cost is checked against that price',
    (tester) async {
      await _openProductDialog(tester, db);

      await _type(tester, 'Precio A', '55');
      await _type(tester, 'Costo de producción', '60');

      expect(
        find.text('Debe ser menor a los precios de venta'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the production cost must be lower than BOTH sale prices',
    (tester) async {
      await _openProductDialog(tester, db);

      await _type(tester, 'Nombre', 'Estuches');
      await _type(tester, 'Precio A', '55');
      await _type(tester, 'Precio B', '40');
      await _type(tester, 'Costo de producción', '45'); // < A pero >= B
      await _type(tester, 'Stock', '10');

      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(
        find.text('Debe ser menor a los precios de venta'),
        findsOneWidget,
      );
      expect(await ProductRepository(db).getAllIncludingInactive(), isEmpty);
    },
  );

  testWidgets(
    'editing shows whole-number prices with two decimals and lets the '
    'two prices change independently',
    (tester) async {
      await ProductRepository(db).save(
        name: 'Estuches',
        priceA: 50.0,
        priceB: 35.5,
        productionCost: 20.0,
        stock: 10,
      );
      final product = (await ProductRepository(db).getAllIncludingInactive()).single;

      await _openProductDialog(tester, db, product: product);

      TextFormField field(String label) => tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, label),
      );
      expect(field('Precio A').controller!.text, '50.00');
      expect(field('Precio B').controller!.text, '35.50');
      expect(field('Costo de producción').controller!.text, '20.00');

      // Solo cambia B: A se conserva.
      await _type(tester, 'Precio B', '30');
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final saved = (await ProductRepository(db).getAllIncludingInactive()).single;
      expect(saved.priceA, 50.0);
      expect(saved.priceB, 30.0);
    },
  );

  group('Stock is a whole number', () {
    Future<void> fillValidProduct(WidgetTester tester) async {
      await _type(tester, 'Nombre', 'Estuches');
      await _type(tester, 'Precio A', '55');
      await _type(tester, 'Precio B', '40');
    }

    testWidgets('a decimal is rejected with feedback and never saved as 0', (
      tester,
    ) async {
      await _openProductDialog(tester, db);
      await fillValidProduct(tester);

      final stock = find.widgetWithText(TextFormField, 'Stock');
      await tester.ensureVisible(stock);
      await tester.enterText(stock, '2');
      await tester.pump();
      await tester.enterText(stock, '2.'); // el usuario intenta "2.5"
      await tester.pump();

      expect(tester.widget<TextFormField>(stock).controller!.text, '2');
      expect(find.text(wholeNumberOnlyMessage), findsOneWidget);

      // Aunque se guarde ahora, el valor es el entero visible, no 0.
      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      final saved = (await ProductRepository(db).getAllIncludingInactive()).single;
      expect(saved.stock, 2);
    });

    testWidgets('a pasted decimal is rejected as a whole and the form will not save without a stock', (
      tester,
    ) async {
      await _openProductDialog(tester, db);
      await fillValidProduct(tester);

      final stock = find.widgetWithText(TextFormField, 'Stock');
      await tester.ensureVisible(stock);
      await tester.enterText(stock, '10.5');
      await tester.pump();

      expect(tester.widget<TextFormField>(stock).controller!.text, '');
      expect(find.text(wholeNumberOnlyMessage), findsOneWidget);

      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      // No se guardó nada (ni un producto con stock 0): hay un error de validación.
      expect(find.byType(ProductDialog), findsOneWidget);
      expect(await ProductRepository(db).getAllIncludingInactive(), isEmpty);
    });

    testWidgets('a valid whole-number stock saves exactly as typed', (
      tester,
    ) async {
      await _openProductDialog(tester, db);
      await fillValidProduct(tester);
      await _type(tester, 'Stock', '25');

      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      final saved = (await ProductRepository(db).getAllIncludingInactive()).single;
      expect(saved.stock, 25);
    });

    testWidgets('0 is a valid initial stock', (tester) async {
      await _openProductDialog(tester, db);
      await fillValidProduct(tester);
      await _type(tester, 'Stock', '0');

      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      final saved = (await ProductRepository(db).getAllIncludingInactive()).single;
      expect(saved.stock, 0);
    });

    testWidgets('editing keeps the stock and rejects a decimal edit too', (
      tester,
    ) async {
      await ProductRepository(db).save(
        name: 'Estuches',
        priceA: 50,
        priceB: 40,
        stock: 10,
      );
      final product = (await ProductRepository(db).getAllIncludingInactive()).single;
      await _openProductDialog(tester, db, product: product);

      final stock = find.widgetWithText(TextFormField, 'Stock');
      await tester.ensureVisible(stock);
      expect(tester.widget<TextFormField>(stock).controller!.text, '10');

      await tester.enterText(stock, '10.');
      await tester.pump();
      expect(tester.widget<TextFormField>(stock).controller!.text, '10');
      expect(find.text(wholeNumberOnlyMessage), findsOneWidget);
    });
  });
}
