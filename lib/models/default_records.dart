class DefaultRecords {
  static const String category = 'Sin categoría';
  static const String client = 'Sin nombre';
  static const String supplier = 'Sin proveedor';

  static const String protectedCategoryMessage =
      'No se puede editar o desactivar esta categoría';
  static const String protectedClientMessage =
      'No se puede editar o desactivar este cliente';
  static const String protectedSupplierMessage =
      'No se puede editar o desactivar este proveedor';
  static const String reservedNameMessage =
      'Ese nombre está reservado para el registro predeterminado del sistema.';

  static bool _same(String? name, String defaultName) =>
      name != null && name.trim().toLowerCase() == defaultName.toLowerCase();

  static bool isCategory(String? name) => _same(name, category);
  static bool isClient(String? name) => _same(name, client);
  static bool isSupplier(String? name) => _same(name, supplier);
}

class ProtectedRecordException implements Exception {
  final String message;

  const ProtectedRecordException(this.message);

  @override
  String toString() => message;
}
