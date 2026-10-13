import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/config/date_formatters.dart';

// Un solo formato de fecha (dd/MM/aaaa).

void main() {
  group('date format', () {
    test('formatDate is dd/MM/yyyy with zero padding', () {
      expect(formatDate(DateTime(2026, 9, 29)), '29/09/2026');
      expect(formatDate(DateTime(2024, 1, 5)), '05/01/2024');
    });

    test('formatDateTime appends HH:mm (24 h)', () {
      expect(formatDateTime(DateTime(2026, 9, 29, 16, 32)), '29/09/2026 16:32');
      expect(formatDateTime(DateTime(2024, 1, 5, 9, 5)), '05/01/2024 09:05');
    });

    test('formatDateForFileName is yyyy-MM-dd (sortable, no slashes)', () {
      expect(formatDateForFileName(DateTime(2026, 9, 29)), '2026-09-29');
      expect(formatDateForFileName(DateTime(2024, 1, 5)), '2024-01-05');
    });
  });
}
