
String _two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year}';

String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${_two(date.hour)}:${_two(date.minute)}';

String formatDateForFileName(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

const List<String> _shortMonthNames = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String formatDateShort(DateTime date) =>
    '${date.day} ${_shortMonthNames[date.month - 1]} ${date.year}';

