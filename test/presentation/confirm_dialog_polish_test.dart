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

  testWidgets('title, message and both buttons are centered in the dialog', (
    tester,
  ) async {
    await _open(tester, message: 'El algo "X" no estará disponible.');

    final dialogCenter = tester.getCenter(find.byType(AlertDialog)).dx;
    for (final finder in [
      find.text('¿Desactivar algo?'),
      find.text('El algo "X" no estará disponible.'),
      find.widgetWithText(ElevatedButton, 'Desactivar'),
      find.widgetWithText(OutlinedButton, 'Cancelar'),
    ]) {
      expect(
        tester.getCenter(finder).dx,
        closeTo(dialogCenter, 1.0),
        reason: '$finder debe quedar centrado',
      );
    }
    final title = tester.widget<Text>(find.text('¿Desactivar algo?'));
    expect(title.textAlign, TextAlign.center);
  });

  testWidgets('a long, wrapping title is centered too', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => confirmCancellation(
                  context,
                  title: '¿Cancelar registro de uso del material seleccionado?',
                  message: 'Se devolverá 1 contenedor.',
                  confirmLabel: 'Cancelar registro',
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

    final title = tester.widget<Text>(
      find.text('¿Cancelar registro de uso del material seleccionado?'),
    );
    expect(title.textAlign, TextAlign.center);
    final box = tester.getRect(
      find.text('¿Cancelar registro de uso del material seleccionado?'),
    );
    // El bloque de texto del título ocupa el ancho del diálogo: centrado.
    expect(
      box.center.dx,
      closeTo(tester.getCenter(find.byType(AlertDialog)).dx, 1.0),
    );
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
