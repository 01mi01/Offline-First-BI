import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// Compras: el tipo de compra son dos opciones con nombre propio, "Materiales"
// y "Gasto general", en lugar de una etiqueta fija con un subtítulo que cambia.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openPurchase(WidgetTester tester, {PurchaseModel? purchase}) async {
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
                  builder: (_) => PurchaseDialog(purchase: purchase),
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

  final selector = find.byType(SegmentedButton<bool>);
  Finder option(String label) =>
      find.descendant(of: selector, matching: find.text(label));
  bool? selectedValue(WidgetTester tester) {
    final selected = tester.widget<SegmentedButton<bool>>(selector).selected;
    return selected.length == 1 ? selected.single : null;
  }

  testWidgets('shows two independently labeled options, and none of the old contradictory texts', (
    tester,
  ) async {
    await openPurchase(tester);

    expect(option('Materiales'), findsOneWidget);
    expect(option('Gasto general'), findsOneWidget);
    // Ni la etiqueta fija ni los subtítulos que cambiaban.
    expect(find.text('Compra de materiales'), findsNothing);
    expect(find.text('Gasto general del negocio'), findsNothing);
    expect(find.text('Actualiza stock de materiales'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('starts on "Materiales" and shows the materials section', (tester) async {
    await openPurchase(tester);

    expect(selectedValue(tester), isTrue);
    expect(find.text('Sin materiales agregados'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Descripción del gasto'), findsNothing);
  });

  testWidgets('each option puts the form in its own, distinct state', (tester) async {
    await openPurchase(tester);

    // Gasto general: descripción + total, sin sección de materiales.
    await tester.tap(option('Gasto general'));
    await tester.pumpAndSettle();
    expect(selectedValue(tester), isFalse);
    expect(find.widgetWithText(TextFormField, 'Descripción del gasto'), findsOneWidget);
    expect(find.text('Sin materiales agregados'), findsNothing);

    // De vuelta a Materiales.
    await tester.tap(option('Materiales'));
    await tester.pumpAndSettle();
    expect(selectedValue(tester), isTrue);
    expect(find.text('Sin materiales agregados'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Descripción del gasto'), findsNothing);
  });

  testWidgets('exactly one option is selected at any time', (tester) async {
    await openPurchase(tester);

    for (final label in ['Gasto general', 'Materiales', 'Gasto general']) {
      await tester.tap(option(label));
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<bool>>(selector).selected, hasLength(1));
    }
    expect(selectedValue(tester), isFalse);
  });

  testWidgets('editing an existing general expense opens on "Gasto general"', (
    tester,
  ) async {
    await openPurchase(
      tester,
      purchase: PurchaseModel(
        id: 1,
        isMaterial: false,
        description: 'Participación en feria',
        totalAmount: 50,
        date: DateTime(2024, 3, 5),
        createdAt: DateTime(2024, 3, 5),
      ),
    );

    expect(selectedValue(tester), isFalse);
    expect(find.widgetWithText(TextFormField, 'Descripción del gasto'), findsOneWidget);
  });
}
