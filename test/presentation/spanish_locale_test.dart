import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/config/app_localization.dart';

// Los selectores de fecha (filtros de reportes, fechas de eventos) usan los
// textos de Material: con la localización de la app deben salir en español,
// no en inglés ("Select date" / "Cancel" / "OK").
void main() {
  testWidgets('showDatePicker shows Spanish texts under the app locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: appLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2026, 9, 28),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('ACEPTAR'), findsOneWidget);
    expect(find.textContaining('Seleccionar fecha'), findsOneWidget);
    // Nada en inglés.
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('OK'), findsNothing);
    expect(find.textContaining('Select date'), findsNothing);
    // Y el mes va en español.
    expect(find.textContaining('septiembre'), findsWidgets);
  });

  testWidgets('without the localization delegates the picker stays in English (control)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2026, 9, 28),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });
}
