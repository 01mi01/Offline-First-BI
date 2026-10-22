import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/client_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/client_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/material_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/widgets/app_sheet.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'form_finders.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'search_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final unit = await (db.select(
      db.units,
    )..where((u) => u.name.equals('unidad'))).getSingle();
    await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Tela',
        unitId: unit.id,
        pricePerUnit: 4,
        stock: const Value(100),
      ),
    );
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Libro',
        priceA: 20,
        priceB: 20,
        stock: const Value(50),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> open(
    WidgetTester tester, {
    required Widget Function() sheet,
    bool form = true,
  }) async {
    tester.view.physicalSize = const Size(900, 2200);
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
                onPressed: () => form
                    ? showFormSheet<void>(context, builder: (_) => sheet())
                    : showAppSheet<void>(context, builder: (_) => sheet()),
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

  Future<void> dragDown(WidgetTester tester, Finder from) async {
    await tester.fling(from, const Offset(0, 900), 2500);
    await tester.pumpAndSettle();
  }

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

  final confirmation = find.text('¿Descartar los cambios?');

  group('a new form', () {
    testWidgets('untouched: dragging down closes it', (tester) async {
      await open(tester, sheet: () => const ClientDialog());

      await dragDown(tester, find.text('Nuevo cliente'));

      expect(find.byType(ClientDialog), findsNothing);
      expect(confirmation, findsNothing);
    });

    testWidgets('with typed text: dragging down does not close it', (
      tester,
    ) async {
      await open(tester, sheet: () => const ClientDialog());
      await type(tester, 'Nombre', 'Ana');

      await dragDown(tester, find.text('Nuevo cliente'));

      expect(find.byType(ClientDialog), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
    });

    testWidgets('typed text then erased: dragging down closes it', (
      tester,
    ) async {
      await open(tester, sheet: () => const ClientDialog());
      await type(tester, 'Nombre', 'Ana');
      await type(tester, 'Nombre', '');

      await dragDown(tester, find.text('Nuevo cliente'));

      expect(find.byType(ClientDialog), findsNothing);
    });

    testWidgets('typing again after being clean keeps the text and blocks', (
      tester,
    ) async {
      await open(tester, sheet: () => const ClientDialog());
      await type(tester, 'Nombre', 'Ana');
      await type(tester, 'Nombre', '');
      await type(tester, 'Nombre', 'Luis');

      expect(find.text('Luis'), findsOneWidget);
      await dragDown(tester, find.text('Nuevo cliente'));
      expect(find.byType(ClientDialog), findsOneWidget);
    });

    testWidgets('validation errors without changes do not block the drag', (
      tester,
    ) async {
      await open(tester, sheet: () => const ClientDialog());
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Crear'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear'));
      await tester.pumpAndSettle();
      expect(find.text('Campo requerido'), findsOneWidget);

      await dragDown(tester, find.text('Nuevo cliente'));

      expect(find.byType(ClientDialog), findsNothing);
    });

    testWidgets('a material form with typed stock then erased is clean', (
      tester,
    ) async {
      await open(tester, sheet: () => const MaterialDialog());
      await type(tester, 'Stock', '3');
      await type(tester, 'Stock', '');

      await dragDown(tester, find.text('Nuevo material'));

      expect(find.byType(MaterialDialog), findsNothing);
    });
  });

  group('an edit form', () {
    testWidgets('changed and reverted to the initial value: drag closes', (
      tester,
    ) async {
      await ClientRepository(db).save(name: 'Ana', contactInfo: '555');
      final client = (await ClientRepository(db).getAllIncludingInactive())
          .firstWhere((c) => c.name == 'Ana');
      await open(tester, sheet: () => ClientDialog(client: client));

      await type(tester, 'Información de contacto', '999');
      await dragDown(tester, find.text('Editar cliente'));
      expect(find.byType(ClientDialog), findsOneWidget);

      await type(tester, 'Información de contacto', '555');
      await dragDown(tester, find.text('Editar cliente'));
      expect(find.byType(ClientDialog), findsNothing);
    });
  });

  group('the sale form', () {
    testWidgets('untouched: dragging down closes it', (tester) async {
      await open(tester, sheet: () => const SaleDialog());

      await dragDown(tester, find.text('Nueva venta'));

      expect(find.byType(SaleDialog), findsNothing);
    });

    testWidgets('with a product in the cart: blocked; removed: closes', (
      tester,
    ) async {
      await open(tester, sheet: () => const SaleDialog());
      await addProductToCart(tester);

      await dragDown(tester, find.text('Nueva venta'));
      expect(find.byType(SaleDialog), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Quitar uno'));
      await tester.tap(find.byTooltip('Quitar uno'));
      await tester.pumpAndSettle();
      await dragDown(tester, find.text('Nueva venta'));
      expect(find.byType(SaleDialog), findsNothing);
    });
  });

  group('the purchase form', () {
    testWidgets('untouched: dragging down closes it', (tester) async {
      await open(tester, sheet: () => const PurchaseDialog());

      await dragDown(tester, find.text('Nueva compra'));

      expect(find.byType(PurchaseDialog), findsNothing);
    });

    testWidgets('switching to a general expense blocks it until switched back', (
      tester,
    ) async {
      await open(tester, sheet: () => const PurchaseDialog());
      await tester.tap(find.text('Gasto general'));
      await tester.pumpAndSettle();

      await dragDown(tester, find.text('Nueva compra'));
      expect(find.byType(PurchaseDialog), findsOneWidget);

      await tester.tap(find.text('Materiales').first);
      await tester.pumpAndSettle();
      await dragDown(tester, find.text('Nueva compra'));
      expect(find.byType(PurchaseDialog), findsNothing);
    });

    testWidgets('a material line blocks it and removing the line frees it', (
      tester,
    ) async {
      await open(tester, sheet: () => const PurchaseDialog());
      await tester.ensureVisible(materialsAddButton());
      await tester.tap(materialsAddButton());
      await tester.pumpAndSettle();
      await pickFromSearch(
        tester,
        find.byType(SearchablePickerField<int>).last,
        'Tela',
        'Tela',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '0').first,
        '3',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Agregar'));
      await tester.pumpAndSettle();

      await dragDown(tester, find.text('Nueva compra'));
      expect(find.byType(PurchaseDialog), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar material'));
      await tester.pumpAndSettle();
      await dragDown(tester, find.text('Nueva compra'));
      expect(find.byType(PurchaseDialog), findsNothing);
    });

    testWidgets('a typed expense total is a change', (tester) async {
      await open(tester, sheet: () => const PurchaseDialog());
      await tester.tap(find.text('Gasto general'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('purchase-total-expense')),
        '15',
      );
      await tester.pumpAndSettle();

      await dragDown(tester, find.text('Nueva compra'));

      expect(find.byType(PurchaseDialog), findsOneWidget);
    });
  });

  group('nested forms depend only on their own state', () {
    testWidgets('dirty client over a clean sale, then cleaned', (tester) async {
      await open(tester, sheet: () => const SaleDialog());
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();
      await type(tester, 'Nombre', 'Ana');

      await dragDown(tester, find.text('Nuevo cliente').last);
      expect(find.byType(ClientDialog), findsOneWidget);

      await type(tester, 'Nombre', '');
      await dragDown(tester, find.text('Nuevo cliente').last);
      expect(find.byType(ClientDialog), findsNothing);
      expect(find.byType(SaleDialog), findsOneWidget);

      await dragDown(tester, find.text('Nueva venta'));
      expect(find.byType(SaleDialog), findsNothing);
    });

    testWidgets('clean client over a dirty sale closes only the client', (
      tester,
    ) async {
      await open(tester, sheet: () => const SaleDialog());
      await addProductToCart(tester);
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      await dragDown(tester, find.text('Nuevo cliente').last);
      expect(find.byType(ClientDialog), findsNothing);
      expect(find.byType(SaleDialog), findsOneWidget);

      await dragDown(tester, find.text('Nueva venta'));
      expect(find.byType(SaleDialog), findsOneWidget);
    });
  });

  group('Back and tapping outside are unchanged', () {
    testWidgets('clean form: Back closes without asking', (tester) async {
      await open(tester, sheet: () => const ClientDialog());

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(ClientDialog), findsNothing);
      expect(confirmation, findsNothing);
    });

    testWidgets('dirty form: Back asks', (tester) async {
      await open(tester, sheet: () => const ClientDialog());
      await type(tester, 'Nombre', 'Ana');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(confirmation, findsOneWidget);
      expect(find.byType(ClientDialog), findsOneWidget);
    });

    testWidgets('dirty form: tapping outside asks', (tester) async {
      await open(tester, sheet: () => const ClientDialog());
      await type(tester, 'Nombre', 'Ana');

      await tester.tapAt(const Offset(450, 30));
      await tester.pumpAndSettle();

      expect(confirmation, findsOneWidget);
    });

    testWidgets('clean form: tapping outside closes without asking', (
      tester,
    ) async {
      await open(tester, sheet: () => const ClientDialog());

      await tester.tapAt(const Offset(450, 30));
      await tester.pumpAndSettle();

      expect(find.byType(ClientDialog), findsNothing);
      expect(confirmation, findsNothing);
    });
  });

  testWidgets('a sheet that is not a form still closes when dragged', (
    tester,
  ) async {
    await open(
      tester,
      form: false,
      sheet: () => const SizedBox(
        height: 300,
        child: Center(child: Text('Detalle de prueba')),
      ),
    );

    await dragDown(tester, find.text('Detalle de prueba'));

    expect(find.text('Detalle de prueba'), findsNothing);
  });
}
