import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/presentation/widgets/filter_panel.dart';

import 'form_finders.dart';

// Ayudas para el panel de filtros de las listas: un botón de filtros al lado
// del buscador despliega un panel con un desplegable por filtro, y las fechas
// (atajos de periodo y Desde / Hasta).

// Abre el panel de filtros si está cerrado.
Future<void> openFilterPanel(WidgetTester tester) async {
  if (find.byType(FilterPanel).evaluate().isNotEmpty &&
      find.descendant(
        of: find.byType(FilterPanel),
        matching: find.byType(Wrap),
      ).evaluate().isNotEmpty) {
    return;
  }
  await tester.tap(find.byType(FilterButton));
  await tester.pumpAndSettle();
}

// Elige [option] en el filtro [label] del panel (lo abre si hace falta).
Future<void> pickFilter(WidgetTester tester, String label, String option) async {
  await openFilterPanel(tester);
  await chooseOption(tester, label, option);
}

// Toca un atajo de periodo ("Hoy", "Este año"...) del panel de filtros.
Future<void> pickPreset(WidgetTester tester, String preset) async {
  await openFilterPanel(tester);
  await tester.tap(find.text(preset));
  await tester.pumpAndSettle();
}

// La casilla de fecha "Desde" o "Hasta" del panel de filtros (la que se toca
// para abrir el selector), a partir de su etiqueta.
Finder dateBox(String label) => find
    .descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(InkWell),
    )
    .first;
