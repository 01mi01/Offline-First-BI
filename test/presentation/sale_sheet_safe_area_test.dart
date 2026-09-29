import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// La hoja "Nueva venta" es más alta que la pantalla: sin respetar el área
// segura su título quedaba debajo de la barra de estado del teléfono.
void main() {
  testWidgets(
    'the "Nueva venta" title starts below the status bar (safe area top inset)',
    (tester) async {
      const statusBarHeight = 48.0;
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      // Barra de estado simulada de 48 px.
      tester.view.padding = const FakeViewPadding(top: statusBarHeight);
      tester.view.viewPadding = const FakeViewPadding(top: statusBarHeight);
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(theme: lightTheme, home: const SalesPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final titleTop = tester.getTopLeft(find.text('Nueva venta')).dy;
      expect(
        titleTop,
        greaterThanOrEqualTo(statusBarHeight),
        reason: 'el título no debe quedar bajo la barra de estado',
      );
    },
  );
}
