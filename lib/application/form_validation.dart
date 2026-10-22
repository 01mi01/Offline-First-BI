import 'search_filter.dart';

const String requiredMessage = 'Campo requerido';
const int maxNameLength = 100;
const int maxTextLength = 500;
const double maxAmount = 99999999.99;
const double maxQuantity = 9999999;

String? validateRequired(String? value, {String message = requiredMessage}) =>
    value == null || value.trim().isEmpty ? message : null;

String? validateName(String? value) {
  final error = validateRequired(value);
  if (error != null) return error;
  if (value!.trim().length > maxNameLength) {
    return 'Máximo $maxNameLength caracteres';
  }
  return null;
}

String? validateOptionalText(String? value) {
  if (value != null && value.trim().length > maxTextLength) {
    return 'Máximo $maxTextLength caracteres';
  }
  return null;
}

String comparableName(String name) =>
    normalizeForSearch(name).replaceAll(RegExp(r'\s+'), ' ');

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

double? parseNumber(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty || !_numberPattern.hasMatch(text)) return null;
  return double.tryParse(text);
}

int _decimalsOf(String text) {
  final dot = text.indexOf('.');
  return dot < 0 ? 0 : text.length - dot - 1;
}

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
