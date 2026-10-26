import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/presentation/widgets/filter_panel.dart';

import 'form_finders.dart';

Future<void> openFilterPanel(WidgetTester tester) async {
  final button = find.byType(FilterButton);
  if (button.evaluate().isEmpty ||
      tester.widget<FilterButton>(button.first).open) {
    return;
  }
  await tester.tap(button.first);
  await tester.pumpAndSettle();
}

Future<void> pickFilter(WidgetTester tester, String label, String option) async {
  await openFilterPanel(tester);
  await chooseOption(tester, label, option);
}

Future<void> pickPreset(WidgetTester tester, String preset) async {
  await openFilterPanel(tester);
  await tester.tap(find.text(preset));
  await tester.pumpAndSettle();
}

Finder dateBox(String label) => find
    .descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(InkWell),
    )
    .first;
