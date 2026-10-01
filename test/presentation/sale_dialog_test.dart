import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

Future<void> _openSaleDialog(WidgetTester tester, AppDatabase db) async {
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
                builder: (_) => const SaleDialog(),
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

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Producto Test',
        priceA: 20.0,
        priceB: 20.0,
        stock: const Value(50),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'collects a client, a product and a discount, and shows the correct '
    'subtotal/discount/total (computed by SaleRepository, not the dialog)',
    (tester) async {
      await _openSaleDialog(tester, db);

      expect(find.text('Nueva venta'), findsOneWidget);
      // Sin nada en el carrito, el subtotal y el total deben ser 0
      expect(find.text('Bs. 0.00'), findsWidgets);

      // Selecciona el cliente por defecto ("Sin nombre")
      await tester.tap(find.byType(SearchablePickerField<int>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin nombre').last);
      await tester.pumpAndSettle();

      // Agrega el producto al carrito tocando el ícono "+"
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // El carrito y el resumen deben reflejar el precio del producto
      expect(find.text('Carrito'), findsOneWidget);
      expect(find.text('Bs. 20.00'), findsWidgets);

      // Escribe un descuento y confirma que el total se recalcula
      await tester.enterText(find.widgetWithText(TextFormField, '0'), '5');
      await tester.pumpAndSettle();

      expect(find.text('- Bs. 5.00'), findsOneWidget);
      expect(find.text('Bs. 15.00'), findsOneWidget);

      // Registra la venta
      await tester.ensureVisible(find.text('Registrar venta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();

      // El diálogo se cierra tras un registro exitoso
      expect(find.byType(SaleDialog), findsNothing);

      // La lógica de negocio (repositorio) persistió la venta correctamente
      final repository = SaleRepository(db);
      final sales = await repository.getAll();
      expect(sales, hasLength(1));
      expect(sales.first.totalAmount, 20.0);
      expect(sales.first.discount, 5.0);
      expect(sales.first.finalAmount, 15.0);

      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(1))).getSingle();
      expect(product.stock, 49); // 50 - 1 unidad vendida
    },
  );

  testWidgets(
    'shows a validation error instead of saving when the discount exceeds the subtotal',
    (tester) async {
      await _openSaleDialog(tester, db);

      await tester.tap(find.byType(SearchablePickerField<int>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin nombre').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Descuento mayor al subtotal (20)
      await tester.enterText(find.widgetWithText(TextFormField, '0'), '999');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Registrar venta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();

      expect(
        find.text('El descuento no puede ser mayor al subtotal'),
        findsOneWidget,
      );
      // El diálogo sigue abierto: no se guardó nada
      expect(find.byType(SaleDialog), findsOneWidget);

      final repository = SaleRepository(db);
      expect(await repository.getAll(), isEmpty);
    },
  );

  // Productos con precios A y B distintos, para comprobar que cada banda cobra
  // su propio monto (los productos de las demás pruebas tienen A == B).
  Future<void> seedDistinctPriceProducts() async {
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Acuarela',
        priceA: 55.0,
        priceB: 40.0,
        stock: const Value(10),
      ),
    );
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Marcador',
        priceA: 8.0,
        priceB: 6.5,
        stock: const Value(20),
      ),
    );
  }

  Future<void> addToCart(WidgetTester tester, String productName) async {
    // Cada fila del catálogo (ListTile) tiene su propio ícono "+": se toca el
    // de la fila del producto pedido.
    final tile = find.ancestor(
      of: find.text(productName).first,
      matching: find.byType(ListTile),
    );
    final add = find.descendant(of: tile.first, matching: find.byIcon(Icons.add));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a product with distinct A/B prices is charged Precio A by default and '
    'Precio B after switching the band, and the sale persists the B price',
    (tester) async {
      await seedDistinctPriceProducts();
      await _openSaleDialog(tester, db);

      // El catálogo muestra ambos precios del producto.
      expect(find.textContaining('A: Bs. 55.00  •  B: Bs. 40.00'), findsOneWidget);

      await addToCart(tester, 'Acuarela');
      // Por defecto se cobra Precio A: el ítem del carrito y el total.
      expect(find.text('Bs. 55.00'), findsWidgets);
      expect(find.text('Bs. 40.00'), findsNothing);

      // Cambia a Precio B: el monto pasa a 40.
      await tester.tap(find.text('Precio B'));
      await tester.pumpAndSettle();
      expect(find.text('Bs. 40.00'), findsWidgets);
      expect(find.text('Bs. 55.00'), findsNothing);

      // Y de vuelta a Precio A: vuelve a 55.
      await tester.tap(find.text('Precio A'));
      await tester.pumpAndSettle();
      expect(find.text('Bs. 55.00'), findsWidgets);

      await tester.tap(find.text('Precio B'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(SearchablePickerField<int>).at(0));
      await tester.tap(find.byType(SearchablePickerField<int>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin nombre').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Registrar venta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();

      final repository = SaleRepository(db);
      final sale = (await repository.getAll()).single;
      expect(sale.finalAmount, 40.0);
      final items = await repository.getItemsForSale(sale.id);
      expect(items.single.unitPrice, 40.0);
      expect(items.single.priceType, 'B');
      expect(items.single.subtotal, 40.0);

      final product = await (db.select(
        db.products,
      )..where((p) => p.name.equals('Acuarela'))).getSingle();
      expect(product.stock, 9);
    },
  );

  testWidgets(
    'one sale can mix bands: a product at Precio A and another at Precio B '
    'are each charged their own price and the total adds them up',
    (tester) async {
      await seedDistinctPriceProducts();
      await _openSaleDialog(tester, db);

      await addToCart(tester, 'Acuarela');
      await addToCart(tester, 'Marcador');

      // Los dos ítems arrancan en Precio A: 55 + 8 = 63.
      expect(find.text('Bs. 63.00'), findsWidgets);

      // Solo el ítem del carrito de Marcador (el segundo) pasa a Precio B.
      await tester.tap(find.text('Precio B').last);
      await tester.pumpAndSettle();

      // 55 (A) + 6.5 (B) = 61.5
      expect(find.text('Bs. 61.50'), findsWidgets);

      await tester.ensureVisible(find.byType(SearchablePickerField<int>).at(0));
      await tester.tap(find.byType(SearchablePickerField<int>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin nombre').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Registrar venta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();

      final repository = SaleRepository(db);
      final sale = (await repository.getAll()).single;
      expect(sale.totalAmount, 61.5);
      expect(sale.finalAmount, 61.5);

      final items = await repository.getItemsForSale(sale.id);
      final byName = {for (final i in items) i.productName: i};
      expect(byName['Acuarela']!.priceType, 'A');
      expect(byName['Acuarela']!.unitPrice, 55.0);
      expect(byName['Marcador']!.priceType, 'B');
      expect(byName['Marcador']!.unitPrice, 6.5);
    },
  );
}
