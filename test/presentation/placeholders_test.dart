import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
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
import 'package:offline_first_bi/theme/app_theme.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpSheet(WidgetTester tester, Widget sheet) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: lightTheme, home: Scaffold(body: sheet)),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectEveryFieldHasHint(WidgetTester tester) {
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    for (final field in fields) {
      expect(field.decoration?.hintText, isNotNull);
      expect(field.decoration!.hintText, isNotEmpty);
    }
  }

  final forms = <String, Widget Function()>{
    'login': () => const LoginPage(),
    'category': () => const CategoryDialog(),
    'client': () => const ClientDialog(),
    'supplier': () => const SupplierDialog(),
    'location': () => const LocationDialog(),
    'event': () => const EventDialog(),
    'material': () => const MaterialDialog(),
    'product': () => const ProductDialog(),
    'sale': () => const SaleDialog(),
    'purchase': () => const PurchaseDialog(),
  };

  for (final entry in forms.entries) {
    testWidgets('every text field of the ${entry.key} form has a placeholder', (
      tester,
    ) async {
      await pumpSheet(tester, entry.value());
      expectEveryFieldHasHint(tester);
    });
  }

  testWidgets('the expense purchase form has placeholders too', (tester) async {
    await pumpSheet(tester, const PurchaseDialog());
    await tester.tap(find.text('Gasto general'));
    await tester.pumpAndSettle();
    expectEveryFieldHasHint(tester);
  });

  testWidgets('amount fields share one placeholder', (tester) async {
    await pumpSheet(tester, const PurchaseDialog());
    expect(find.widgetWithText(TextFormField, '0.00'), findsOneWidget);
    await tester.tap(find.text('Gasto general'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '0.00'), findsOneWidget);
  });
}
