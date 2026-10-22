import 'dart:math' as math;

double _nudge(double scaled) =>
    scaled + (scaled < 0 ? -1 : 1) * math.max(1e-9, 1e-12 * scaled.abs());

double round2(double value) {
  if (value.isNaN || value.isInfinite) return value;
  final result = _nudge(value * 100).roundToDouble() / 100;
  return result == 0 ? 0.0 : result;
}

double cleanFloat(double value) {
  if (value.isNaN || value.isInfinite) return value;
  final result = (value * 1e6).roundToDouble() / 1e6;
  return result == 0 ? 0.0 : result;
}

const String fractionUnitType = 'contenedor';

double roundQuantity(double value, {required String unitType}) =>
    unitType == fractionUnitType ? cleanFloat(value) : round2(value);

const Set<String> wholeNumberUnitNames = {'unidad'};

String fixed2(double value) => round2(value).toStringAsFixed(2);
