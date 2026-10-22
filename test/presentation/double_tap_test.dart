import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/config/date_formatters.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/client_repository.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/models/client_model.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/category_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/client_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/event_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/location_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/material_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/product_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/supplier_dialog.dart';
import 'package:offline_first_bi/presentation/pages/materials_page.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'form_finders.dart';
import 'search_helpers.dart';

const _tables = [
  'categories',
  'clients',
  'suppliers',
  'locations',
  'events',
  'products',
  'materials',
  'sales',
  'sale_items',
  'purchases',
  'purchase_items',
  'product_materials',
];

Future<void> _installWriteLog(AppDatabase db) async {
  await db.customStatement('CREATE TABLE write_log (tbl TEXT, op TEXT)');
  for (final table in _tables) {
    for (final op in ['INSERT', 'UPDATE']) {
      await db.customStatement(
        'CREATE TRIGGER log_${table}_${op.toLowerCase()} AFTER $op ON $table '
        "BEGIN INSERT INTO write_log VALUES ('$table', '$op'); END",
      );
    }
  }
}

Future<void> _clearWriteLog(AppDatabase db) =>
    db.customStatement('DELETE FROM write_log');

String _us(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

void main() {
  late AppDatabase db;

  Future<int> writes(String table, String op) async {
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM write_log WHERE tbl = ? AND op = ?',
          variables: [Variable.withString(table), Variable.withString(op)],
        )
        .get();
    return rows.single.read<int>('n');
  }

  Future<int> rows(String table) async {
    final result = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .get();
    return result.single.read<int>('n');
  }

  Future<int> productStock() async => (await (db.select(
    db.products,
  )..where((p) => p.name.equals('Libro'))).getSingle()).stock;

  Future<double> materialStock() async => (await (db.select(
    db.materials,
  )..where((m) => m.name.equals('Tela'))).getSingle()).stock;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final unit = await (db.select(
      db.units,
    )..where((u) => u.name.equals('unidad'))).getSingle();
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Libro',
        priceA: 20,
        priceB: 20,
        stock: const Value(50),
      ),
    );
    await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Tela',
        unitId: unit.id,
        pricePerUnit: 4,
        stock: const Value(100),
      ),
    );
    await _installWriteLog(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openWidget(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: lightTheme, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester, Widget sheet) async {
    await openWidget(
      tester,
      Scaffold(
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
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> doubleTap(
    WidgetTester tester,
    Finder finder, {
    Duration gap = Duration.zero,
  }) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    final point = tester.getCenter(finder);
    await tester.tapAt(point);
    if (gap > Duration.zero) await tester.pump(gap);
    await tester.tapAt(point);
    await tester.pumpAndSettle();
  }

  Finder button(String label) => find.widgetWithText(ElevatedButton, label);

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(ElevatedButton, label),
  );

  Future<void> type(WidgetTester tester, String label, String text) async {
    final field = fieldLabeled(label);
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  Future<void> addProductToCart(WidgetTester tester) async {
    await searchProducts(tester, 'Libro');
    await tester.tap(find.byIcon(Icons.add_circle_rounded));
    await tester.pumpAndSettle();
  }

  Future<void> addMaterialLine(WidgetTester tester) async {
    await tester.ensureVisible(materialsAddButton());
    await tester.tap(materialsAddButton());
    await tester.pumpAndSettle();
    await pickFromSearch(
      tester,
      find.byType(SearchablePickerField<int>).last,
      'Tela',
      'Tela',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '0').first, '3');
    await tester.pumpAndSettle();
  }

  Future<void> seedSale() async {
    await SaleRepository(db).createSale(
      clientId: null,
      locationId: null,
      eventId: null,
      totalAmount: 40,
      discount: 0,
      finalAmount: 40,
      date: DateTime(2024, 1, 1),
      items: [
        {'productId': 1, 'quantity': 2, 'unitPrice': 20.0, 'priceType': 'A'},
      ],
    );
    await _clearWriteLog(db);
  }

  Future<void> seedPurchase() async {
    await PurchaseRepository(db).createPurchase(
      supplierId: null,
      isMaterial: true,
      description: null,
      totalAmount: 12,
      date: DateTime(2024, 1, 1),
      locationId: null,
      eventId: null,
      items: [
        {'materialId': 1, 'quantity': 3.0, 'unitPrice': 4.0},
      ],
    );
    await _clearWriteLog(db);
  }

  group('creation forms: Crear twice creates exactly one record', () {
    testWidgets('categoría', (tester) async {
      await openSheet(tester, const CategoryDialog());
      final before = await rows('categories');
      await type(tester, 'Nombre', 'Pinturas');
      await doubleTap(tester, button('Crear'));

      expect(await rows('categories'), before + 1);
      expect(await writes('categories', 'INSERT'), 1);
      expect(find.byType(CategoryDialog), findsNothing);
    });

    testWidgets('producto', (tester) async {
      await openSheet(tester, const ProductDialog());
      final before = await rows('products');
      await type(tester, 'Nombre', 'Cuadro');
      await type(tester, 'Precio A', '55');
      await type(tester, 'Stock', '4');
      await doubleTap(tester, button('Crear'));

      expect(await rows('products'), before + 1);
      expect(await writes('products', 'INSERT'), 1);
      expect(find.byType(ProductDialog), findsNothing);
      expect(find.textContaining('Ya existe'), findsNothing);
    });

    testWidgets('material', (tester) async {
      await openSheet(tester, const MaterialDialog());
      final before = await rows('materials');
      await type(tester, 'Nombre', 'Hilo');
      await tester.tap(find.byTooltip('Unidad'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<int>, 'unidad'),
      );
      await tester.pumpAndSettle();
      await type(tester, 'Stock', '3');
      await type(tester, 'Precio por unidad', '4');
      await doubleTap(tester, button('Crear'));

      expect(await rows('materials'), before + 1);
      expect(await writes('materials', 'INSERT'), 1);
      expect(find.byType(MaterialDialog), findsNothing);
    });

    testWidgets('cliente', (tester) async {
      await openSheet(tester, const ClientDialog());
      final before = await rows('clients');
      await type(tester, 'Nombre', 'Ana');
      await doubleTap(tester, button('Crear'));

      expect(await rows('clients'), before + 1);
      expect(await writes('clients', 'INSERT'), 1);
      expect(find.textContaining('Ya existe'), findsNothing);
    });

    testWidgets('proveedor', (tester) async {
      await openSheet(tester, const SupplierDialog());
      final before = await rows('suppliers');
      await type(tester, 'Nombre', 'Papelera');
      await doubleTap(tester, button('Crear'));

      expect(await rows('suppliers'), before + 1);
      expect(await writes('suppliers', 'INSERT'), 1);
      expect(find.textContaining('Ya existe'), findsNothing);
    });

    testWidgets('ubicación', (tester) async {
      await openSheet(tester, const LocationDialog());
      final before = await rows('locations');
      await type(tester, 'Ciudad', 'Oruro');
      await type(tester, 'País', 'Bolivia');
      await doubleTap(tester, button('Crear'));

      expect(await rows('locations'), before + 1);
      expect(await writes('locations', 'INSERT'), 1);
      expect(find.textContaining('Ya existe'), findsNothing);
    });

    testWidgets('evento', (tester) async {
      await openSheet(tester, const EventDialog());
      final before = await rows('events');
      await type(tester, 'Nombre del evento', 'Feria');
      await tester.ensureVisible(find.text('Seleccionar fecha').first);
      await tester.tap(find.text('Seleccionar fecha').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.edit_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        _us(DateTime(2026, 3, 5)),
      );
      await tester.pump();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(find.text(formatDate(DateTime(2026, 3, 5))), findsOneWidget);
      await doubleTap(tester, button('Crear'));

      expect(await rows('events'), before + 1);
      expect(await writes('events', 'INSERT'), 1);
    });
  });

  group('the handler itself ignores a second call', () {
    testWidgets('a form action fired twice in the same frame runs once', (
      tester,
    ) async {
      await openSheet(tester, const ClientDialog());
      await type(tester, 'Nombre', 'Ana');
      final before = await rows('clients');
      final onPressed = tester.widget<ElevatedButton>(button('Crear')).onPressed!;
      onPressed();
      onPressed();
      await tester.pumpAndSettle();

      expect(await rows('clients'), before + 1);
      expect(await writes('clients', 'INSERT'), 1);
    });

    testWidgets('a sale action fired twice in the same frame runs once', (
      tester,
    ) async {
      await openSheet(tester, const SaleDialog());
      await addProductToCart(tester);
      final onPressed = tester
          .widget<ElevatedButton>(button('Registrar venta'))
          .onPressed!;
      onPressed();
      onPressed();
      await tester.pumpAndSettle();

      expect(await rows('sales'), 1);
      expect(await productStock(), 49);
    });
  });

  group('sales', () {
    testWidgets('Registrar venta twice records one sale and one stock change', (
      tester,
    ) async {
      await openSheet(tester, const SaleDialog());
      await addProductToCart(tester);
      await doubleTap(tester, button('Registrar venta'));

      expect(await rows('sales'), 1);
      expect(await rows('sale_items'), 1);
      expect(await writes('sales', 'INSERT'), 1);
      expect(await productStock(), 49);
      expect(find.byType(SaleDialog), findsNothing);
    });

    testWidgets('Registrar venta twice with a short gap is still one sale', (
      tester,
    ) async {
      await openSheet(tester, const SaleDialog());
      await addProductToCart(tester);
      await doubleTap(
        tester,
        button('Registrar venta'),
        gap: const Duration(milliseconds: 40),
      );

      expect(await rows('sales'), 1);
      expect(await productStock(), 49);
    });

    testWidgets('Guardar twice on an edited sale applies the edit once', (
      tester,
    ) async {
      await seedSale();
      final sale = (await SaleRepository(db).getAll()).single;
      await openSheet(tester, SaleDialog(sale: sale));
      expect(await productStock(), 48);
      await tester.ensureVisible(find.byTooltip('Agregar uno'));
      await tester.tap(find.byTooltip('Agregar uno'));
      await tester.pumpAndSettle();
      await _clearWriteLog(db);
      await doubleTap(tester, button('Guardar'));

      expect(await writes('sales', 'UPDATE'), 1);
      expect(await rows('sales'), 1);
      expect(await rows('sale_items'), 1);
      expect(await productStock(), 47);
      expect(find.byType(SaleDialog), findsNothing);
    });

    testWidgets('Cancelar la venta twice returns the stock once', (
      tester,
    ) async {
      await seedSale();
      final sale = (await SaleRepository(db).getAll()).single;
      await openSheet(tester, SaleDialog(sale: sale));
      await doubleTap(tester, button('Cancelar la venta'));
      expect(find.byType(AlertDialog), findsOneWidget);

      await doubleTap(tester, dialogButton('Cancelar la venta'));

      expect(await productStock(), 50);
      expect(await writes('sales', 'UPDATE'), 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SaleDialog), findsNothing);
    });

    testWidgets('the cancel repository call is safe when reached twice', (
      tester,
    ) async {
      await seedSale();
      final repository = SaleRepository(db);
      final id = (await repository.getAll()).single.id;
      final first = repository.cancelSale(id);
      final second = repository.cancelSale(id);
      expect(await first, isNull);
      expect(await second, isNotNull);
      expect(await productStock(), 50);
    });
  });

  group('purchases', () {
    testWidgets('Registrar compra of materials twice creates one purchase', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog());
      await addMaterialLine(tester);
      await doubleTap(tester, button('Agregar'));
      expect(find.text('Agregar material'), findsNothing);
      expect(find.text('Quitar material'), findsNothing);
      expect(find.byTooltip('Quitar material'), findsOneWidget);

      await doubleTap(tester, button('Registrar compra'));

      expect(await rows('purchases'), 1);
      expect(await rows('purchase_items'), 1);
      expect(await writes('purchases', 'INSERT'), 1);
      expect(await materialStock(), 103);
      expect(find.byType(PurchaseDialog), findsNothing);
    });

    testWidgets('Registrar compra as a general expense twice creates one', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog());
      await tester.tap(find.text('Gasto general'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción del gasto'),
        'Transporte',
      );
      await tester.enterText(find.byKey(const ValueKey('purchase-total-expense')), '15');
      await tester.pumpAndSettle();
      await doubleTap(tester, button('Registrar compra'));

      expect(await rows('purchases'), 1);
      expect(await writes('purchases', 'INSERT'), 1);
      expect(await materialStock(), 100);
    });

    testWidgets('Guardar twice on an edited purchase applies the edit once', (
      tester,
    ) async {
      await seedPurchase();
      final purchase = (await PurchaseRepository(db).getAll()).single;
      await openSheet(tester, PurchaseDialog(purchase: purchase));
      expect(await materialStock(), 103);
      await tester.ensureVisible(find.byTooltip('Agregar uno'));
      await tester.tap(find.byTooltip('Agregar uno'));
      await tester.pumpAndSettle();
      await _clearWriteLog(db);
      await doubleTap(tester, button('Guardar'));

      expect(await writes('purchases', 'UPDATE'), 1);
      expect(await rows('purchase_items'), 1);
      expect(await materialStock(), 104);
      expect(find.byType(PurchaseDialog), findsNothing);
    });

    testWidgets('Cancelar la compra twice returns the stock once', (
      tester,
    ) async {
      await seedPurchase();
      final purchase = (await PurchaseRepository(db).getAll()).single;
      await openSheet(tester, PurchaseDialog(purchase: purchase));
      await doubleTap(tester, button('Cancelar la compra'));
      expect(find.byType(AlertDialog), findsOneWidget);

      await doubleTap(tester, dialogButton('Cancelar la compra'));

      expect(await materialStock(), 100);
      expect(await writes('purchases', 'UPDATE'), 1);
      expect(find.byType(PurchaseDialog), findsNothing);
    });

    testWidgets('the cancel repository call is safe when reached twice', (
      tester,
    ) async {
      await seedPurchase();
      final repository = PurchaseRepository(db);
      final id = (await repository.getAll()).single.id;
      final first = repository.cancelPurchase(id);
      final second = repository.cancelPurchase(id);
      expect(await first, isNull);
      expect(await second, isNotNull);
      expect(await materialStock(), 100);
    });
  });

  group('material usage', () {
    Future<void> openUsageTab(WidgetTester tester) async {
      await openWidget(tester, const Scaffold(body: MaterialsUsageTab()));
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).first,
        'Libro',
        'Libro',
      );
    }

    Future<void> openRegisterSheet(WidgetTester tester) async {
      await openUsageTab(tester);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        'Tela',
        'Tela',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '0').first, '3');
      await tester.pumpAndSettle();
    }

    Future<void> seedUsage() async {
      await MaterialRepository(db).registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 3,
      );
      await _clearWriteLog(db);
    }

    Future<void> openEditSheet(WidgetTester tester) async {
      await openUsageTab(tester);
      await tester.tap(find.textContaining('3 unidades'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
    }

    testWidgets('Registrar twice registers one usage and one stock change', (
      tester,
    ) async {
      await openRegisterSheet(tester);
      await doubleTap(tester, button('Registrar'));

      expect(await rows('product_materials'), 1);
      expect(await writes('product_materials', 'INSERT'), 1);
      expect(await materialStock(), 97);
      expect(find.text('Registrar uso de material'), findsNothing);
    });

    testWidgets('Guardar twice on an edited usage changes the stock once', (
      tester,
    ) async {
      await seedUsage();
      expect(await materialStock(), 97);
      await openEditSheet(tester);
      final field = find.byType(TextFormField).first;
      await tester.enterText(field, '5');
      await tester.pumpAndSettle();
      await _clearWriteLog(db);
      await doubleTap(tester, button('Guardar'));

      expect(await writes('product_materials', 'UPDATE'), 1);
      expect(await materialStock(), 95);
    });

    testWidgets('Cancelar el registro de uso twice returns the stock once', (
      tester,
    ) async {
      await seedUsage();
      await openEditSheet(tester);
      await doubleTap(tester, button('Cancelar el registro de uso'));
      expect(find.byType(AlertDialog), findsOneWidget);

      await doubleTap(tester, dialogButton('Cancelar el registro de uso'));

      expect(await materialStock(), 100);
      expect(await writes('product_materials', 'UPDATE'), 1);
    });

    testWidgets('the usage repository calls are safe when reached twice', (
      tester,
    ) async {
      final repository = MaterialRepository(db);
      final results = await Future.wait([
        repository.registerMaterialUsage(
          productId: 1,
          materialId: 1,
          quantityUsed: 2,
        ),
        repository.registerMaterialUsage(
          productId: 1,
          materialId: 1,
          quantityUsed: 2,
        ),
      ]);
      expect(results, [null, null]);
      expect(await rows('product_materials'), 1);
      expect(await materialStock(), 96);

      final record = (await db.select(db.productMaterials).get()).single;
      final cancels = await Future.wait([
        repository.cancelMaterialUsage(record.id),
        repository.cancelMaterialUsage(record.id),
      ]);
      expect(cancels.where((e) => e == null), hasLength(1));
      expect(await materialStock(), 100);
    });
  });

  group('creation forms opened from another form', () {
    testWidgets('Nuevo cliente over Nueva venta', (tester) async {
      await openSheet(tester, const SaleDialog());
      final before = await rows('clients');
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();
      await type(tester, 'Nombre', 'Cliente doble');
      await doubleTap(tester, button('Crear'));

      expect(await rows('clients'), before + 1);
      expect(find.byType(SaleDialog), findsOneWidget);
      expect(find.byType(ClientDialog), findsNothing);
    });

    testWidgets('Nuevo proveedor over Nueva compra', (tester) async {
      await openSheet(tester, const PurchaseDialog());
      final before = await rows('suppliers');
      await tester.tap(find.text('Nuevo proveedor'));
      await tester.pumpAndSettle();
      await type(tester, 'Nombre', 'Proveedor doble');
      await doubleTap(tester, button('Crear'));

      expect(await rows('suppliers'), before + 1);
      expect(find.byType(PurchaseDialog), findsOneWidget);
      expect(find.byType(SupplierDialog), findsNothing);
    });

    testWidgets('Nueva ubicación over Nuevo evento', (tester) async {
      await openSheet(tester, const EventDialog());
      final before = await rows('locations');
      await tester.tap(find.text('Nueva ubicación'));
      await tester.pumpAndSettle();
      await type(tester, 'Ciudad', 'Sucre');
      await type(tester, 'País', 'Bolivia');
      await doubleTap(tester, button('Crear').last);

      expect(await rows('locations'), before + 1);
      expect(find.byType(EventDialog), findsOneWidget);
      expect(find.byType(LocationDialog), findsNothing);
    });

    testWidgets(
      'Nuevo material over Agregar material over Nueva compra creates one '
      'material and keeps the two forms below open',
      (tester) async {
        await openSheet(tester, const PurchaseDialog());
        final before = await rows('materials');
        await tester.ensureVisible(materialsAddButton());
        await tester.tap(materialsAddButton());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nuevo material'));
        await tester.pumpAndSettle();
        await type(tester, 'Nombre', 'Hilo doble');
        await tester.tap(find.byTooltip('Unidad'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<int>, 'unidad'),
        );
        await tester.pumpAndSettle();
        await type(tester, 'Stock', '3');
        await type(tester, 'Precio por unidad', '4');
        await doubleTap(tester, button('Crear').last);

        expect(await rows('materials'), before + 1);
        expect(await writes('materials', 'INSERT'), 1);
        expect(find.byType(MaterialDialog), findsNothing);
        expect(find.text('Agregar material'), findsOneWidget);
        expect(find.text('Nueva compra'), findsOneWidget);
      },
    );

    testWidgets('Agregar over Agregar material adds one line', (tester) async {
      await openSheet(tester, const PurchaseDialog());
      await addMaterialLine(tester);
      await doubleTap(tester, button('Agregar'));

      expect(find.byTooltip('Quitar material'), findsOneWidget);
      expect(find.text('Nueva compra'), findsOneWidget);
    });
  });

  group('activation confirmations', () {
    Future<ClientModel> client(String name, {bool active = true}) async {
      final repository = ClientRepository(db);
      await repository.save(name: name, isActive: active);
      return (await repository.getAllIncludingInactive()).firstWhere(
        (c) => c.name == name,
      );
    }

    testWidgets('Desactivar twice only closes the confirmation', (
      tester,
    ) async {
      await openSheet(tester, ClientDialog(client: await client('Luis')));
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await doubleTap(tester, dialogButton('Desactivar'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ClientDialog), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('the confirmation answers once when its button fires twice', (
      tester,
    ) async {
      await openSheet(tester, ClientDialog(client: await client('Pablo')));
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final onPressed = tester
          .widget<ElevatedButton>(dialogButton('Desactivar'))
          .onPressed!;
      onPressed();
      onPressed();
      await tester.pumpAndSettle();

      expect(find.byType(ClientDialog), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('Activar twice only closes the confirmation', (tester) async {
      await openSheet(
        tester,
        ClientDialog(client: await client('Marta', active: false)),
      );
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await doubleTap(tester, dialogButton('Activar'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ClientDialog), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });
  });
}
