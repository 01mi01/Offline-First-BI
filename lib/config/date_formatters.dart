// Formato de fechas de toda la app: un solo estilo, dd/MM/aaaa, en pantallas,
// filtros y exportaciones. Es numérico para no depender del idioma del
// dispositivo ni de abreviaturas de meses.

String _two(int n) => n.toString().padLeft(2, '0');

// 29/09/2026
String formatDate(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year}';

// 29/09/2026 16:32
String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${_two(date.hour)}:${_two(date.minute)}';

// 2026-09-29: para nombres de archivo (ordenable y sin barras).
String formatDateForFileName(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';
