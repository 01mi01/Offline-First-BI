import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Ayudas para los selectores con búsqueda: la lista solo aparece al escribir.

// Escribe en el buscador de productos de la hoja de ventas.
Future<void> searchProducts(WidgetTester tester, String text) async {
  await tester.enterText(find.widgetWithText(TextField, 'Buscar producto'), text);
  await tester.pumpAndSettle();
}

// Abre un [SearchablePickerField], escribe [query] y toca la opción [option].
Future<void> pickFromSearch(
  WidgetTester tester,
  Finder picker,
  String query,
  String option,
) async {
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  // La hoja de búsqueda es la ruta de más arriba: su campo es el último.
  await tester.enterText(find.byType(TextField).last, query);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}
