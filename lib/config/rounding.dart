// Redondeo de la app: todo importe (Bs.), cantidad de unidades de medida
// decimales y cualquier otro número calculado (porcentajes, promedios,
// indicadores) lleva DOS decimales, redondeados "half up" (0.125 -> 0.13).
// Se redondea una sola vez, en el origen de cada cálculo, con estas funciones.
//
// Las cantidades de unidades por fracciones (contenedor, paquete, rollo, tira)
// quedan exentas: un cuarto o un tercio deben seguir exactos, así que solo se
// limpia el ruido de coma flotante más allá del sexto decimal.

// Tolerancia para que un valor como 1.005 (que en binario es 1.00499999...)
// redondee a 1.01 como se espera: el ruido de coma flotante es del orden de
// 1e-16 relativo, muy por debajo de este margen.
double _nudge(double scaled) =>
    scaled + (scaled < 0 ? -1 : 1) * 1e-9 * (scaled.abs() < 1 ? 1 : scaled.abs());

// Redondea a dos decimales, "half up" (lejos de cero en negativos, para que
// el resultado sea simétrico). NaN e infinito se devuelven tal cual.
double round2(double value) {
  if (value.isNaN || value.isInfinite) return value;
  final result = _nudge(value * 100).roundToDouble() / 100;
  return result == 0 ? 0.0 : result; // sin "-0.0"
}

// Quita el ruido de coma flotante más allá del sexto decimal sin cambiar
// fracciones reales (0.25, 1/3...). Para cantidades de unidades por fracciones.
double cleanFloat(double value) {
  if (value.isNaN || value.isInfinite) return value;
  final result = (value * 1e6).roundToDouble() / 1e6;
  return result == 0 ? 0.0 : result;
}

// Cantidad de un material según el tipo de su unidad: las unidades por
// fracciones ('contenedor') solo limpian el ruido; las demás (medida, otros,
// "unidad") van a dos decimales.
const String fractionUnitType = 'contenedor';

double roundQuantity(double value, {required String unitType}) =>
    unitType == fractionUnitType ? cleanFloat(value) : round2(value);

// Unidades "por pieza" que no son por fracciones: sus cantidades son enteras.
const Set<String> wholeNumberUnitNames = {'unidad'};

// Muestra una cantidad de material según su unidad: las unidades por
// fracciones conservan su fracción (2.5, 0.25: sin ceros de más y sin ruido),
// las de piezas enteras ("unidad") se ven enteras, y las de medida decimal
// (metro, kg, litro...) siempre con dos decimales ("57.60").
String formatMaterialQuantity(
  double value, {
  required String unitType,
  String unitName = '',
}) {
  if (unitType == fractionUnitType) return _trim(cleanFloat(value));
  if (wholeNumberUnitNames.contains(unitName.trim().toLowerCase())) {
    return _trim(round2(value));
  }
  return fixed2(value);
}

String _trim(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

// Texto con exactamente dos decimales ("57.60"), ya redondeado half up.
String fixed2(double value) => round2(value).toStringAsFixed(2);
