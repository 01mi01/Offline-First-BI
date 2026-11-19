import '../config/date_formatters.dart';
import '../data/db/audit_log.dart';
import '../models/app_role.dart';

const Map<String, String> auditActionLabels = {
  AuditAction.create: 'Creación',
  AuditAction.update: 'Actualización',
  AuditAction.deactivate: 'Desactivación',
  AuditAction.activate: 'Reactivación',
  AuditAction.cancel: 'Cancelación',
  AuditAction.reactivate: 'Restauración',
  AuditAction.stockUpdate: 'Ajuste de stock',
  AuditAction.priceUpdate: 'Actualización de precio',
  AuditAction.themeUpdate: 'Cambio de tema',
  AuditAction.biSettingsUpdate: 'Cambio de configuración',
  AuditAction.login: 'Inicio de sesión',
  AuditAction.logout: 'Cierre de sesión',
  AuditAction.loginFailed: 'Inicio de sesión fallido',
  AuditAction.lockout: 'Bloqueo automático',
  AuditAction.block: 'Bloqueo',
  AuditAction.unblock: 'Desbloqueo',
  AuditAction.passwordReset: 'Restablecimiento de contraseña',
  AuditAction.permissionsUpdate: 'Cambio de permisos',
  AuditAction.twoFactorEnable: 'Activación de dos pasos',
  AuditAction.twoFactorDisable: 'Desactivación de dos pasos',
  AuditAction.export: 'Exportación',
};

const Map<String, String> auditModuleLabels = {
  AuditModule.inventario: 'Productos y categorías',
  AuditModule.materiales: 'Materiales',
  AuditModule.ventas: 'Ventas',
  AuditModule.compras: 'Compras',
  AuditModule.clientes: 'Clientes',
  AuditModule.proveedores: 'Proveedores',
  AuditModule.eventos: 'Eventos',
  AuditModule.ubicaciones: 'Ubicaciones',
  AuditModule.reportes: 'Reportes',
  AuditModule.businessIntelligence: 'Business Intelligence',
  AuditModule.usuarios: 'Usuarios',
  AuditModule.ajustes: 'Ajustes',
  AuditModule.sesion: 'Sesión',
};

const Map<String, String> auditEntityLabels = {
  'categories': 'Categoría',
  'products': 'Producto',
  'materials': 'Material',
  'product_materials': 'Uso de material',
  'sales': 'Venta',
  'purchases': 'Compra',
  'clients': 'Cliente',
  'suppliers': 'Proveedor',
  'locations': 'Ubicación',
  'events': 'Evento',
  'users': 'Usuario',
  'module_permissions': 'Permisos',
  'report': 'Reporte',
  'bi_settings': 'Configuración',
};

const Map<String, String> auditFieldLabels = {
  'client_name': 'Cliente',
  'supplier_name': 'Proveedor',
  'category_name': 'Categoría',
  'product_name': 'Producto',
  'material_name': 'Material',
  'event_name': 'Evento',
  'location_name': 'Ubicación',
  'unit_name': 'Unidad',
  'user_name': 'Usuario',
  'theme': 'Tema',
  'indicators': 'Indicadores',
  'chart_types': 'Tipos de gráfico',
  'metrics': 'Métricas',
  'no_movement_days': 'Días sin movimiento',
  'radar_products': 'Productos seguidos',
  'purchase_kind': 'Tipo de compra',
  'id': 'Identificador',
  'name': 'Nombre',
  'username': 'Usuario',
  'email': 'Correo',
  'role': 'Rol',
  'description': 'Descripción',
  'image': 'Imagen',
  'contact_info': 'Contacto',
  'city': 'Ciudad',
  'country': 'País',
  'notes': 'Notas',
  'category_id': 'Categoría',
  'price_a': 'Precio A',
  'price_b': 'Precio B',
  'production_cost': 'Costo de producción',
  'stock': 'Stock',
  'unit_id': 'Unidad',
  'price_per_unit': 'Precio por unidad',
  'product_id': 'Producto',
  'material_id': 'Material',
  'quantity_used': 'Cantidad usada',
  'client_id': 'Cliente',
  'supplier_id': 'Proveedor',
  'location_id': 'Ubicación',
  'event_id': 'Evento',
  'sale_id': 'Venta',
  'purchase_id': 'Compra',
  'total_amount': 'Total',
  'discount': 'Descuento',
  'final_amount': 'Total final',
  'quantity': 'Cantidad',
  'unit_price': 'Precio unitario',
  'price_type': 'Tipo de precio',
  'subtotal': 'Subtotal',
  'is_material': 'Compra de materiales',
  'date': 'Fecha',
  'start_date': 'Fecha de inicio',
  'end_date': 'Fecha de fin',
  'is_active': 'Activo',
  'is_canceled': 'Cancelado',
  'canceled_at': 'Fecha de cancelación',
  'mfa_enabled': 'Verificación en dos pasos',
  'two_factor': 'Verificación en dos pasos',
  'dark_mode': 'Modo oscuro',
  'sincronizado': 'Sincronizado',
  'supabase_id': 'Identificador en la nube',
  'created_at': 'Fecha de creación',
  'updated_at': 'Fecha de actualización',
  'reason': 'Motivo',
  'cause': 'Causa',
  'report': 'Reporte',
  'format': 'Formato',
  'title': 'Título',
  'file_name': 'Archivo',
  'rows': 'Registros',
  'items': 'Detalle',
  'can_read': 'Lectura',
  'can_create': 'Creación',
  'can_update': 'Actualización',
  'can_delete': 'Desactivación',
};

