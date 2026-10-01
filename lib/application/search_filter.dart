// Búsqueda por texto sin distinguir mayúsculas ni tildes ("cafe" encuentra
// "Café"), usada por los selectores con búsqueda.
const _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n',
};

String normalizeForSearch(String text) {
  final lower = text.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

// Elementos cuyo texto contiene lo escrito. Una búsqueda vacía los devuelve
// todos, en su orden original.
List<T> filterByQuery<T>(
  Iterable<T> items,
  String query,
  String Function(T item) textOf,
) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return items.toList();
  return items.where((i) => normalizeForSearch(textOf(i)).contains(q)).toList();
}
