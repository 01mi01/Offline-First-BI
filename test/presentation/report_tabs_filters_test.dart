import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/config/date_formatters.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/pages/reports_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'package:offline_first_bi/config/app_clock.dart';

// Reportes: las pestañas Ventas y Compras llevan cada una sus propios filtros.
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
          home: const Scaffold(body: ReportsBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickDate(WidgetTester tester, String chipLabel) async {
    await tester.tap(find.text(chipLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String name) async {
    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text(name)));
    await tester.pumpAndSettle();
  }

  final today = formatDate(appNow());

  testWidgets(
    'a date set on the Ventas tab does not carry over to Compras, and it is '
    'still there when coming back',
    (tester) async {
      await pumpReports(tester);

      await pickDate(tester, 'Fecha de inicio');
      expect(find.text('Desde: $today'), findsOneWidget);

      await openTab(tester, 'Compras');
      expect(find.textContaining('Desde:'), findsNothing);
      expect(find.text('Fecha de inicio'), findsOneWidget);

      await openTab(tester, 'Ventas');
      expect(find.text('Desde: $today'), findsOneWidget);
    },
  );

  testWidgets(
    'filters set on Compras stay on Compras, and the two tabs can hold '
    'different dates at once',
    (tester) async {
      await pumpReports(tester);

      await openTab(tester, 'Compras');
      await pickDate(tester, 'Fecha de fin');
      expect(find.text('Hasta: $today'), findsOneWidget);
      expect(find.textContaining('Desde:'), findsNothing);

      await openTab(tester, 'Ventas');
      // Ventas no recibe el "Hasta" de Compras...
      expect(find.textContaining('Hasta:'), findsNothing);
      // ...y puede tener su propia fecha de inicio.
      await pickDate(tester, 'Fecha de inicio');
      expect(find.text('Desde: $today'), findsOneWidget);

      await openTab(tester, 'Compras');
      expect(find.text('Hasta: $today'), findsOneWidget);
      expect(find.textContaining('Desde:'), findsNothing);
    },
  );

  testWidgets('"Limpiar todo" on one tab leaves the other tab\'s filters alone', (
    tester,
  ) async {
    await pumpReports(tester);
    await pickDate(tester, 'Fecha de inicio'); // Ventas
    await openTab(tester, 'Compras');
    await pickDate(tester, 'Fecha de fin'); // Compras

    await tester.tap(find.text('Limpiar todo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hasta:'), findsNothing); // Compras limpia

    await openTab(tester, 'Ventas');
    expect(find.text('Desde: $today'), findsOneWidget); // Ventas intacta
  });
}
