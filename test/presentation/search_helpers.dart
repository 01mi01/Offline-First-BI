import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Ayudas para los selectores con búsqueda: la lista solo aparece al escribir.

// Escribe en el buscador de productos de la hoja de ventas.
Future<void> searchProducts(WidgetTester tester, String text) async {
  await tester.enterText(find.widgetWithText(TextField, 'Buscar producto'), text);
  await tester.pumpAndSettle();
}

// Escribe en un [SearchablePickerField] (el buscador en línea) y toca la
// opción [option] de los resultados que aparecen debajo.
Future<void> pickFromSearch(
  WidgetTester tester,
  Finder picker,
  String query,
  String option,
) async {
  final field = find.descendant(of: picker, matching: find.byType(TextField));
  await tester.ensureVisible(picker);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, query);
  await tester.pumpAndSettle();
  // Los resultados van debajo del campo: la opción es la última coincidencia.
  await tester.tap(find.descendant(of: picker, matching: find.text(option)).last);
  await tester.pumpAndSettle();
}