const Set<String> _flagFields = {
  'is_active',
  'is_canceled',
  'is_material',
  'mfa_enabled',
  'two_factor',
  'dark_mode',
  'sincronizado',
  'can_read',
  'can_create',
  'can_update',
  'can_delete',
};

const Set<String> _dateFields = {
  'date',
  'start_date',
  'end_date',
  'canceled_at',
  'created_at',
  'updated_at',
};

const Set<String> _codeFields = {
  'reason',
  'cause',
  'report',
  'format',
  'theme',
  'purchase_kind',
};

bool isHiddenAuditField(String field) =>
    field == 'id' || field.endsWith('_id');

const Map<String, String> _codeLabels = {
  'light': 'Claro',
  'dark': 'Oscuro',
  'system': 'Tema del teléfono',
  'all': 'Todas',
  'material': 'Materiales',
  'expense': 'Gastos generales',
  'unknown_user': 'Usuario inexistente',
  'blocked_user': 'Usuario bloqueado',
  'wrong_password': 'Contraseña incorrecta',
  'wrong_code': 'Código de verificación incorrecto',
  'password': 'Cinco contraseñas incorrectas seguidas',
  'verification_code': 'Cinco códigos de verificación incorrectos seguidos',
  'ventas': 'Ventas',
  'compras': 'Compras',
  'pdf': 'PDF',
  'excel': 'Excel',
};

const Map<String, String> auditModuleNameLabels = {
  'inventario': 'Productos y categorías',
  'materiales': 'Materiales',
  'ventas': 'Ventas',
  'compras': 'Compras',
  'clientes': 'Clientes',
  'proveedores': 'Proveedores',
  'eventos': 'Eventos',
  'ubicaciones': 'Ubicaciones',
  'reportes': 'Reportes',
  'business_intelligence': 'Business Intelligence',
  'auditoria': 'Auditoría',
  'usuarios': 'Usuarios',
};

String auditActionLabel(String action) => auditActionLabels[action] ?? action;

String auditModuleLabel(String module) => auditModuleLabels[module] ?? module;

String auditEntityLabel(String? entity) =>
    entity == null ? '—' : auditEntityLabels[entity] ?? entity;

String auditFieldLabel(String field) =>
    auditFieldLabels[field] ?? auditModuleNameLabels[field] ?? field;

String auditValueText(String field, Object? value) {
  if (value == null) return '—';
  if (_flagFields.contains(field) && value is num) {
    return value == 0 ? 'No' : 'Sí';
  }
  if (_dateFields.contains(field) && value is num) {
    return formatDateTime(
      DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000),
    );
  }
  if (field == 'role' && value is String) {
    return AppRole.fromDbName(value).label;
  }
  if (_codeFields.contains(field) && value is String) {
    return _codeLabels[value] ?? value;
  }
  if (value is double) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }
  return value.toString();
}
