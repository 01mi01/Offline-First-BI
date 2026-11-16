enum AppRole {
  administrador('admin', 'Administrador'),
  propietario('propietario', 'Propietario'),
  empleado('empleado', 'Empleado');

  final String dbName;
  final String label;

  const AppRole(this.dbName, this.label);

  static AppRole fromDbName(String name) => AppRole.values.firstWhere(
    (r) => r.dbName == name,
    orElse: () => AppRole.empleado,
  );
}
