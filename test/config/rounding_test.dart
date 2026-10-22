import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/config/quantity_format.dart';
import 'package:offline_first_bi/config/rounding.dart';

void main() {
  group('round2', () {
    test('rounds half up, also when the binary value sits just below the half', () {
      expect(round2(0.125), 0.13);
      expect(round2(1.005), 1.01);
      expect(round2(2.675), 2.68);
      expect(round2(0.994), 0.99);
      expect(round2(0.995), 1.0);
    });

    test('removes floating point noise', () {
      expect(round2(72.6 - 15), 57.6);
      expect(round2(0.1 + 0.2), 0.3);
      expect(round2(57.599999999999994), 57.6);
      expect(round2(70.00000000000001), 70.0);
    });

    test('is symmetric for negatives and never returns -0.0', () {
      expect(round2(-0.125), -0.13);
      expect(round2(-0.001).toString(), '0.0');
      expect(round2(-0.0).toString(), '0.0');
    });

    test('sums of many items stay on cents', () {
      var total = 0.0;
      for (var i = 0; i < 100; i++) {
        total += 0.1;
      }
      expect(total == 10.0, isFalse);
      expect(round2(total), 10.0);
    });

    test('NaN and infinity pass through', () {
      expect(round2(double.nan).isNaN, isTrue);
      expect(round2(double.infinity), double.infinity);
    });
  });

  group('cleanFloat', () {
    test('keeps real fractions and removes noise past the sixth decimal', () {
      expect(cleanFloat(0.25), 0.25);
      expect(cleanFloat(1 / 3), closeTo(0.333333, 1e-12));
      expect(cleanFloat(0.5 + 1e-12), 0.5);
      expect(cleanFloat(2.5 - 2.0000000000000004 + 2), 2.5);
    });
  });

  group('roundQuantity', () {
    test('fraction units keep their fractions, the rest go to two decimals', () {
      expect(roundQuantity(1 / 4, unitType: 'contenedor'), 0.25);
      expect(roundQuantity(1 / 3, unitType: 'contenedor'), isNot(0.33));
      expect(roundQuantity(57.599999999999994, unitType: 'medida'), 57.6);
      expect(roundQuantity(1.005, unitType: 'otros'), 1.01);
    });
  });

  group('fixed2 and formatMaterialQuantity', () {
    test('fixed2 always shows two decimals', () {
      expect(fixed2(57.6), '57.60');
      expect(fixed2(70), '70.00');
      expect(fixed2(13.333333), '13.33');
      expect(fixed2(0.1 + 0.2), '0.30');
    });

    test('whole numbers have no decimals', () {
      expect(formatQuantity(12), '12');
      expect(formatQuantity(2), '2');
      expect(formatQuantity(18.00), '18');
    });

    test('other values show up to two decimals without trailing zeros', () {
      expect(formatQuantity(72.6 - 15), '57.6');
      expect(formatQuantity(0.25), '0.25');
      expect(formatQuantity(2.5), '2.5');
      expect(formatQuantity(33.333), '33.33');
      expect(formatQuantity(0.1 + 0.2), '0.3');
    });

    test('quantity with unit agrees in number', () {
      expect(quantityWithUnit(1, 'metro'), '1 metro');
      expect(quantityWithUnit(95, 'metro'), '95 metros');
      expect(quantityWithUnit(16, 'contenedor'), '16 contenedores');
      expect(quantityWithUnit(0.5, 'paquete'), '0.5 paquetes');
      expect(quantityWithUnit(2.5, 'kg'), '2.5 kg');
      expect(quantityWithUnit(3, null), '3');
      expect(unitsText(1), '1 unidad');
      expect(unitsText(21), '21 unidades');
    });
  });
}
