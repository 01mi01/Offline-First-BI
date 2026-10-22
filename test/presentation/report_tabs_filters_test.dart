import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/pages/reports_page.dart';
import 'package:offline_first_bi/presentation/widgets/app_controls.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'filter_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpReports(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: lightTheme,
          home: const ReportsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppTabSwitcher),
        matching: find.text(name),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a period set on the Ventas tab does not carry over to Compras, and it is '
    'still there when coming back',
    (tester) async {
      await pumpReports(tester);

      await pickPreset(tester, 'Hoy');
      expect(find.text('Limpiar'), findsOneWidget);

      await openTab(tester, 'Compras');
      expect(find.text('Limpiar'), findsNothing);

      await openTab(tester, 'Ventas');
      expect(find.text('Hoy'), findsOneWidget);
    },
  );

  testWidgets(
    'filters set on Compras stay on Compras, and the two tabs can hold '
    'different periods at once',
    (tester) async {
      await pumpReports(tester);

      await openTab(tester, 'Compras');
      await pickPreset(tester, 'Este mes');

      await openTab(tester, 'Ventas');
      expect(find.text('Limpiar'), findsNothing);
      await pickPreset(tester, 'Hoy');

      await openTab(tester, 'Compras');
      expect(find.text('Este mes'), findsOneWidget);
      expect(find.text('Hoy'), findsNothing);
      await openTab(tester, 'Ventas');
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Este mes'), findsNothing);
    },
  );

  testWidgets('"Limpiar" on one tab leaves the other tab filters alone', (
    tester,
  ) async {
    await pumpReports(tester);
    await pickPreset(tester, 'Hoy');
    await openTab(tester, 'Compras');
    await pickPreset(tester, 'Este mes');

    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    expect(find.text('Limpiar'), findsNothing);

    await openTab(tester, 'Ventas');
    expect(find.text('Hoy'), findsOneWidget);
  });
}
