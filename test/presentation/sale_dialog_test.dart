import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
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
      await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
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

      await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
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
}
