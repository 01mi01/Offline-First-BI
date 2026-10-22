import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/category_repository.dart';
import 'package:offline_first_bi/data/repositories/client_repository.dart';
import 'package:offline_first_bi/data/repositories/event_repository.dart';
import 'package:offline_first_bi/data/repositories/location_repository.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/data/repositories/product_repository.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/data/repositories/supplier_repository.dart';
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

void main() {
  late AppDatabase db;

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

  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Finder button(String label) => find.widgetWithText(ElevatedButton, label);

  final confirmationTitle = find.text('¿Descartar los cambios?');
  final confirmationText = find.text('Los datos escritos se perderán.');

  Future<void> type(WidgetTester tester, String label, String text) async {
    final field = fieldLabeled(label);
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String label) => tester
      .widget<TextFormField>(fieldLabeled(label))
      .controller!
      .text;

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

  group('Back with typed data asks before closing', () {
    testWidgets('sale: confirmation, Seguir editando keeps the data', (
      tester,
    ) async {
      await openSheet(tester, const SaleDialog());
      await addProductToCart(tester);

      await pressBack(tester);

      expect(confirmationTitle, findsOneWidget);
      expect(confirmationText, findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);
      expect(find.text('Seguir editando'), findsOneWidget);
      expect(find.byType(SaleDialog), findsOneWidget);

      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();

      expect(confirmationTitle, findsNothing);
      expect(find.byType(SaleDialog), findsOneWidget);
      expect(find.text('Carrito'), findsOneWidget);
      expect(find.text('Libro'), findsWidgets);
    });

    testWidgets('sale: Descartar closes the form and saves nothing', (
      tester,
    ) async {
      await openSheet(tester, const SaleDialog());
      await addProductToCart(tester);

      await pressBack(tester);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(SaleDialog), findsNothing);
      expect(confirmationTitle, findsNothing);
      expect(await SaleRepository(db).getAll(), isEmpty);
    });

    testWidgets('sale: Back with nothing typed closes directly', (
      tester,
    ) async {
      await openSheet(tester, const SaleDialog());

      await pressBack(tester);

      expect(find.byType(SaleDialog), findsNothing);
      expect(confirmationTitle, findsNothing);
    });

    testWidgets('purchase: confirmation keeps the line, Descartar closes', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog());
      await addMaterialLine(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Agregar'));
      await tester.pumpAndSettle();

      await pressBack(tester);
      expect(confirmationTitle, findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Quitar material'), findsOneWidget);

      await pressBack(tester);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(PurchaseDialog), findsNothing);
      expect(await PurchaseRepository(db).getAll(), isEmpty);
    });

    testWidgets('purchase: Back with nothing typed closes directly', (
      tester,
    ) async {
      await openSheet(tester, const PurchaseDialog());

      await pressBack(tester);

      expect(find.byType(PurchaseDialog), findsNothing);
    });

    testWidgets('product: typed name asks, kept text survives', (tester) async {
      await openSheet(tester, const ProductDialog());
      await type(tester, 'Nombre', 'Cuadro');

      await pressBack(tester);
      expect(confirmationTitle, findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductDialog), findsOneWidget);
      expect(fieldText(tester, 'Nombre'), 'Cuadro');

      await pressBack(tester);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductDialog), findsNothing);
      expect(await ProductRepository(db).getAllIncludingInactive(), hasLength(1));
    });

    testWidgets('product: Back with nothing typed closes directly', (
      tester,
    ) async {
      await openSheet(tester, const ProductDialog());

      await pressBack(tester);

      expect(find.byType(ProductDialog), findsNothing);
    });

    testWidgets('client: typed name asks, Descartar closes', (tester) async {
      await openSheet(tester, const ClientDialog());
      await type(tester, 'Nombre', 'Ana');

      await pressBack(tester);
      expect(confirmationTitle, findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'Nombre'), 'Ana');

      await pressBack(tester);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(ClientDialog), findsNothing);
    });

    testWidgets('client: typing and erasing again counts as no change', (
      tester,
    ) async {
      await openSheet(tester, const ClientDialog());
      await type(tester, 'Nombre', 'Ana');
      await type(tester, 'Nombre', '');

      await pressBack(tester);

      expect(find.byType(ClientDialog), findsNothing);
      expect(confirmationTitle, findsNothing);
    });

    testWidgets('tapping outside a form with data asks too', (tester) async {
      await openSheet(tester, const ClientDialog());
      await type(tester, 'Nombre', 'Ana');

      await tester.tapAt(const Offset(450, 30));
      await tester.pumpAndSettle();

      expect(confirmationTitle, findsOneWidget);
      expect(find.byType(ClientDialog), findsOneWidget);
    });

    testWidgets('the Volver button still closes without asking', (
      tester,
    ) async {
      await openSheet(tester, const ClientDialog());
      await type(tester, 'Nombre', 'Ana');

      await tester.ensureVisible(button('Volver'));
      await tester.tap(button('Volver'));
      await tester.pumpAndSettle();

      expect(find.byType(ClientDialog), findsNothing);
      expect(confirmationTitle, findsNothing);
    });
  });

  group('nested forms check their own changes', () {
    testWidgets(
      'Nuevo material over Agregar material over Nueva compra: each level '
      'asks for its own data',
      (tester) async {
        await openSheet(tester, const PurchaseDialog());
        await tester.ensureVisible(materialsAddButton());
        await tester.tap(materialsAddButton());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nuevo material'));
        await tester.pumpAndSettle();
        await type(tester, 'Nombre', 'Hilo');

        await pressBack(tester);
        expect(confirmationTitle, findsOneWidget);
        await tester.tap(find.text('Seguir editando'));
        await tester.pumpAndSettle();
        expect(find.byType(MaterialDialog), findsOneWidget);
        expect(fieldText(tester, 'Nombre'), 'Hilo');

        await pressBack(tester);
        await tester.tap(find.text('Descartar'));
        await tester.pumpAndSettle();
        expect(find.byType(MaterialDialog), findsNothing);
        expect(find.text('Agregar material'), findsOneWidget);
        expect(find.text('Nueva compra'), findsOneWidget);
        expect(await MaterialRepository(db).getAllIncludingInactive(), hasLength(1));

        await pressBack(tester);
        expect(find.text('Agregar material'), findsNothing);
        expect(find.text('Nueva compra'), findsOneWidget);
        expect(confirmationTitle, findsNothing);
      },
    );

    testWidgets('a typed form under an untouched nested form stays open', (
      tester,
    ) async {
      await openSheet(tester, const SaleDialog());
      await addProductToCart(tester);
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      await pressBack(tester);

      expect(find.byType(ClientDialog), findsNothing);
      expect(find.byType(SaleDialog), findsOneWidget);
      expect(confirmationTitle, findsNothing);

      await pressBack(tester);
      expect(confirmationTitle, findsOneWidget);
    });
  });

  group('editing without changes closes directly', () {
    Future<void> expectClosesDirectly(
      WidgetTester tester,
      Widget sheet,
      Type type,
    ) async {
      await openSheet(tester, sheet);
      expect(find.byType(type), findsOneWidget);

      await pressBack(tester);

      expect(find.byType(type), findsNothing);
      expect(confirmationTitle, findsNothing);
    }

    testWidgets('categoría', (tester) async {
      await CategoryRepository(db).save(name: 'Pinturas', description: 'x');
      final category = (await CategoryRepository(db).getAllIncludingInactive())
          .firstWhere((c) => c.name == 'Pinturas');
      await expectClosesDirectly(
        tester,
        CategoryDialog(category: category),
        CategoryDialog,
      );
    });

    testWidgets('producto', (tester) async {
      final product = (await ProductRepository(db).getAllIncludingInactive())
          .single;
      await expectClosesDirectly(
        tester,
        ProductDialog(product: product),
        ProductDialog,
      );
    });

    testWidgets('material', (tester) async {
      final material = (await MaterialRepository(db).getAllIncludingInactive())
          .single;
      await expectClosesDirectly(
        tester,
        MaterialDialog(material: material),
        MaterialDialog,
      );
    });

    testWidgets('cliente', (tester) async {
      await ClientRepository(db).save(name: 'Ana', contactInfo: '555');
      final client = (await ClientRepository(db).getAllIncludingInactive())
          .firstWhere((c) => c.name == 'Ana');
      await expectClosesDirectly(
        tester,
        ClientDialog(client: client),
        ClientDialog,
      );
    });

    testWidgets('proveedor', (tester) async {
      await SupplierRepository(db).save(name: 'Papelera', contactInfo: '555');
      final supplier = (await SupplierRepository(db).getAllIncludingInactive())
          .firstWhere((s) => s.name == 'Papelera');
      await expectClosesDirectly(
        tester,
        SupplierDialog(supplier: supplier),
        SupplierDialog,
      );
    });

    testWidgets('ubicación', (tester) async {
      await LocationRepository(db).save(
        city: 'Oruro',
        country: 'Bolivia',
        description: 'Centro',
      );
      final location = (await LocationRepository(db).getAllIncludingInactive())
          .firstWhere((l) => l.city == 'Oruro');
      await expectClosesDirectly(
        tester,
        LocationDialog(location: location),
        LocationDialog,
      );
    });

    testWidgets('evento', (tester) async {
      await EventRepository(db).save(
        name: 'Feria',
        startDate: DateTime(2026, 3, 5),
        endDate: DateTime(2026, 3, 7),
        notes: 'n',
      );
      final event = (await EventRepository(db).getAll()).single;
      await expectClosesDirectly(
        tester,
        EventDialog(event: event),
        EventDialog,
      );
    });

    testWidgets('venta', (tester) async {
      await SaleRepository(db).createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 40,
        discount: 5,
        finalAmount: 35,
        date: DateTime(2024, 1, 1),
        notes: 'nota',
        items: [
          {'productId': 1, 'quantity': 2, 'unitPrice': 20.0, 'priceType': 'A'},
        ],
      );
      final sale = (await SaleRepository(db).getAll()).single;
      await expectClosesDirectly(tester, SaleDialog(sale: sale), SaleDialog);
    });

    testWidgets('compra', (tester) async {
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
      final purchase = (await PurchaseRepository(db).getAll()).single;
      await expectClosesDirectly(
        tester,
        PurchaseDialog(purchase: purchase),
        PurchaseDialog,
      );
    });

    testWidgets('a changed edit form asks', (tester) async {
      await ClientRepository(db).save(name: 'Ana');
      final client = (await ClientRepository(db).getAllIncludingInactive())
          .firstWhere((c) => c.name == 'Ana');
      await openSheet(tester, ClientDialog(client: client));
      await type(tester, 'Información de contacto', '555');

      await pressBack(tester);

      expect(confirmationTitle, findsOneWidget);
      expect(find.byType(ClientDialog), findsOneWidget);
    });
  });

  group('material usage forms', () {
    Future<void> openUsageTab(WidgetTester tester) async {
      await openWidget(tester, const Scaffold(body: MaterialsUsageTab()));
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).first,
        'Libro',
        'Libro',
      );
    }

    testWidgets('Registrar uso de material: typed data asks', (tester) async {
      await openUsageTab(tester);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        'Tela',
        'Tela',
      );

      await pressBack(tester);
      expect(confirmationTitle, findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar uso de material'), findsOneWidget);

      await pressBack(tester);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar uso de material'), findsNothing);
    });

    testWidgets('Registrar uso de material: nothing typed closes directly', (
      tester,
    ) async {
      await openUsageTab(tester);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      await pressBack(tester);

      expect(find.text('Registrar uso de material'), findsNothing);
    });

    testWidgets('Editar registro de uso: asks only after a change', (
      tester,
    ) async {
      await MaterialRepository(db).registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 3,
      );
      await openUsageTab(tester);
      await tester.tap(find.textContaining('3 unidades'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar registro de uso'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.pumpAndSettle();
      await pressBack(tester);
      expect(confirmationTitle, findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar registro de uso'), findsNothing);
    });
  });
}
