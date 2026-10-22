import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/event_repository.dart';
import 'package:offline_first_bi/data/repositories/location_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/event_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/presentation/widgets/info_hint.dart';
import 'package:offline_first_bi/data/repositories/client_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
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

  Future<void> openSheet(WidgetTester tester, Widget sheet) async {
    tester.view.physicalSize = const Size(900, 1600);
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
                  builder: (_) => sheet,
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

  Future<void> pickEvent(WidgetTester tester, String query, String name) async {
    final field = find.byType(SearchablePickerField<int>).at(2);
    await tester.ensureVisible(field);
    final input = find.descendant(of: field, matching: find.byType(TextField));
    await tester.tap(input);
    await tester.pumpAndSettle();
    await tester.enterText(input, query);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: field, matching: find.text(name)));
    await tester.pumpAndSettle();
  }

  String locationText(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byType(SearchablePickerField<int>).at(1),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  Future<void> seedEvents() async {
    await LocationRepository(db).save(city: 'La Paz', country: 'Bolivia');
    final location = (await db.select(db.locations).get()).single;
    final events = EventRepository(db);
    await events.save(
      name: 'Feria con lugar',
      startDate: DateTime(2024, 3, 5),
      locationId: location.id,
    );
    await events.save(name: 'Feria sin lugar', startDate: DateTime(2024, 4, 5));
  }

  testWidgets('an inactive event asks to be activated, with its own texts', (
    tester,
  ) async {
    await EventRepository(db).save(
      name: 'Feria vieja',
      startDate: DateTime(2024, 3, 5),
      isActive: false,
    );
    final event = (await EventRepository(db).getAll()).single;
    await openSheet(tester, EventDialog(event: event));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Activar el evento'), findsOneWidget);
    expect(
      find.text('El evento volverá a estar disponible para nuevos registros.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Activar'));
    await tester.pumpAndSettle();
    expect(find.text('Oculto en el sistema'), findsNothing);
  });

  for (final isSale in [true, false]) {
    testWidgets(
      '${isSale ? 'sale' : 'purchase'}: picking an event fills the location, or "Sin ubicación"',
      (tester) async {
        await seedEvents();
        await openSheet(
          tester,
          isSale ? const SaleDialog() : const PurchaseDialog(),
        );
        expect(locationText(tester), 'Sin ubicación');

        await pickEvent(tester, 'con lugar', 'Feria con lugar');
        expect(locationText(tester), 'La Paz, Bolivia');

        await pickEvent(tester, 'sin lugar', 'Feria sin lugar');
        expect(locationText(tester), 'Sin ubicación');
      },
    );
  }

  testWidgets('a sale row shows the first product with "+N más", then the client', (
    tester,
  ) async {
    await ClientRepository(db).save(name: 'Ana Martínez');
    final clientId = (await db.select(db.clients).get()).last.id;
    Future<int> product(String name) => db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: name,
        priceA: 10,
        priceB: 8,
        stock: const Value(20),
      ),
    );
    final a = await product('Pines grandes');
    final b = await product('Stickers');
    await SaleRepository(db).createSale(
      clientId: clientId,
      locationId: null,
      eventId: null,
      totalAmount: 20,
      discount: 5,
      finalAmount: 15,
      date: DateTime.now(),
      items: [
        {'productId': a, 'quantity': 1, 'unitPrice': 10.0, 'priceType': 'A'},
        {'productId': b, 'quantity': 1, 'unitPrice': 10.0, 'priceType': 'A'},
      ],
    );

    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: lightTheme, home: const SalesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pines grandes'), findsOneWidget);
    expect(find.text('+1 más'), findsOneWidget);
    expect(find.text('Ana Martínez'), findsOneWidget);
    expect(find.text('Stickers'), findsNothing);
    final discount = tester.widget<Text>(find.text('Desc. Bs. 5.00'));
    expect(discount.style?.color, AppColors.cyanDeep);
  });

  testWidgets('info dialogs close with the shared "Cerrar" button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showInfoDialog(context, title: 'Título', message: 'Texto'),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Entendido'), findsNothing);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Texto'), findsNothing);
  });
}
