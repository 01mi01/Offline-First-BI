import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/config/rounding.dart';

// Redondeo de la app: dos decimales "half up" en importes, cantidades decimales
// y cualquier número calculado; las fracciones solo pierden el ruido.
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
      expect(total == 10.0, isFalse); // la suma cruda arrastra ruido
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

    test('decimal units show two decimals', () {
      expect(
        formatMaterialQuantity(72.6 - 15, unitType: 'medida', unitName: 'metro'),
        '57.60',
      );
      expect(formatMaterialQuantity(2, unitType: 'otros'), '2.00');
    });

    test('whole-number units stay whole', () {
      expect(
        formatMaterialQuantity(12, unitType: 'otros', unitName: 'unidad'),
        '12',
      );
    });

    test('fraction units keep the fraction, trimmed and without noise', () {
      expect(formatMaterialQuantity(0.25, unitType: 'contenedor'), '0.25');
      expect(formatMaterialQuantity(2.5, unitType: 'contenedor'), '2.5');
      expect(formatMaterialQuantity(3, unitType: 'contenedor'), '3');
      expect(
        formatMaterialQuantity(0.1 + 0.2, unitType: 'contenedor'),
        '0.3',
      );
    });
  });
}
