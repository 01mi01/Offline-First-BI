import 'form_validation.dart';

const int minPasswordLength = 6;
const int maxUsernameLength = 30;
const int maxEmailLength = maxNameLength;

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateUsername(String? value) {
  final error = validateRequired(value);
  if (error != null) return error;
  final text = value!.trim();
  if (text.contains(RegExp(r'\s'))) return 'No puede tener espacios';
  if (text.length > maxUsernameLength) {
    return 'Máximo $maxUsernameLength caracteres';
  }
  return null;
}

String? validateEmail(String? value) {
  final error = validateRequired(value);
  if (error != null) return error;
  final text = value!.trim();
  if (text.length > maxEmailLength) return 'Máximo $maxEmailLength caracteres';
  if (!_emailPattern.hasMatch(text)) return 'Ingresa un correo válido';
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return requiredMessage;
  if (value.trim().isEmpty) return 'No puede tener solo espacios';
  if (value.length < minPasswordLength) {
    return 'Mínimo $minPasswordLength caracteres';
  }
  if (value.length > maxNameLength) return 'Máximo $maxNameLength caracteres';
  return null;
}
