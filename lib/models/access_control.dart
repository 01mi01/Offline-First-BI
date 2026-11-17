enum AppModule {
  inventario('inventario', 'Productos y categorías'),
  materiales('materiales', 'Materiales'),
  ventas('ventas', 'Ventas'),
  compras('compras', 'Compras'),
  clientes('clientes', 'Clientes'),
  proveedores('proveedores', 'Proveedores'),
  eventos('eventos', 'Eventos'),
  ubicaciones('ubicaciones', 'Ubicaciones'),
  reportes('reportes', 'Reportes', readOnly: true),
  businessIntelligence(
    'business_intelligence',
    'Business Intelligence',
    readOnly: true,
  ),
  auditoria('auditoria', 'Auditoría', commercial: false),
  usuarios('usuarios', 'Usuarios', commercial: false);

  final String dbName;
  final String label;
  final bool readOnly;
  final bool commercial;

  const AppModule(
    this.dbName,
    this.label, {
    this.readOnly = false,
    this.commercial = true,
  });

  static List<AppModule> get configurable =>
      values.where((m) => m.commercial).toList();

  static AppModule? fromDbName(String name) =>
      values.where((m) => m.dbName == name).firstOrNull;

  List<ModuleAction> get actions =>
      readOnly ? const [ModuleAction.read] : ModuleAction.values;
}

enum ModuleAction {
  read('Lectura'),
  create('Creación'),
  update('Actualización'),
  deactivate('Desactivación');

  final String label;

  const ModuleAction(this.label);
}

class PermissionSet {
  final bool create;
  final bool read;
  final bool update;
  final bool deactivate;

  const PermissionSet({
    this.create = false,
    this.read = false,
    this.update = false,
    this.deactivate = false,
  });

  static const PermissionSet full = PermissionSet(
    create: true,
    read: true,
    update: true,
    deactivate: true,
  );

  static const PermissionSet none = PermissionSet();

  bool allows(ModuleAction action) => switch (action) {
    ModuleAction.create => create,
    ModuleAction.read => read,
    ModuleAction.update => update,
    ModuleAction.deactivate => deactivate,
  };

  PermissionSet withAction(ModuleAction action, bool value) =>
      PermissionSet(
        create: action == ModuleAction.create ? value : create,
        read: action == ModuleAction.read ? value : read,
        update: action == ModuleAction.update ? value : update,
        deactivate: action == ModuleAction.deactivate ? value : deactivate,
      );

  @override
  bool operator ==(Object other) =>
      other is PermissionSet &&
      other.create == create &&
      other.read == read &&
      other.update == update &&
      other.deactivate == deactivate;

  @override
  int get hashCode => Object.hash(create, read, update, deactivate);
}

const String accessDeniedMessage =
    'No tienes permiso para realizar esta acción.';

class AccessDeniedException implements Exception {
  const AccessDeniedException();

  @override
  String toString() => accessDeniedMessage;
}

class AccessControl {
  final bool unrestricted;
  final Map<AppModule, PermissionSet> _permissions;

  const AccessControl._(this.unrestricted, this._permissions);

  static const AccessControl full = AccessControl._(true, {});

  factory AccessControl.restricted(Map<AppModule, PermissionSet> perms) =>
      AccessControl._(false, {
        for (final entry in perms.entries)
          if (entry.key.commercial) entry.key: entry.value,
      });

  PermissionSet permissionFor(AppModule module) {
    if (unrestricted) return PermissionSet.full;
    if (!module.commercial) return PermissionSet.none;
    final permission = _permissions[module] ?? PermissionSet.none;
    if (!module.readOnly) return permission;
    return PermissionSet(read: permission.read);
  }

  bool can(AppModule module, ModuleAction action) =>
      permissionFor(module).allows(action);

  bool canRead(AppModule module) => can(module, ModuleAction.read);

  bool canCreate(AppModule module) => can(module, ModuleAction.create);

  bool canUpdate(AppModule module) => can(module, ModuleAction.update);

  bool canDeactivate(AppModule module) => can(module, ModuleAction.deactivate);

  bool canEditOrDeactivate(AppModule module) =>
      canUpdate(module) || canDeactivate(module);

  bool canQuickAdd(AppModule target, AppModule from) =>
      canCreate(target) || (_quickAddForms.contains(from) && canCreate(from));

  List<String> get readableModuleNames => [
    for (final module in AppModule.values)
      if (canRead(module)) module.dbName,
  ];
}

const Set<AppModule> _quickAddForms = {
  AppModule.ventas,
  AppModule.compras,
  AppModule.eventos,
};
