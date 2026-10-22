import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

void main() {
  late AppDatabase db;
  late PurchaseRepository purchases;
  late int unitId;
  late int tela;
  late int hilo;
  late int product;

  Future<double> stockOf(int id) async => (await (db.select(
    db.materials,
  )..where((m) => m.id.equals(id))).getSingle()).stock;

  Future<double> priceOf(int id) async => (await (db.select(
    db.materials,
  )..where((m) => m.id.equals(id))).getSingle()).pricePerUnit;

  Future<List<PurchaseItem>> linesOf(int purchaseId) => (db.select(
    db.purchaseItems,
  )..where((i) => i.purchaseId.equals(purchaseId))).get();

  Future<Purchase> purchaseRow(int id) =>
      (db.select(db.purchases)..where((p) => p.id.equals(id))).getSingle();

  Map<String, dynamic> line(int materialId, double quantity, double price) => {
    'materialId': materialId,
    'quantity': quantity,
    'unitPrice': price,
  };

  Future<String?> edit(
    int purchaseId,
    List<Map<String, dynamic>> items, {
    bool isMaterial = true,
    double total = 10,
    String? description,
  }) => purchases.editPurchase(
    purchaseId: purchaseId,
    supplierId: null,
    isMaterial: isMaterial,
    description: description,
    totalAmount: total,
    date: DateTime(2024, 1, 1),
    locationId: null,
    eventId: null,
    newItems: items,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    purchases = PurchaseRepository(db);
    unitId = (await (db.select(
      db.units,
    )..where((u) => u.name.equals('unidad'))).getSingle()).id;
    tela = await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Tela',
        unitId: unitId,
        pricePerUnit: 2,
        stock: const Value(0),
      ),
    );
    hilo = await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Hilo',
        unitId: unitId,
        pricePerUnit: 3,
        stock: const Value(10),
      ),
    );
    product = await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Cuadro',
        priceA: 20,
        priceB: 20,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> purchaseOfFiveWithFourUsed() async {
    await purchases.createPurchase(
      supplierId: null,
      isMaterial: true,
      description: null,
      totalAmount: 10,
      date: DateTime(2024, 1, 1),
      locationId: null,
      eventId: null,
      items: [line(tela, 5, 2)],
    );
    final id = (await purchases.getAll()).single.id;
    expect(
      await MaterialRepository(
        db,
      ).registerMaterialUsage(productId: product, materialId: tela, quantityUsed: 4),
      isNull,
    );
    expect(await stockOf(tela), 1);
    return id;
  }

  group('editing a purchase never leaves a material with negative stock', () {
    test('removing the line is rejected and nothing changes', () async {
      final id = await purchaseOfFiveWithFourUsed();

      final error = await edit(id, [line(hilo, 1, 3)]);

      expect(error, PurchaseRepository.editBlockedMessage);
      expect(await stockOf(tela), 1);
      expect(await stockOf(hilo), 10);
      final lines = await linesOf(id);
      expect(lines.single.materialId, tela);
      expect(lines.single.quantity, 5);
      expect((await purchaseRow(id)).totalAmount, 10);
    });

    test('reducing the line below what was already used is rejected', () async {
      final id = await purchaseOfFiveWithFourUsed();

      final error = await edit(id, [line(tela, 1, 2)], total: 2);

      expect(error, PurchaseRepository.editBlockedMessage);
      expect(await stockOf(tela), 1);
      final lines = await linesOf(id);
      expect(lines.single.quantity, 5);
      expect((await purchaseRow(id)).totalAmount, 10);
    });

    test('switching to a general expense is rejected', () async {
      final id = await purchaseOfFiveWithFourUsed();

      final error = await edit(
        id,
        const [],
        isMaterial: false,
        description: 'Transporte',
      );

      expect(error, PurchaseRepository.editBlockedMessage);
      expect(await stockOf(tela), 1);
      expect((await linesOf(id)).single.quantity, 5);
      final row = await purchaseRow(id);
      expect(row.isMaterial, isTrue);
      expect(row.description, isNull);
    });

    test('a rejected edit does not touch the material price', () async {
      final id = await purchaseOfFiveWithFourUsed();
      final before = await priceOf(tela);

      await edit(id, [line(tela, 1, 9)], total: 9);

      expect(await priceOf(tela), before);
    });

    test('allowed edits still work', () async {
      final id = await purchaseOfFiveWithFourUsed();

      expect(await edit(id, [line(tela, 8, 2)], total: 16), isNull);
      expect(await stockOf(tela), 4);

      expect(await edit(id, [line(tela, 5, 2)], total: 10), isNull);
      expect(await stockOf(tela), 1);

      expect(await edit(id, [line(tela, 4, 2)], total: 8), isNull);
      expect(await stockOf(tela), 0);
      expect((await linesOf(id)).single.quantity, 4);
    });

    test('swapping to another material with enough stock is allowed when '
        'the first keeps enough', () async {
      await purchases.createPurchase(
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 10,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: [line(tela, 5, 2)],
      );
      final id = (await purchases.getAll()).single.id;

      expect(await edit(id, [line(hilo, 3, 3)], total: 9), isNull);

      expect(await stockOf(tela), 0);
      expect(await stockOf(hilo), 13);
      expect((await linesOf(id)).single.materialId, hilo);
    });

    test('switching an unused purchase to a general expense is allowed', () async {
      await purchases.createPurchase(
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 10,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: [line(tela, 5, 2)],
      );
      final id = (await purchases.getAll()).single.id;

      final error = await edit(
        id,
        const [],
        isMaterial: false,
        description: 'Transporte',
      );

      expect(error, isNull);
      expect(await stockOf(tela), 0);
      expect(await linesOf(id), isEmpty);
    });

    test('cancelling stays blocked exactly as before', () async {
      final id = await purchaseOfFiveWithFourUsed();

      expect(
        await purchases.cancelPurchase(id),
        PurchaseRepository.cancelBlockedMessage,
      );
      expect(await stockOf(tela), 1);
    });

    testWidgets('the form stays open and shows the message', (tester) async {
      tester.view.physicalSize = const Size(412, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final id = await purchaseOfFiveWithFourUsed();
      final model = (await purchases.getAll()).firstWhere((p) => p.id == id);

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
                    builder: (_) => PurchaseDialog(purchase: model),
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

      await tester.tap(find.byTooltip('Quitar material'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasto general'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('purchase-description')),
        'Transporte',
      );
      await tester.enterText(
        find.byKey(const ValueKey('purchase-total-expense')),
        '10',
      );
      await tester.ensureVisible(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text(PurchaseRepository.editBlockedMessage), findsOneWidget);
      expect(find.byType(PurchaseDialog), findsOneWidget);
      expect(await stockOf(tela), 1);
      expect((await linesOf(id)).single.quantity, 5);
    });
  });
}
