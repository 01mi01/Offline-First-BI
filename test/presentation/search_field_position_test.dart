import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/pages/reports_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'filter_helpers.dart';

void main() {
  const screen = Size(360, 640);
  const keyboard = 300.0;
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (var i = 0; i < 30; i++) {
      await db.into(db.locations).insert(
        LocationsCompanion.insert(city: 'Zona $i', country: 'Bolivia'),
      );
      await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Cliente $i'));
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Producto $i',
          priceA: 1,
          priceB: 1,
          stock: const Value(5),
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = screen;
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

  void openKeyboard(WidgetTester tester) {
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> typeAndCheck(
    WidgetTester tester,
    Finder field, {
    required String first,
    required String second,
    required Finder results,
  }) async {
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await settle(tester);
    final atFocus = tester.getRect(field);
    await tester.enterText(field, first);
    await settle(tester);
    final before = tester.getRect(field);
    expect(before, atFocus);
    expect(before.top, greaterThanOrEqualTo(0));
    expect(before.bottom, lessThanOrEqualTo(screen.height - keyboard));
    expect(results, findsWidgets);
    expect(tester.getRect(results.first).top, greaterThanOrEqualTo(before.bottom));
    expect(tester.getRect(results.first).bottom, lessThanOrEqualTo(screen.height - keyboard));

    await tester.enterText(field, second);
    await settle(tester);
    expect(tester.getRect(field), before);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Reportes: typing in the Ubicación search keeps the field in place, above the keyboard', (
    tester,
  ) async {
    await pump(tester, const ReportsPage());
    await openFilterPanel(tester);
    final locationField = find.descendant(
      of: find.byKey(const ValueKey('filter-search-Ubicación')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(locationField);
    await tester.pumpAndSettle();
    await tester.tap(locationField);
    await tester.pumpAndSettle();
    openKeyboard(tester);
    await settle(tester);

    await typeAndCheck(
      tester,
      locationField,
      first: 'zona 1',
      second: 'zona 2',
      results: find.text('Zona 1, Bolivia'),
    );
  });
}
