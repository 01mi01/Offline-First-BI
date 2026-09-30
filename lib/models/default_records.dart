// Registros predeterminados del sistema. Se siembran al crear la base y
// reciben, sin que la persona lo note, lo que se guarda sin elegir categoría,
// cliente o proveedor. Por eso están protegidos: nadie puede renombrarlos,
// editarlos ni desactivarlos, y ningún otro registro puede usar su nombre.
class DefaultRecords {
  static const String category = 'Sin categoría';
  static const String client = 'Sin nombre';
  static const String supplier = 'Sin proveedor';

  // Mismo patrón para los tres, con el artículo y el género de cada uno.
  static const String protectedCategoryMessage =
      'No se puede editar o desactivar esta categoría';
  static const String protectedClientMessage =
      'No se puede editar o desactivar este cliente';
  static const String protectedSupplierMessage =
      'No se puede editar o desactivar este proveedor';
  static const String reservedNameMessage =
      'Ese nombre está reservado para el registro predeterminado del sistema.';

  // Compara sin distinguir mayúsculas ni espacios de los extremos, para que
  // "sin categoría " tampoco pueda pasar por un registro distinto.
  static bool _same(String? name, String defaultName) =>
      name != null && name.trim().toLowerCase() == defaultName.toLowerCase();

  static bool isCategory(String? name) => _same(name, category);
  static bool isClient(String? name) => _same(name, client);
  static bool isSupplier(String? name) => _same(name, supplier);
}

// Se lanza cuando se intenta modificar un registro predeterminado, o usar su
// nombre para otro. Su mensaje ya está pensado para mostrarse a la persona.
class ProtectedRecordException implements Exception {
  final String message;

  const ProtectedRecordException(this.message);

  @override
  String toString() => message;
}
