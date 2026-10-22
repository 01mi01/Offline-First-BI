import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/presentation/widgets/unit_quantity_input.dart';

void main() {
  group('isFractionFriendlyUnitType', () {
    test('"contenedor" (e.g. paquete) uses the fraction picker', () {
      expect(isFractionFriendlyUnitType('contenedor'), isTrue);
    });

    test('"medida" (e.g. metro) uses a plain number field', () {
      expect(isFractionFriendlyUnitType('medida'), isFalse);
    });

    test('"otros" (comodín) uses a plain number field', () {
      expect(isFractionFriendlyUnitType('otros'), isFalse);
    });
  });

  group('isDiscreteUnit', () {
    test('"contenedor" (e.g. paquete) rejects decimal quantities', () {
      expect(isDiscreteUnit('contenedor', 'paquete'), isTrue);
    });

    test('"otros" (comodín) allows decimal quantities', () {
      expect(isDiscreteUnit('otros', 'otro'), isFalse);
    });

    test('"medida" unidad rejects decimal quantities', () {
      expect(isDiscreteUnit('medida', 'unidad'), isTrue);
    });

    test('"medida" unidad is matched case-insensitively', () {
      expect(isDiscreteUnit('medida', 'Unidad'), isTrue);
    });

    test('"medida" metro allows decimal quantities', () {
      expect(isDiscreteUnit('medida', 'metro'), isFalse);
    });

    test('"medida" litro allows decimal quantities', () {
      expect(isDiscreteUnit('medida', 'litro'), isFalse);
    });

    test('"medida" kg allows decimal quantities', () {
      expect(isDiscreteUnit('medida', 'kg'), isFalse);
    });

    test('"medida" gramo allows decimal quantities', () {
      expect(isDiscreteUnit('medida', 'gramo'), isFalse);
    });
  });
}
