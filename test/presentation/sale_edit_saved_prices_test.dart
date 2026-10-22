import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/models/sale_model.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'search_helpers.dart';

void main() {
  late AppDatabase db;
  late int cuadro;
  late int marco;

  Finder bs(String amount) => find.text('Bs. $amount');

  Future<int> stockOf(int id) async => (await (db.select(
    db.products,
  )..where((p) => p.id.equals(id))).getSingle()).stock;

  Future<SaleModel> seedSale({
    required List<(int, int, double, String)> lines,
    double discount = 0,
  }) async {
    final repository = SaleRepository(db);
    final subtotal = lines.fold<double>(0, (t, l) => t + l.$2 * l.$3);
    await repository.createSale(
      clientId: 1,
      locationId: null,
      eventId: null,
      totalAmount: subtotal,
      discount: discount,
      finalAmount: subtotal - discount,
      date: DateTime(2024, 1, 1),
      items: [
        for (final l in lines)
          {
            'productId': l.$1,
            'quantity': l.$2,
            'unitPrice': l.$3,
            'priceType': l.$4,
          },
      ],
    );
    return (await repository.getAll()).single;
  }

  Future<void> setPrices(int id, {double? a, double? b}) async {
    await (db.update(db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        priceA: a == null ? const Value.absent() : Value(a),
        priceB: b == null ? const Value.absent() : Value(b),
      ),
    );
  }

  Future<void> openEdit(WidgetTester tester, SaleModel sale) async {
    tester.view.physicalSize = const Size(412, 1400);
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
                  builder: (_) => SaleDialog(sale: sale),
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

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
  }

  Future<List<SaleItem>> savedItems(int saleId) => (db.select(db.saleItems)
        ..where((i) => i.saleId.equals(saleId))
        ..orderBy([(i) => OrderingTerm.asc(i.productId)]))
      .get();

  Future<Sale> savedSale(int id) =>
      (db.select(db.sales)..where((s) => s.id.equals(id))).getSingle();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cuadro = await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Cuadro',
        priceA: 20,
        priceB: 25,
        stock: const Value(10),
      ),
    );
    marco = await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Marco',
        priceA: 10,
        priceB: 12,
        stock: const Value(10),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('editing a sale keeps the prices it was sold at', () {
    testWidgets('saving without changes keeps unit price, type and totals', (
      tester,
    ) async {
      final sale = await seedSale(
        lines: [(cuadro, 2, 25.0, 'B')],
        discount: 5,
      );
      expect(await stockOf(cuadro), 8);
      await setPrices(cuadro, b: 18);

      await openEdit(tester, sale);
      expect(bs('50.00'), findsWidgets);
      expect(bs('36.00'), findsNothing);

      await save(tester);

      final items = await savedItems(sale.id);
      expect(items.single.unitPrice, 25);
      expect(items.single.priceType, 'B');
      expect(items.single.subtotal, 50);
      final stored = await savedSale(sale.id);
      expect(stored.totalAmount, 50);
      expect(stored.finalAmount, 45);
      expect(await stockOf(cuadro), 8);
    });

    testWidgets('changing the quantity keeps the saved unit price', (
      tester,
    ) async {
      final sale = await seedSale(
        lines: [(cuadro, 2, 25.0, 'B')],
        discount: 5,
      );
      await setPrices(cuadro, b: 18);

      await openEdit(tester, sale);
      await tester.tap(find.byTooltip('Agregar uno'));
      await tester.pumpAndSettle();
      expect(bs('75.00'), findsWidgets);

      await save(tester);

      final items = await savedItems(sale.id);
      expect(items.single.quantity, 3);
      expect(items.single.unitPrice, 25);
      expect(items.single.subtotal, 75);
      final stored = await savedSale(sale.id);
      expect(stored.totalAmount, 75);
      expect(stored.finalAmount, 70);
      expect(await stockOf(cuadro), 7);
    });

    testWidgets(
      'switching the price type uses the current price, switching back '
      'restores the saved one',
      (tester) async {
        final sale = await seedSale(lines: [(cuadro, 2, 25.0, 'B')]);
        await setPrices(cuadro, a: 22, b: 18);

        await openEdit(tester, sale);
        expect(bs('50.00'), findsWidgets);

        await tester.tap(find.text('Precio A'));
        await tester.pumpAndSettle();
        expect(bs('44.00'), findsWidgets);
        expect(bs('50.00'), findsNothing);

        await tester.tap(find.text('Precio B'));
        await tester.pumpAndSettle();
        expect(bs('50.00'), findsWidgets);
        expect(bs('36.00'), findsNothing);

        await tester.tap(find.text('Precio A'));
        await tester.pumpAndSettle();
        await save(tester);

        final items = await savedItems(sale.id);
        expect(items.single.priceType, 'A');
        expect(items.single.unitPrice, 22);
        expect(items.single.subtotal, 44);
      },
    );

    testWidgets('a product added while editing uses its current price', (
      tester,
    ) async {
      final sale = await seedSale(lines: [(cuadro, 2, 25.0, 'B')]);
      await setPrices(cuadro, b: 18);

      await openEdit(tester, sale);
      await searchProducts(tester, 'Marco');
      await tester.tap(find.byIcon(Icons.add_circle_rounded));
      await tester.pumpAndSettle();
      expect(bs('60.00'), findsWidgets);

      await save(tester);

      final items = await savedItems(sale.id);
      expect(items.length, 2);
      final saved = {for (final i in items) i.productId: i};
      expect(saved[cuadro]!.unitPrice, 25);
      expect(saved[marco]!.unitPrice, 10);
      expect(saved[marco]!.priceType, 'A');
      expect((await savedSale(sale.id)).totalAmount, 60);
      expect(await stockOf(marco), 9);
    });

    testWidgets('a removed line that is added again takes the current price', (
      tester,
    ) async {
      final sale = await seedSale(lines: [(cuadro, 1, 25.0, 'B')]);
      await setPrices(cuadro, a: 22, b: 18);

      await openEdit(tester, sale);
      await tester.tap(find.byTooltip('Quitar uno'));
      await tester.pumpAndSettle();
      await searchProducts(tester, 'Cuadro');
      await tester.tap(find.byIcon(Icons.add_circle_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Precio B'));
      await tester.pumpAndSettle();
      await save(tester);

      final items = await savedItems(sale.id);
      expect(items.single.unitPrice, 18);
    });
  });

  group('editing a sale with a product that is now inactive', () {
    Future<SaleModel> seedAndDeactivate() async {
      final sale = await seedSale(
        lines: [(cuadro, 1, 25.0, 'B'), (marco, 2, 12.0, 'B')],
      );
      await (db.update(db.products)..where((p) => p.id.equals(marco))).write(
        const ProductsCompanion(isActive: Value(false)),
      );
      return sale;
    }

    testWidgets('shows every line, labels the inactive one and the subtotal '
        'matches the visible lines', (tester) async {
      final sale = await seedAndDeactivate();

      await openEdit(tester, sale);

      expect(find.text('Cuadro'), findsOneWidget);
      expect(find.text('Marco'), findsOneWidget);
      expect(find.text('Inactivo'), findsOneWidget);
      expect(bs('25.00'), findsWidgets);
      expect(bs('24.00'), findsWidgets);
      expect(bs('49.00'), findsWidgets);
      expect(find.byTooltip('Quitar uno'), findsNWidgets(2));
      expect(find.text('Precio A'), findsNWidgets(2));
    });

    testWidgets('the inactive line can be removed and its stock returns', (
      tester,
    ) async {
      final sale = await seedAndDeactivate();
      expect(await stockOf(marco), 8);

      await openEdit(tester, sale);
      await tester.tap(find.byTooltip('Quitar uno').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar uno').last);
      await tester.pumpAndSettle();
      expect(find.text('Marco'), findsNothing);
      expect(find.text('Inactivo'), findsNothing);
      expect(bs('25.00'), findsWidgets);

      await save(tester);

      final items = await savedItems(sale.id);
      expect(items.single.productId, cuadro);
      expect((await savedSale(sale.id)).totalAmount, 25);
      expect(await stockOf(marco), 10);
    });

    testWidgets('the product search does not offer inactive products', (
      tester,
    ) async {
      final sale = await seedAndDeactivate();

      await openEdit(tester, sale);
      await searchProducts(tester, 'Marco');

      expect(find.textContaining('Stock:'), findsNothing);
      expect(find.byIcon(Icons.add_circle_rounded), findsNothing);
    });
  });
}
