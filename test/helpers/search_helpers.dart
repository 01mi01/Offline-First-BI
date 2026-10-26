import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> searchProducts(WidgetTester tester, String text) async {
  await tester.enterText(find.widgetWithText(TextField, 'Buscar producto'), text);
  await tester.pumpAndSettle();
}

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
  await tester.tap(find.descendant(of: picker, matching: find.text(option)).last);
  await tester.pumpAndSettle();
}
