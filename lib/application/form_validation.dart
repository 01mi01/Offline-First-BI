import 'search_filter.dart';

// Reglas de validación de los formularios. Cada función devuelve el mensaje que
// se muestra bajo el campo, o null si el valor es válido.

const String requiredMessage = 'Campo requerido';
const int maxNameLength = 100;
const int maxTextLength = 500;
// Tope de un importe (Bs.): evita números absurdos que desbordarían reportes.
const double maxAmount = 99999999.99;
// Tope de una cantidad de stock o de un material.
const double maxQuantity = 9999999;

// Texto obligatorio: vacío o solo espacios no vale.
String? validateRequired(String? value, {String message = requiredMessage}) =>
    value == null || value.trim().isEmpty ? message : null;

// Nombre obligatorio y de largo razonable.
String? validateName(String? value, {String message = requiredMessage}) {
  final error = validateRequired(value, message: message);
  if (error != null) return error;
  if (value!.trim().length > maxNameLength) {
    return 'Máximo $maxNameLength caracteres';
  }
  return null;
}

// Texto opcional (descripción, notas...) con largo máximo.
String? validateOptionalText(String? value) {
  if (value != null && value.trim().length > maxTextLength) {
    return 'Máximo $maxTextLength caracteres';
  }
  return null;
}

// Forma común de comparar nombres: sin distinguir mayúsculas, tildes ni
// espacios de más.
String comparableName(String name) =>
    normalizeForSearch(name).replaceAll(RegExp(r'\s+'), ' ');

// ¿Hay otro registro con el mismo nombre (sin distinguir mayúsculas ni
// tildes)? [others] son los nombres de los demás registros (sin el que se está
// editando).
String? validateUniqueName(
  String? value,
  Iterable<String> others, {
  required String message,
}) {
  final name = comparableName(value ?? '');
  if (name.isEmpty) return null;
  for (final other in others) {
    if (comparableName(other) == name) return message;
  }
  return null;
}

final RegExp _numberPattern = RegExp(r'^\d*\.?\d+$|^\d+\.$');

// Número escrito por una persona: solo dígitos con un punto decimal opcional.
// Devuelve null si no es un número válido.
double? parseNumber(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty || !_numberPattern.hasMatch(text)) return null;
  return double.tryParse(text);
}

int _decimalsOf(String text) {
  final dot = text.indexOf('.');
  return dot < 0 ? 0 : text.length - dot - 1;
}

// Importe o cantidad decimal: obligatorio (o no, según [required]), sin
// negativos, sin letras ni símbolos, con [maxDecimals] decimales como máximo y
// mayor a cero salvo que [allowZero].
String? validateDecimal(
  String? value, {
  bool required = true,
  bool allowZero = false,
  int maxDecimals = 2,
  double max = maxAmount,
}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return required ? requiredMessage : null;
  if (text.startsWith('-')) return 'No puede ser negativo';
  final number = parseNumber(text);
  if (number == null) return 'Ingresa un número válido';
  if (_decimalsOf(text) > maxDecimals) {
    return maxDecimals == 0
        ? 'Solo se admiten números enteros'
        : 'Máximo $maxDecimals decimales';
  }
  if (number == 0 && !allowZero) return 'Debe ser mayor a 0';
  if (number > max) return 'El valor es demasiado grande';
  return null;
}

// Importe en bolivianos: dos decimales como máximo.
String? validateAmountField(
  String? value, {
  bool required = true,
  bool allowZero = false,
}) => validateDecimal(
  value,
  required: required,
  allowZero: allowZero,
  maxDecimals: 2,
  max: maxAmount,
);
