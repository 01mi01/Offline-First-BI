import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/widgets/app_controls.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'form_finders.dart';

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

  final selector = find.byType(AppSegmented<bool>);
  Finder option(String label) =>
      find.descendant(of: selector, matching: find.text(label));
  bool? selectedValue(WidgetTester tester) =>
      tester.widget<AppSegmented<bool>>(selector).selected;

  testWidgets('starts on "Materiales" and shows the materials section', (tester) async {
    await openPurchase(tester);

    expect(selectedValue(tester), isTrue);
    expect(find.text('No hay materiales agregados.'), findsOneWidget);
    expect(fieldLabeled('Descripción del gasto'), findsNothing);
  });

  testWidgets('each option puts the form in its own, distinct state', (tester) async {
    await openPurchase(tester);

    await tester.tap(option('Gasto general'));
    await tester.pumpAndSettle();
    expect(selectedValue(tester), isFalse);
    expect(fieldLabeled('Descripción del gasto'), findsOneWidget);
    expect(find.text('No hay materiales agregados.'), findsNothing);

    await tester.tap(option('Materiales'));
    await tester.pumpAndSettle();
    expect(selectedValue(tester), isTrue);
    expect(find.text('No hay materiales agregados.'), findsOneWidget);
    expect(fieldLabeled('Descripción del gasto'), findsNothing);
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
    expect(fieldLabeled('Descripción del gasto'), findsOneWidget);
  });
}
