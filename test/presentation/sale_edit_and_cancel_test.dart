import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/models/sale_model.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/materials_page.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// Edición y cancelación de ventas / registros de uso desde la interfaz.
void main() {
  late AppDatabase db;

  Future<int> productStock() async => (await (db.select(
    db.products,
  )..where((p) => p.id.equals(1))).getSingle()).stock;

  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(theme: lightTheme, home: home),
  );

  // Producto con 5 en stock; una venta suya de 2 unidades lo deja en 3.
  Future<SaleModel> seedSaleOfTwo() async {
    final repository = SaleRepository(db);
    await repository.createSale(
      clientId: 1, // "Sin nombre", sembrado al crear la base
      locationId: null,
      eventId: null,
      totalAmount: 20,
      discount: 0,
      finalAmount: 20,
      date: DateTime(2024, 1, 1),
      items: [
        {'productId': 1, 'quantity': 2, 'unitPrice': 10.0},
      ],
    );
    return (await repository.getAll()).single;
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Collar',
        priceA: 10,
        priceB: 10,
        stock: const Value(5),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('editing a sale offers current stock + the units the sale holds', () {
    Future<void> openEditDialog(WidgetTester tester, SaleModel sale) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SaleDialog(sale: sale),
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

    testWidgets(
      'with 3 in stock and 2 in the sale, the "+" stepper goes up to 5 (and no '
      'further), the catalog shows 5, and saving leaves stock at 0',
      (tester) async {
        final sale = await seedSaleOfTwo();
        expect(await productStock(), 3);

        await openEditDialog(tester, sale);

        // El carrito arranca con las 2 unidades de la venta, y el catálogo
        // ofrece 5 (3 en inventario + 2 de esta venta), no 3.
        expect(find.textContaining('Stock: 5'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);

        // El único "+" visible es el del carrito (en el catálogo el producto
        // ya aparece marcado).
        final plus = find.byIcon(Icons.add);
        for (var i = 0; i < 6; i++) {
          await tester.ensureVisible(plus);
          await tester.tap(plus);
          await tester.pumpAndSettle();
        }
        // Tras 6 toques solo sube hasta 5: el tope es 3 + 2, no el 3 de antes.
        expect(find.text('5'), findsOneWidget);
        expect(find.text('6'), findsNothing);

        await tester.ensureVisible(find.text('Guardar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        expect(find.byType(SaleDialog), findsNothing);
        expect(await productStock(), 0); // 3 + 2 devueltos - 5 nuevos
        final items = await SaleRepository(db).getItemsForSale(sale.id);
        expect(items.single.quantity, 5);
      },
    );

    testWidgets(
      'a NEW sale is still capped at the plain current stock',
      (tester) async {
        useTallScreen(tester);
        await tester.pumpWidget(
          app(
            Scaffold(
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
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Stock: 5'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.add)); // agrega al carrito (1)
        await tester.pumpAndSettle();
        // Ahora el "+" del carrito: ya no hay ícono "+" del catálogo (marcado).
        final plus = find.byIcon(Icons.add);
        for (var i = 0; i < 8; i++) {
          await tester.ensureVisible(plus);
          await tester.tap(plus);
          await tester.pumpAndSettle();
        }
        expect(find.text('5'), findsOneWidget);
        expect(find.text('6'), findsNothing);
      },
    );
  });

  group('canceling a sale from the list', () {
    testWidgets(
      'confirming returns the stock, and the sale stays listed as "Cancelada" '
      'with no edit/cancel actions',
      (tester) async {
        useTallScreen(tester);
        await seedSaleOfTwo();
        expect(await productStock(), 3);

        await tester.pumpWidget(app(const SalesPage()));
        await tester.pumpAndSettle();

        expect(find.text('Cancelada'), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

        await tester.tap(find.byIcon(Icons.cancel_outlined));
        await tester.pumpAndSettle();
        expect(find.text('¿Cancelar venta?'), findsOneWidget);
        await tester.tap(find.text('Cancelar venta'));
        await tester.pumpAndSettle();

        expect(await productStock(), 5); // lo vendido volvió al inventario
        expect(find.text('Cancelada'), findsOneWidget);
        // La venta sigue en la lista, pero ya no se puede editar ni cancelar.
        expect(find.text('Sin nombre'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.cancel_outlined), findsNothing);

        final sale = (await SaleRepository(db).getAll()).single;
        expect(sale.isCanceled, isTrue);
      },
    );

    testWidgets('choosing "Volver" leaves the sale and the stock untouched', (
      tester,
    ) async {
      useTallScreen(tester);
      await seedSaleOfTwo();

      await tester.pumpWidget(app(const SalesPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.cancel_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(await productStock(), 3);
      expect(find.text('Cancelada'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect((await SaleRepository(db).getAll()).single.isCanceled, isFalse);
    });
  });

  group('canceling a material usage record from the usage tab', () {
    testWidgets(
      'confirming returns the material stock and keeps the record listed as '
      '"Cancelado" with no actions',
      (tester) async {
        useTallScreen(tester);
        final unit = await (db.select(
          db.units,
        )..where((u) => u.name.equals('metro'))).getSingle();
        await db.into(db.materials).insert(
          MaterialsCompanion.insert(
            name: 'Cinta',
            unitId: unit.id,
            pricePerUnit: 2,
            stock: const Value(10),
          ),
        );
        await MaterialRepository(db).registerMaterialUsage(
          productId: 1,
          materialId: 1,
          quantityUsed: 4,
        );
        Future<double> materialStock() async => (await db.select(db.materials).getSingle()).stock;
        expect(await materialStock(), 6);

        await tester.pumpWidget(app(const Scaffold(body: MaterialsUsageTab())));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Selecciona un producto'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Collar').last);
        await tester.pumpAndSettle();

        expect(find.text('Cinta'), findsOneWidget);
        expect(find.text('Cancelado'), findsNothing);

        await tester.tap(find.byIcon(Icons.cancel_outlined));
        await tester.pumpAndSettle();
        expect(find.text('¿Cancelar registro de uso?'), findsOneWidget);
        await tester.tap(find.text('Cancelar registro'));
        await tester.pumpAndSettle();

        expect(await materialStock(), 10); // los 4 metros volvieron
        expect(find.text('Cinta'), findsOneWidget); // sigue en la lista
        expect(find.text('Cancelado'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.cancel_outlined), findsNothing);
      },
    );
  });
}
