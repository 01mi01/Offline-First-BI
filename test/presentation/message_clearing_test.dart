import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/category_provider.dart';
import 'package:offline_first_bi/application/client_provider.dart';
import 'package:offline_first_bi/application/form_validation.dart';
import 'package:offline_first_bi/application/location_provider.dart';
import 'package:offline_first_bi/application/material_provider.dart';
import 'package:offline_first_bi/application/date_range_filter.dart';
import 'package:offline_first_bi/application/product_provider.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/presentation/widgets/filter_panel.dart';
import 'package:offline_first_bi/application/supplier_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/category_repository.dart';
import 'package:offline_first_bi/data/repositories/client_repository.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/data/repositories/product_repository.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/data/repositories/supplier_repository.dart';
import 'package:offline_first_bi/models/category_model.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/presentation/dialogs/category_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/client_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/event_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/location_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/material_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/product_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/supplier_dialog.dart';
import 'package:offline_first_bi/presentation/pages/login_page.dart';
import 'package:offline_first_bi/presentation/pages/materials_page.dart';
import 'package:offline_first_bi/presentation/widgets/form_widgets.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'form_finders.dart';
import 'search_helpers.dart';

String _us(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

void main() {
  late AppDatabase db;
  late int unitUnidad;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    unitUnidad = (await (db.select(
      db.units,
    )..where((u) => u.name.equals('unidad'))).getSingle()).id;
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
        unitId: unitUnidad,
        pricePerUnit: 4,
        stock: const Value(100),
      ),
    );
    await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Hilo',
        unitId: unitUnidad,
        pricePerUnit: 2,
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

  Future<void> open(WidgetTester tester, Widget sheet) async {
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
    final container = ProviderScope.containerOf(
      tester.element(find.text('Open')),
    );
    await container.read(productProvider.notifier).load();
    await container.read(clientProvider.notifier).load();
    await container.read(supplierProvider.notifier).load();
    await container.read(categoryProvider.notifier).load();
    await container.read(locationProvider.notifier).load();
    await container.read(materialProvider.notifier).load();
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    final field = fieldLabeled(label);
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(ElevatedButton, label);
    await tester.ensureVisible(button.first);
    await tester.pumpAndSettle();
    await tester.tap(button.first);
    await tester.pumpAndSettle();
  }

  Future<void> pickDate(
    WidgetTester tester,
    Finder opener,
    DateTime date,
  ) async {
    await tester.ensureVisible(opener);
    await tester.tap(opener);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
      _us(date),
    );
    await tester.pump();
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseUnit(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Unidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<int>, 'unidad'));
    await tester.pumpAndSettle();
  }

  Future<void> addProductToCart(WidgetTester tester) async {
    await searchProducts(tester, 'Libro');
    await tester.tap(find.byIcon(Icons.add_circle_rounded));
    await tester.pumpAndSettle();
  }

  group('Nuevo producto', () {
    testWidgets('required messages clear as the name and one price are typed', (
      tester,
    ) async {
      await open(tester, const ProductDialog());
      await tapButton(tester, 'Crear');
      expect(find.text('Indica al menos un precio'), findsNWidgets(2));
      expect(find.text(requiredMessage), findsNWidgets(2));

      await type(tester, 'Nombre', 'Cuadro');
      expect(find.text(requiredMessage), findsNWidgets(1));

      await type(tester, 'Precio A', '10');
      expect(find.text('Indica al menos un precio'), findsNothing);

      await type(tester, 'Stock', '3');
      expect(find.text(requiredMessage), findsNothing);
    });

    testWidgets('the cost message follows the cost and both prices', (
      tester,
    ) async {
      await open(tester, const ProductDialog());
      await type(tester, 'Precio A', '10');
      await type(tester, 'Costo de producción', '20');
      expect(find.text('Debe ser menor a los precios de venta'), findsOneWidget);

      await type(tester, 'Costo de producción', '5');
      expect(find.text('Debe ser menor a los precios de venta'), findsNothing);

      await type(tester, 'Costo de producción', '20');
      expect(find.text('Debe ser menor a los precios de venta'), findsOneWidget);
      await type(tester, 'Precio A', '50');
      expect(find.text('Debe ser menor a los precios de venta'), findsNothing);

      await type(tester, 'Precio B', '15');
      expect(find.text('Debe ser menor a los precios de venta'), findsOneWidget);
      await type(tester, 'Precio B', '');
      expect(find.text('Debe ser menor a los precios de venta'), findsNothing);
    });

    testWidgets('the duplicate name message clears when the name changes', (
      tester,
    ) async {
      await open(tester, const ProductDialog());
      await type(tester, 'Nombre', 'libro');
      expect(find.text(duplicateProductMessage), findsOneWidget);

      await type(tester, 'Nombre', 'Libro nuevo');
      expect(find.text(duplicateProductMessage), findsNothing);
    });

    testWidgets('a numeric message is replaced by the current one', (
      tester,
    ) async {
      await open(tester, const ProductDialog());
      await type(tester, 'Precio A', '0');
      expect(find.text('Debe ser mayor a 0'), findsOneWidget);
      await type(tester, 'Precio A', '1.234');
      expect(find.text('Máximo 2 decimales'), findsOneWidget);
      expect(find.text('Debe ser mayor a 0'), findsNothing);
      await type(tester, 'Precio A', '1.5');
      expect(find.text('Máximo 2 decimales'), findsNothing);
    });
  });

  group('Nuevo material', () {
    testWidgets('the unit message clears when a unit is chosen', (
      tester,
    ) async {
      await open(tester, const MaterialDialog());
      await tapButton(tester, 'Crear');
      expect(find.text('Selecciona una unidad'), findsOneWidget);

      await chooseUnit(tester);
      expect(find.text('Selecciona una unidad'), findsNothing);
    });

    testWidgets('the total needs a quantity and clears once there is one', (
      tester,
    ) async {
      await open(tester, const MaterialDialog());
      await type(tester, 'Total pagado (Bs.)', '10');
      expect(
        find.text('Indica la cantidad para calcular el precio'),
        findsOneWidget,
      );

      await type(tester, 'Stock', '2');
      expect(
        find.text('Indica la cantidad para calcular el precio'),
        findsNothing,
      );
    });

    testWidgets('the price message clears when the total is typed instead', (
      tester,
    ) async {
      await open(tester, const MaterialDialog());
      await type(tester, 'Stock', '2');
      await type(tester, 'Precio por unidad', '0');
      expect(find.text('Debe ser mayor a 0'), findsOneWidget);

      await type(tester, 'Total pagado (Bs.)', '10');
      expect(find.text('Debe ser mayor a 0'), findsNothing);
    });
  });

  group('names', () {
    testWidgets('client: required, duplicate and reserved messages', (
      tester,
    ) async {
      await ClientRepository(db).save(name: 'Ana');
      await open(tester, const ClientDialog());
      await tapButton(tester, 'Crear');
      expect(find.text(requiredMessage), findsOneWidget);

      await type(tester, 'Nombre', 'ana');
      expect(find.text(requiredMessage), findsNothing);
      expect(find.text('Ya existe un cliente con ese nombre'), findsOneWidget);

      await type(tester, 'Nombre', 'sin nombre');
      expect(find.text('Ya existe un cliente con ese nombre'), findsNothing);
      expect(
        find.text('Ese nombre está reservado para el registro predeterminado del sistema.'),
        findsOneWidget,
      );

      await type(tester, 'Nombre', 'Beto');
      expect(find.textContaining('Ese nombre'), findsNothing);
    });

    testWidgets('supplier: duplicate message clears when the name changes', (
      tester,
    ) async {
      await SupplierRepository(db).save(name: 'Papelera');
      await open(tester, const SupplierDialog());
      await type(tester, 'Nombre', 'papelera');
      expect(find.text('Ya existe un proveedor con ese nombre'), findsOneWidget);

      await type(tester, 'Nombre', 'Otra');
      expect(find.text('Ya existe un proveedor con ese nombre'), findsNothing);
    });

    testWidgets('category: duplicate message clears when the name changes', (
      tester,
    ) async {
      await CategoryRepository(db).save(name: 'Pinturas');
      await open(tester, const CategoryDialog());
      await type(tester, 'Nombre', 'pinturas');
      expect(find.text('Ya existe una categoría con ese nombre'), findsOneWidget);

      await type(tester, 'Nombre', 'Marcos');
      expect(find.text('Ya existe una categoría con ese nombre'), findsNothing);
    });

    testWidgets('location: the duplicate message follows any of its fields', (
      tester,
    ) async {
      await LocationRepositoryHelper.seed(db);
      await open(tester, const LocationDialog());
      await type(tester, 'Ciudad', 'Oruro');
      await type(tester, 'País', 'Bolivia');
      await tapButton(tester, 'Crear');
      const message =
          'Ya existe una ubicación con esa ciudad, país y descripción';
      expect(find.text(message), findsOneWidget);

      await type(tester, 'Descripción', 'Norte');
      expect(find.text(message), findsNothing);

      await type(tester, 'Descripción', '');
      await tapButton(tester, 'Crear');
      expect(find.text(message), findsOneWidget);
      await type(tester, 'País', 'Peru');
      expect(find.text(message), findsNothing);
    });
  });

  group('category with active products', () {
    Future<CategoryModel> seed() async {
      await CategoryRepository(db).save(name: 'Pinturas');
      final category = (await CategoryRepository(db).getAllIncludingInactive())
          .firstWhere((c) => c.name == 'Pinturas');
      await ProductRepository(db).save(
        name: 'Cuadro',
        categoryId: category.id,
        priceA: 10,
        stock: 1,
      );
      return category;
    }

    Future<void> rejectDeactivation(WidgetTester tester) async {
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Desactivar'),
        ),
      );
      await tester.pumpAndSettle();
      await tapButton(tester, 'Guardar');
    }

    const message =
        'No se puede desactivar una categoría con productos activos.';

    testWidgets('the rejection clears when another field is edited', (
      tester,
    ) async {
      final category = await seed();
      await open(tester, CategoryDialog(category: category));
      await rejectDeactivation(tester);
      expect(find.text(message), findsOneWidget);

      await type(tester, 'Descripción', 'algo');
      expect(find.text(message), findsNothing);
    });

    testWidgets('the rejection clears when the switch is changed', (
      tester,
    ) async {
      final category = await seed();
      await open(tester, CategoryDialog(category: category));
      await rejectDeactivation(tester);
      expect(find.text(message), findsOneWidget);

      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Desactivar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });
  });

  group('Nuevo evento', () {
    testWidgets('the start date message clears when a date is picked', (
      tester,
    ) async {
      await open(tester, const EventDialog());
      await type(tester, 'Nombre del evento', 'Feria');
      await tapButton(tester, 'Crear');
      expect(find.text('Selecciona la fecha de inicio'), findsOneWidget);

      await pickDate(
        tester,
        find.byWidgetPredicate(
          (w) => w is AppDateField && w.label == 'Fecha de inicio',
        ),
        DateTime(2026, 3, 10),
      );
      expect(find.text('Selecciona la fecha de inicio'), findsNothing);
    });

    testWidgets('the end date message follows both dates', (tester) async {
      await open(tester, const EventDialog());
      final start = find.byWidgetPredicate(
        (w) => w is AppDateField && w.label == 'Fecha de inicio',
      );
      final end = find.byWidgetPredicate(
        (w) => w is AppDateField && w.label == 'Fecha de fin (opcional)',
      );
      await pickDate(tester, start, DateTime(2026, 3, 1));
      await pickDate(tester, end, DateTime(2026, 3, 10));
      const message = 'La fecha de fin no puede ser anterior a la de inicio';
      expect(find.text(message), findsNothing);

      await pickDate(tester, start, DateTime(2026, 3, 20));
      expect(find.text(message), findsOneWidget);

      await pickDate(tester, start, DateTime(2026, 3, 5));
      expect(find.text(message), findsNothing);

      await pickDate(tester, start, DateTime(2026, 3, 25));
      expect(find.text(message), findsOneWidget);
      await tester.tap(find.byTooltip('Quitar fecha'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });
  });

  group('Nueva venta', () {
    testWidgets('the empty cart message clears when a product is added', (
      tester,
    ) async {
      await open(tester, const SaleDialog());
      await tapButton(tester, 'Registrar venta');
      expect(find.text('Agrega al menos un producto'), findsOneWidget);

      await addProductToCart(tester);
      expect(find.text('Agrega al menos un producto'), findsNothing);
    });

    testWidgets('the discount message follows the discount and the cart', (
      tester,
    ) async {
      await open(tester, const SaleDialog());
      await addProductToCart(tester);
      await tester.enterText(find.widgetWithText(TextFormField, '0.00'), '30');
      await tester.pumpAndSettle();
      const message = 'El descuento no puede ser mayor al subtotal';
      expect(find.text(message), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Agregar uno'));
      await tester.tap(find.byTooltip('Agregar uno'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);

      await tester.ensureVisible(find.byTooltip('Quitar uno'));
      await tester.tap(find.byTooltip('Quitar uno'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, '30'), '5');
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });
  });

  group('Nueva compra', () {
    testWidgets('the empty list message clears when a material is added', (
      tester,
    ) async {
      await open(tester, const PurchaseDialog());
      await tapButton(tester, 'Registrar compra');
      expect(find.text('Agrega al menos un material'), findsOneWidget);

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
      await tapButton(tester, 'Agregar');
      expect(find.text('Agrega al menos un material'), findsNothing);
    });

    testWidgets('the add sheet messages follow the selection and quantity', (
      tester,
    ) async {
      await open(tester, const PurchaseDialog());
      await tester.ensureVisible(materialsAddButton());
      await tester.tap(materialsAddButton());
      await tester.pumpAndSettle();
      await tapButton(tester, 'Agregar');
      expect(find.text('Selecciona un material'), findsOneWidget);

      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        'Tela',
        'Tela',
      );
      expect(find.text('Selecciona un material'), findsNothing);
    });

    testWidgets('the duplicate material message clears with the selection', (
      tester,
    ) async {
      await open(tester, const PurchaseDialog());
      for (final name in ['Tela']) {
        await tester.ensureVisible(materialsAddButton());
        await tester.tap(materialsAddButton());
        await tester.pumpAndSettle();
        await pickFromSearch(
          tester,
          find.byType(SearchablePickerField<int>).last,
          name,
          name,
        );
        await tester.enterText(find.widgetWithText(TextFormField, '0').first, '3');
        await tester.pumpAndSettle();
        await tapButton(tester, 'Agregar');
      }
      await tester.ensureVisible(materialsAddButton());
      await tester.tap(materialsAddButton());
      await tester.pumpAndSettle();
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        'Tela',
        'Tela',
      );
      expect(find.textContaining('Ese material ya está en la compra'), findsOneWidget);

      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        'Hilo',
        'Hilo',
      );
      expect(find.textContaining('Ese material ya está en la compra'), findsNothing);
    });

    testWidgets('a blocked cancellation clears when the form changes', (
      tester,
    ) async {
      final purchase = await _purchaseWithUsage(db);
      await open(tester, PurchaseDialog(purchase: purchase));
      await tapButton(tester, 'Cancelar la compra');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Cancelar la compra'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(PurchaseRepository.cancelBlockedMessage), findsOneWidget);

      await type(tester, 'Notas', 'nota');
      expect(find.text(PurchaseRepository.cancelBlockedMessage), findsNothing);
    });

    testWidgets('a blocked edit clears when the form changes', (tester) async {
      final purchase = await _purchaseWithUsage(db);
      await open(tester, PurchaseDialog(purchase: purchase));
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
      await tester.pumpAndSettle();
      await tapButton(tester, 'Guardar');
      expect(find.text(PurchaseRepository.editBlockedMessage), findsOneWidget);

      await type(tester, 'Notas', 'nota');
      expect(find.text(PurchaseRepository.editBlockedMessage), findsNothing);
    });
  });

  group('Registrar uso de material', () {
    testWidgets('the material message clears when a material is picked', (
      tester,
    ) async {
      await openWidget(tester, const Scaffold(body: MaterialsUsageTab()));
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).first,
        'Libro',
        'Libro',
      );
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tapButton(tester, 'Registrar');
      expect(find.text('Selecciona un material'), findsOneWidget);

      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        'Tela',
        'Tela',
      );
      expect(find.text('Selecciona un material'), findsNothing);
    });
  });

  group('messages do not appear earlier than before', () {
    testWidgets('typing in one field before submitting shows no new errors', (
      tester,
    ) async {
      await open(tester, const ProductDialog());
      await type(tester, 'Nombre', 'Cuadro');
      await type(tester, 'Nombre', 'Cuadro 2');

      expect(find.text('Indica al menos un precio'), findsNothing);
      expect(find.text(requiredMessage), findsNothing);
    });

    testWidgets('after a failed submit only the invalid fields show errors', (
      tester,
    ) async {
      await open(tester, const ClientDialog());
      await tapButton(tester, 'Crear');
      expect(find.text(requiredMessage), findsOneWidget);
      await type(tester, 'Información de contacto', 'x');
      expect(find.text(requiredMessage), findsOneWidget);
      await type(tester, 'Nombre', 'Ana');
      expect(find.text(requiredMessage), findsNothing);
    });
  });

  group('rejections from the repository', () {
    testWidgets('an edit of a sale cancelled elsewhere clears on any change', (
      tester,
    ) async {
      final repository = SaleRepository(db);
      await repository.createSale(
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
      final sale = (await repository.getAll()).single;
      await open(tester, SaleDialog(sale: sale));
      await repository.cancelSale(sale.id);

      await tapButton(tester, 'Guardar');
      const message = 'La venta está cancelada y no se puede editar';
      expect(find.text(message), findsOneWidget);

      await type(tester, 'Notas', 'nota');
      expect(find.text(message), findsNothing);
    });

    testWidgets('an edit of a usage cancelled elsewhere clears on any change', (
      tester,
    ) async {
      final materials = MaterialRepository(db);
      await materials.registerMaterialUsage(
        productId: 1,
        materialId: 1,
        quantityUsed: 3,
      );
      await openWidget(tester, const Scaffold(body: MaterialsUsageTab()));
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).first,
        'Libro',
        'Libro',
      );
      await tester.tap(find.textContaining('3 unidades'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      final record = (await db.select(db.productMaterials).get()).single;
      await materials.cancelMaterialUsage(record.id);

      await tester.enterText(find.byType(TextFormField).first, '4');
      await tester.pumpAndSettle();
      await tapButton(tester, 'Guardar');
      const message = 'El registro está cancelado y no se puede editar';
      expect(find.text(message), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });
  });

  group('fraction quantities', () {
    Future<void> seedContainer() async {
      final unit = (await (db.select(
        db.units,
      )..where((u) => u.name.equals('contenedor'))).getSingle()).id;
      await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Resina',
          unitId: unit,
          pricePerUnit: 3,
          stock: const Value(2),
        ),
      );
    }

    testWidgets('usage: the quantity messages follow the picker', (
      tester,
    ) async {
      await seedContainer();
      await openWidget(tester, const Scaffold(body: MaterialsUsageTab()));
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).first,
        'Libro',
        'Libro',
      );
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        'Resina',
        'Resina',
      );
      await tapButton(tester, 'Registrar');
      expect(find.text('Selecciona una cantidad'), findsOneWidget);

      await tester.tap(find.text('La mitad'));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona una cantidad'), findsNothing);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('container-whole-plus')));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Cantidad máxima disponible'), findsOneWidget);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey('container-whole-minus')));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Cantidad máxima disponible'), findsNothing);
    });

    testWidgets('purchase line: the quantity message clears on picking', (
      tester,
    ) async {
      await seedContainer();
      await open(tester, const PurchaseDialog());
      await tester.ensureVisible(materialsAddButton());
      await tester.tap(materialsAddButton());
      await tester.pumpAndSettle();
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        'Resina',
        'Resina',
      );
      await tapButton(tester, 'Agregar');
      expect(find.text('Selecciona una cantidad'), findsOneWidget);

      await tester.tap(find.text('La mitad'));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona una cantidad'), findsNothing);
    });
  });

  group('date range filter', () {
    testWidgets('the rejection snackbar goes away after a valid pick', (
      tester,
    ) async {
      var current = const DateRangeFilter();
      await openWidget(
        tester,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: Builder(
                builder: (context) => FilterDates(
                  current: current,
                  onApply: (next) => setState(() => current = next),
                ).build(context),
              ),
            ),
          ),
        ),
      );
      Finder box(String label) => find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.byType(InkWell),
      );
      await pickDate(tester, box('Hasta'), DateTime(2026, 3, 5));
      await pickDate(tester, box('Desde'), DateTime(2026, 3, 10));
      expect(find.text(rangeOrderMessage), findsOneWidget);

      await pickDate(tester, box('Desde'), DateTime(2026, 3, 1));
      await tester.pumpAndSettle();
      expect(find.text(rangeOrderMessage), findsNothing);
    });
  });

  group('Iniciar sesión', () {
    testWidgets('the wrong credentials message clears when typing', (
      tester,
    ) async {
      await db.select(db.modules).get();
      await db.into(db.users).insert(
        UsersCompanion.insert(
          username: 'usuario_prueba',
          email: 'prueba@test.com',
          passwordHash: sha256.convert(utf8.encode('123456')).toString(),
        ),
      );
      await openWidget(tester, const LoginPage());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de usuario'),
        'usuario_prueba',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'mala',
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'mala1',
      );
      await tester.pumpAndSettle();
      expect(find.text('Usuario o contraseña incorrectos'), findsNothing);
    });
  });
}

