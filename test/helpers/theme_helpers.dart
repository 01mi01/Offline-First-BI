import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/presentation/pages/settings_page.dart';
import 'user_management_helpers.dart';

Finder themeOption(ThemeMode mode) => find.byKey(themeOptionKey(mode));

ThemeMode appThemeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

Brightness brightnessAt(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder.first)).brightness;

ThemeMode? selectedThemeOption(WidgetTester tester) {
  for (final mode in ThemeMode.values) {
    final check = find.descendant(
      of: themeOption(mode),
      matching: find.byIcon(Icons.check_rounded),
    );
    if (check.evaluate().isNotEmpty) return mode;
  }
  return null;
}

bool darkModeSwitchValue(WidgetTester tester) =>
    selectedThemeOption(tester) == ThemeMode.dark;

Future<void> chooseTheme(
  WidgetTester tester,
  ThemeMode mode, {
  bool settle = true,
}) async {
  if (themeOption(mode).evaluate().isEmpty) await openSettingsPage(tester);
  await tester.ensureVisible(themeOption(mode));
  await tester.pumpAndSettle();
  await tester.tap(themeOption(mode));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> tapDarkModeSwitch(WidgetTester tester, {bool settle = true}) =>
    chooseTheme(
      tester,
      appThemeMode(tester) == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      settle: settle,
    );
