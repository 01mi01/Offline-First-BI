import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/models/default_records.dart';

void main() {
  test('protected-record messages follow one pattern, with the right gender', () {
    expect(
      DefaultRecords.protectedCategoryMessage,
      'No se puede editar o desactivar esta categoría',
    );
    expect(
      DefaultRecords.protectedClientMessage,
      'No se puede editar o desactivar este cliente',
    );
    expect(
      DefaultRecords.protectedSupplierMessage,
      'No se puede editar o desactivar este proveedor',
    );
  });
}