class LocationRepositoryHelper {
  static Future<void> seed(AppDatabase db) async {
    await db.into(db.locations).insert(
      LocationsCompanion.insert(city: 'Oruro', country: 'Bolivia'),
    );
  }
}

Future<PurchaseModel> _purchaseWithUsage(AppDatabase db) async {
  final purchases = PurchaseRepository(db);
  final unit = (await (db.select(
    db.units,
  )..where((u) => u.name.equals('unidad'))).getSingle()).id;
  final id = await db.into(db.materials).insert(
    MaterialsCompanion.insert(
      name: 'Cinta',
      unitId: unit,
      pricePerUnit: 2,
      stock: const Value(0),
    ),
  );
  await purchases.createPurchase(
    supplierId: null,
    isMaterial: true,
    description: null,
    totalAmount: 10,
    date: DateTime(2024, 1, 1),
    locationId: null,
    eventId: null,
    items: [
      {'materialId': id, 'quantity': 5.0, 'unitPrice': 2.0},
    ],
  );
  final product = await db.into(db.products).insert(
    ProductsCompanion.insert(
      categoryId: 1,
      name: 'Cuadro',
      priceA: 20,
      priceB: 20,
    ),
  );
  await MaterialRepository(db).registerMaterialUsage(
    productId: product,
    materialId: id,
    quantityUsed: 4,
  );
  return (await purchases.getAll()).single;
}
