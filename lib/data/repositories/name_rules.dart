import '../../application/form_validation.dart';

class InvalidNameException implements Exception {
  final String message;

  const InvalidNameException(this.message);

  @override
  String toString() => message;
}

String requireName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) throw const InvalidNameException(requiredMessage);
  return trimmed;
}

bool sameName(String a, String b) => comparableName(a) == comparableName(b);
