import 'rounding.dart';

String formatQuantity(double value) {
  final rounded = round2(value);
  if (rounded == rounded.truncateToDouble()) return rounded.toInt().toString();
  final text = rounded.toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

String unitLabel(String name, double quantity) {
  final unit = name.trim();
  if (quantity == 1 || unit.isEmpty) return unit;
  if (unit.toLowerCase() == 'kg') return unit;
  return unit.split(RegExp(r'\s+')).map(_pluralizeWord).join(' ');
}

String _pluralizeWord(String word) {
  if (word.isEmpty) return word;
  return 'aeiouáéíóú'.contains(word[word.length - 1].toLowerCase())
      ? '${word}s'
      : '${word}es';
}

String quantityWithUnit(double value, String? unit) {
  final number = formatQuantity(value);
  final name = unit?.trim() ?? '';
  return name.isEmpty ? number : '$number ${unitLabel(name, round2(value))}';
}

String unitsText(num value) => quantityWithUnit(value.toDouble(), 'unidad');
