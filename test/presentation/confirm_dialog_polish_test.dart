import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/models/default_records.dart';
import 'package:offline_first_bi/presentation/widgets/confirm_cancel_dialog.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

Future<void> _open(WidgetTester tester, {String? message}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => confirmCancellation(
                context,
                title: '¿Desactivar algo?',
                message: message,
                confirmLabel: 'Desactivar',
                dismissLabel: 'Cancelar',
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the confirmation message is center-aligned', (tester) async {
    await _open(tester, message: 'El algo "X" no estará disponible.');
    final text = tester.widget<Text>(find.text('El algo "X" no estará disponible.'));
    expect(text.textAlign, TextAlign.center);
  });

  testWidgets('without a message the dialog shows only the title and actions', (
    tester,
  ) async {
    await _open(tester);
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.content, isNull);
    expect(find.text('¿Desactivar algo?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Desactivar'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Cancelar'), findsOneWidget);
  });

  test('protected-record messages follow one pattern, with the right gender', () {
    expect(
      DefaultRecords.protectedCategoryMessage,
      'No se puede editar o desactivar esta categoría',
    );
    expect(
      DefaultRecords.protectedClientMessage,
      'No se puede editar o desactivar este cliente',
    );
    expect(
      DefaultRecords.protectedSupplierMessage,
      'No se puede editar o desactivar este proveedor',
    );
  });
}
