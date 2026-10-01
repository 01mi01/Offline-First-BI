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
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/data/repositories/supplier_repository.dart';
import 'package:offline_first_bi/models/default_records.dart';
import 'package:offline_first_bi/presentation/dialogs/event_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/categories_page.dart';
import 'package:offline_first_bi/presentation/pages/clients_page.dart';
import 'package:offline_first_bi/presentation/pages/events_page.dart';
import 'package:offline_first_bi/presentation/pages/suppliers_page.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    bigScreen(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: lightTheme, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester, Widget sheet) async {
    await pumpApp(
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

  Future<void> seedProduct() => db.into(db.products).insert(
    ProductsCompanion.insert(
      categoryId: 1,
      name: 'Collar',
      priceA: 10,
      priceB: 10,
      stock: const Value(5),
    ),
  );

  group('default records show a lock instead of the edit button', () {
    testWidgets('categories: "Sin categoría" is locked, the others stay editable', (
      tester,
    ) async {
      await CategoryRepository(db).save(name: 'Bisutería');
      await pumpApp(tester, const CategoriesPage());

      expect(find.text('Sin categoría'), findsOneWidget);
      expect(find.text('Bisutería'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('clients: the default client is locked, the others stay editable', (
      tester,
    ) async {
      await ClientRepository(db).save(name: 'Maria');
      await pumpApp(tester, const ClientsPage());

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('suppliers: "Sin proveedor" is locked, the others stay editable', (
      tester,
    ) async {
      await SupplierRepository(db).save(name: 'Andino');
      await pumpApp(tester, const SuppliersPage());

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });
  });

  group('leaving the client / supplier unchosen is a deliberate, silent choice', () {
    testWidgets(
      'sale form: the client selector starts on "Sin nombre" and a sale saved '
      'without touching it is stored under the default client',
      (tester) async {
        await seedProduct();
        await openSheet(tester, const SaleDialog());

        // El selector muestra la opción predeterminada, no queda en blanco.
        final clientField = find.byType(SearchablePickerField<int>).first;
        expect(
          find.descendant(of: clientField, matching: find.text('Sin nombre')),
          findsOneWidget,
        );

        await tester.tap(find.byIcon(Icons.add)); // agrega el producto
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Registrar venta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Registrar venta'));
        await tester.pumpAndSettle();

        expect(find.byType(SaleDialog), findsNothing); // sin bloquear la venta
        final defaultId = (await (db.select(db.clients)
              ..where((c) => c.name.equals(DefaultRecords.client))).getSingle())
            .id;
        final sale = (await SaleRepository(db).getAll()).single;
        expect(sale.clientId, defaultId);
      },
    );

    testWidgets(
      'sale form: the default client is offered once ("Sin nombre"), next to '
      'the real clients',
      (tester) async {
        await ClientRepository(db).save(name: 'Maria');
        await openSheet(tester, const SaleDialog());

        await tester.tap(find.byType(SearchablePickerField<int>).first);
        await tester.pumpAndSettle();

        // Una vez en el campo (valor elegido) y una vez en el menú abierto;
        // no hay una tercera fila "Sin nombre" duplicada.
        expect(find.text('Sin nombre'), findsNWidgets(2));
        expect(find.text('Maria'), findsOneWidget);
      },
    );

    testWidgets(
      'purchase form: an expense saved without a supplier is stored under '
      '"Sin proveedor"',
      (tester) async {
        await openSheet(tester, const PurchaseDialog());

        final supplierField = find.byType(SearchablePickerField<int>).first;
        expect(
          find.descendant(of: supplierField, matching: find.text('Sin proveedor')),
          findsOneWidget,
        );

        // Materiales -> Gasto general
        await tester.tap(find.text('Gasto general'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Descripción del gasto'),
          'Alquiler',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Total (Bs.)'),
          '50',
        );
        await tester.ensureVisible(find.text('Registrar compra'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Registrar compra'));
        await tester.pumpAndSettle();

        final defaultId = (await (db.select(db.suppliers)
              ..where((s) => s.name.equals(DefaultRecords.supplier))).getSingle())
            .id;
        final purchase = (await PurchaseRepository(db).getAll()).single;
        expect(purchase.supplierId, defaultId);
      },
    );
  });

  group('deactivating an event', () {
    Future<void> seedEvents() async {
      final repository = EventRepository(db);
      await repository.save(name: 'Feria', startDate: DateTime(2024, 3, 5));
      await repository.save(name: 'Expo', startDate: DateTime(2024, 4, 5));
    }

    testWidgets(
      'asks for confirmation, keeps the record, and the list marks it "Inactivo"',
      (tester) async {
        await seedEvents();
        final expo = (await EventRepository(db).getAll()).firstWhere((e) => e.name == 'Expo');

        await openSheet(tester, EventDialog(event: expo));
        expect(find.text('Evento activo'), findsOneWidget);

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(find.text('¿Desactivar evento?'), findsOneWidget);
        await tester.tap(find.text('Desactivar'));
        await tester.pumpAndSettle();
        expect(find.text('Oculto en el sistema'), findsOneWidget);

        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        final events = await EventRepository(db).getAll();
        expect(events, hasLength(2)); // no se borra
        expect(events.firstWhere((e) => e.name == 'Expo').isActive, isFalse);
        expect(events.firstWhere((e) => e.name == 'Feria').isActive, isTrue);

        // La lista sigue mostrando ambos, con su estado.
        await pumpApp(tester, const EventsPage());
        expect(find.text('Expo'), findsOneWidget);
        expect(find.text('Feria'), findsOneWidget);
        expect(find.text('Inactivo'), findsOneWidget);
        expect(find.text('Activo'), findsOneWidget);
      },
    );

    testWidgets('choosing "Cancelar" in the confirmation leaves the event active', (
      tester,
    ) async {
      await seedEvents();
      final expo = (await EventRepository(db).getAll()).firstWhere((e) => e.name == 'Expo');
      await openSheet(tester, EventDialog(event: expo));

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();

      expect(find.text('Visible en el sistema'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('a new event has no active toggle (it starts active)', (tester) async {
      await openSheet(tester, const EventDialog());

      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('an inactive event is hidden from the event pickers of sales and purchases', (
      tester,
    ) async {
      await seedEvents();
      final repository = EventRepository(db);
      final expo = (await repository.getAll()).firstWhere((e) => e.name == 'Expo');
      await repository.save(
        id: expo.id,
        name: 'Expo',
        startDate: expo.startDate,
        isActive: false,
      );

      // Ventas: selector de evento (segundo desplegable: tras la ubicación).
      await openSheet(tester, const SaleDialog());
      final saleEventField = find.byType(DropdownButtonFormField<int>).at(1);
      await tester.ensureVisible(saleEventField);
      await tester.tap(saleEventField);
      await tester.pumpAndSettle();
      expect(find.text('Feria'), findsOneWidget);
      expect(find.text('Expo'), findsNothing);
    });

    testWidgets('purchases: the event picker also hides the inactive event', (
      tester,
    ) async {
      await seedEvents();
      final repository = EventRepository(db);
      final expo = (await repository.getAll()).firstWhere((e) => e.name == 'Expo');
      await repository.save(
        id: expo.id,
        name: 'Expo',
        startDate: expo.startDate,
        isActive: false,
      );

      await openSheet(tester, const PurchaseDialog());
      // Ubicación, evento (el proveedor ahora es un selector con búsqueda)
      final purchaseEventField = find.byType(DropdownButtonFormField<int>).at(1);
      await tester.ensureVisible(purchaseEventField);
      await tester.tap(purchaseEventField);
      await tester.pumpAndSettle();
      expect(find.text('Feria'), findsOneWidget);
      expect(find.text('Expo'), findsNothing);
    });

    testWidgets(
      'editing a sale that already belongs to a now-inactive event still shows '
      'that event (the selector does not crash)',
      (tester) async {
        await seedEvents();
        final repository = EventRepository(db);
        final expo = (await repository.getAll()).firstWhere((e) => e.name == 'Expo');
        await seedProduct();
        await SaleRepository(db).createSale(
          clientId: null,
          locationId: null,
          eventId: expo.id,
          totalAmount: 10,
          discount: 0,
          finalAmount: 10,
          date: DateTime(2024, 4, 5),
          items: [
            {'productId': 1, 'quantity': 1, 'unitPrice': 10.0},
          ],
        );
        await repository.save(
          id: expo.id,
          name: 'Expo',
          startDate: expo.startDate,
          isActive: false,
        );
        final sale = (await SaleRepository(db).getAll()).single;

        await openSheet(tester, SaleDialog(sale: sale));

        final eventField = find.byType(DropdownButtonFormField<int>).at(1);
        expect(find.descendant(of: eventField, matching: find.text('Expo')), findsOneWidget);
      },
    );
  });
}
