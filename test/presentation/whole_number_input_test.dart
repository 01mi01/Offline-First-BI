import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/presentation/widgets/unit_quantity_input.dart';

// Campos de cantidad de unidades "por pieza" (unidad, botella...): un "." no
// debe descartarse en silencio (antes "2.5" se convertía en "25"), sino
// rechazarse con feedback visible.
void main() {
  group('WholeNumberInputFormatter', () {
    TextEditingValue value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    test('accepts digits only', () {
      const formatter = WholeNumberInputFormatter();
      final result = formatter.formatEditUpdate(value('2'), value('25'));
      expect(result.text, '25');
    });

    test('accepts clearing the field', () {
      const formatter = WholeNumberInputFormatter();
      final result = formatter.formatEditUpdate(value('2'), value(''));
      expect(result.text, '');
    });

    test('rejects a typed "." keeping the previous value (never "2.5" -> "25")', () {
      var rejected = 0;
      final formatter = WholeNumberInputFormatter(onRejected: () => rejected++);

      final result = formatter.formatEditUpdate(value('2'), value('2.'));

      expect(result.text, '2');
      expect(rejected, 1);
    });

    test('rejects a typed "," (decimal comma) too', () {
      var rejected = 0;
      final formatter = WholeNumberInputFormatter(onRejected: () => rejected++);

      final result = formatter.formatEditUpdate(value('2'), value('2,'));

      expect(result.text, '2');
      expect(rejected, 1);
    });

    test('a pasted decimal is rejected as a whole, not mangled into digits', () {
      var rejected = 0;
      final formatter = WholeNumberInputFormatter(onRejected: () => rejected++);

      final result = formatter.formatEditUpdate(value(''), value('2.5'));

      expect(result.text, '');
      expect(rejected, 1);
    });
  });

  group('validateWholeNumberQuantity', () {
    test('requires a value', () {
      expect(validateWholeNumberQuantity(null), 'Campo requerido');
      expect(validateWholeNumberQuantity(''), 'Campo requerido');
    });

    test('rejects decimals with the whole-number message', () {
      expect(validateWholeNumberQuantity('2.5'), wholeNumberOnlyMessage);
      expect(validateWholeNumberQuantity('2,5'), wholeNumberOnlyMessage);
    });

    test('rejects zero', () {
      expect(validateWholeNumberQuantity('0'), 'Cantidad inválida');
    });

    test('0 is rejected by default but accepted with allowZero', () {
      expect(validateWholeNumberQuantity('0'), 'Cantidad inválida');
      expect(validateWholeNumberQuantity('0', allowZero: true), isNull);
      expect(
        validateWholeNumberQuantity('2.5', allowZero: true),
        wholeNumberOnlyMessage,
      );
    });

    test('accepts a positive integer', () {
      expect(validateWholeNumberQuantity('3'), isNull);
    });
  });

  group('WholeNumberQuantityField', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Future<void> pumpField(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: WholeNumberQuantityField(
              controller: controller,
              labelText: 'Cantidad (unidad)',
            ),
          ),
        ),
      ),
    );

    testWidgets('typing a "." keeps the number and shows an explanation', (
      tester,
    ) async {
      await pumpField(tester);
      final field = find.byType(TextFormField);

      await tester.enterText(field, '2');
      await tester.pump();
      expect(controller.text, '2');
      expect(find.text(wholeNumberOnlyMessage), findsNothing);

      // El usuario intenta escribir el punto de "2.5".
      await tester.enterText(field, '2.');
      await tester.pump();

      expect(controller.text, '2', reason: 'el punto no debe quedar en el campo');
      expect(
        find.text(wholeNumberOnlyMessage),
        findsOneWidget,
        reason: 'el usuario debe ver por qué no se registró la tecla',
      );

      // Nunca se convierte en 25 por su cuenta.
      expect(controller.text, isNot('25'));
    });

    testWidgets('the warning disappears on the next accepted keystroke', (
      tester,
    ) async {
      await pumpField(tester);
      final field = find.byType(TextFormField);

      await tester.enterText(field, '2');
      await tester.enterText(field, '2.');
      await tester.pump();
      expect(find.text(wholeNumberOnlyMessage), findsOneWidget);

      await tester.enterText(field, '25');
      await tester.pump();

      expect(controller.text, '25');
      expect(find.text(wholeNumberOnlyMessage), findsNothing);
    });

    testWidgets('a pasted decimal is rejected and leaves the field untouched', (
      tester,
    ) async {
      await pumpField(tester);

      await tester.enterText(find.byType(TextFormField), '2.5');
      await tester.pump();

      expect(controller.text, '');
      expect(find.text(wholeNumberOnlyMessage), findsOneWidget);
    });

    testWidgets('uses a numeric keyboard without the decimal option', (
      tester,
    ) async {
      await pumpField(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType.decimal, isFalse);
      expect(field.keyboardType.index, TextInputType.number.index);
    });

    testWidgets('extraValidator runs on a valid integer (e.g. a stock cap)', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: WholeNumberQuantityField(
                controller: controller,
                labelText: 'Cantidad',
                extraValidator: (qty) => qty > 5 ? 'Máximo: 5' : null,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '9');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Máximo: 5'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '4');
      expect(formKey.currentState!.validate(), isTrue);
    });
  });

  group('unitLabel (unit name next to a quantity)', () {
    test('singular for exactly 1', () {
      expect(unitLabel('botella', 1), 'botella');
    });

    test('plural with -s after a vowel', () {
      expect(unitLabel('botella', 5), 'botellas');
      expect(unitLabel('metro', 0.5), 'metros');
    });

    test('plural with -es after a consonant', () {
      expect(unitLabel('unidad', 3), 'unidades');
    });

    test('"kg" is invariable', () {
      expect(unitLabel('kg', 2), 'kg');
    });
  });
}
