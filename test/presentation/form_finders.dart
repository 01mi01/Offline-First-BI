import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/presentation/widgets/form_widgets.dart';

Finder fieldLabeled(String label) => _FieldLabeledFinder(label);

class _FieldLabeledFinder extends MatchFinder {
  _FieldLabeledFinder(this.label);

  final String label;

  @override
  String get description => 'TextFormField labeled "$label"';

  @override
  bool matches(Element candidate) {
    if (candidate.widget is! TextFormField) return false;
    var match = false;
    var decided = false;
    candidate.visitAncestorElements((ancestor) {
      final descendants = <Element>[];
      void collect(Element e) {
        descendants.add(e);
        e.visitChildren(collect);
      }

      ancestor.visitChildren(collect);
      final labelIndex = descendants.indexWhere(
        (e) => e.widget is Text && (e.widget as Text).data == label,
      );
      if (labelIndex < 0) return true;
      decided = true;
      final next = descendants.indexWhere(
        (e) => e.widget is TextFormField,
        labelIndex,
      );
      match = next >= 0 && identical(descendants[next], candidate);
      return false;
    });
    return decided && match;
  }
}

Finder materialsAddButton() => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is FormSectionLabel && w.text == 'Materiales',
  ),
  matching: find.byType(FormAddButton),
);

Future<void> chooseOption(WidgetTester tester, String label, String option) async {
  await tester.tap(find.byTooltip(label));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(option).last);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}
