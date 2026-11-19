import 'dart:convert';
import 'package:drift/drift.dart';
import '../../config/app_clock.dart';
import '../../config/date_formatters.dart';
import 'app_database.dart';

abstract final class AuditAction {
  static const create = 'create';
  static const update = 'update';
  static const deactivate = 'deactivate';
  static const activate = 'activate';
  static const cancel = 'cancel';
  static const reactivate = 'reactivate';
  static const stockUpdate = 'stock_update';
  static const priceUpdate = 'price_update';
  static const login = 'login';
  static const logout = 'logout';
  static const loginFailed = 'login_failed';
  static const lockout = 'lockout';
  static const block = 'block';
  static const unblock = 'unblock';
  static const passwordReset = 'password_reset';
  static const permissionsUpdate = 'permissions_update';
  static const twoFactorEnable = 'two_factor_enable';
  static const twoFactorDisable = 'two_factor_disable';
  static const themeUpdate = 'theme_update';
  static const biSettingsUpdate = 'bi_settings_update';
  static const export = 'export';

  static const all = [
    create,
    update,
    deactivate,
    activate,
    cancel,
    reactivate,
    stockUpdate,
    priceUpdate,
    login,
    logout,
    loginFailed,
    lockout,
    block,
    unblock,
    passwordReset,
    permissionsUpdate,
    twoFactorEnable,
    twoFactorDisable,
    themeUpdate,
    biSettingsUpdate,
    export,
  ];
}

abstract final class AuditModule {
  static const inventario = 'inventario';
  static const materiales = 'materiales';
  static const ventas = 'ventas';
  static const compras = 'compras';
  static const clientes = 'clientes';
  static const proveedores = 'proveedores';
  static const eventos = 'eventos';
  static const ubicaciones = 'ubicaciones';
  static const reportes = 'reportes';
  static const businessIntelligence = 'business_intelligence';
  static const usuarios = 'usuarios';
  static const ajustes = 'ajustes';
  static const sesion = 'sesion';

  static const all = [
    inventario,
    materiales,
    ventas,
    compras,
    clientes,
    proveedores,
    eventos,
    ubicaciones,
    reportes,
    businessIntelligence,
    usuarios,
    ajustes,
    sesion,
  ];
}

const Set<String> hiddenAuditFields = {'password_hash', 'mfa_secret'};

const Map<String, String> auditEntityModules = {
  'categories': AuditModule.inventario,
  'products': AuditModule.inventario,
  'materials': AuditModule.materiales,
  'product_materials': AuditModule.materiales,
  'sales': AuditModule.ventas,
  'purchases': AuditModule.compras,
  'clients': AuditModule.clientes,
  'suppliers': AuditModule.proveedores,
  'locations': AuditModule.ubicaciones,
  'events': AuditModule.eventos,
  'users': AuditModule.usuarios,
};

const Map<String, (String, String)> _linkedNames = {
  'client_id': ('clients', 'name'),
  'supplier_id': ('suppliers', 'name'),
  'category_id': ('categories', 'name'),
  'product_id': ('products', 'name'),
  'material_id': ('materials', 'name'),
  'event_id': ('events', 'name'),
  'unit_id': ('units', 'name'),
  'user_id': ('users', 'username'),
};

class AuditActor {
  int? userId;
  String? username;

  void set(int id, String name) {
    userId = id;
    username = name;
  }

  void clear() {
    userId = null;
    username = null;
  }
}

Map<String, Object?> cleanAuditRow(Map<String, Object?> row) => {
  for (final entry in row.entries)
    if (!hiddenAuditFields.contains(entry.key))
      entry.key: entry.value is Uint8List ? null : entry.value,
};

String locationLabel(Map<String, Object?> row) {
  final place = [row['city'], row['country']].whereType<String>().join(', ');
  final description = row['description'];
  return description is String && description.trim().isNotEmpty
      ? '$place · $description'
      : place;
}

String? _dateLabel(Object? seconds) => seconds is int
    ? formatDate(DateTime.fromMillisecondsSinceEpoch(seconds * 1000))
    : null;

String? auditRecordLabel(String? entity, Map<String, Object?>? values) {
  if (values == null) return null;
  final name = values['name'];
  switch (entity) {
    case 'users':
      return values['username'] as String?;
    case 'locations':
      return locationLabel(values);
    case 'sales':
      final client = values['client_name'];
      final date = _dateLabel(values['date']);
      return [
        if (date != null) 'Venta del $date',
        if (client is String) client,
      ].join(' · ');
    case 'purchases':
      final supplier = values['supplier_name'];
      final date = _dateLabel(values['date']);
      final description = values['description'];
      return [
        if (date != null) 'Compra del $date',
        if (description is String && description.isNotEmpty) description,
        if (supplier is String) supplier,
      ].join(' · ');
    case 'product_materials':
      return [
        values['product_name'],
        values['material_name'],
      ].whereType<String>().join(' · ');
  }
  return name is String ? name : null;
}

String deriveAuditAction(
  Map<String, Object?>? before,
  Map<String, Object?>? after,
) {
  if (before == null) return AuditAction.create;
  if (before['is_canceled'] == 0 && after?['is_canceled'] == 1) {
    return AuditAction.cancel;
  }
  if (before['is_canceled'] == 1 && after?['is_canceled'] == 0) {
    return AuditAction.reactivate;
  }
  if (before['is_active'] == 1 && after?['is_active'] == 0) {
    return AuditAction.deactivate;
  }
  if (before['is_active'] == 0 && after?['is_active'] == 1) {
    return AuditAction.activate;
  }
  return AuditAction.update;
}

String deriveStockAction(
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  for (final price in const ['price_per_unit', 'price_a', 'price_b']) {
    if (before[price] != after[price]) return AuditAction.priceUpdate;
  }
  return AuditAction.stockUpdate;
}

extension AuditLogWriter on AppDatabase {
  bool get auditing => auditActor.userId != null;

  Future<Map<String, Object?>> auditNames(Map<String, Object?> row) async {
    final result = cleanAuditRow(row);
    for (final entry in _linkedNames.entries) {
      final id = result[entry.key];
      if (id is! int) continue;
      final (table, column) = entry.value;
      final found = await customSelect(
        'SELECT "$column" AS v FROM "$table" WHERE id = ?',
        variables: [Variable.withInt(id)],
      ).getSingleOrNull();
      final name = found?.data['v'];
      if (name is String) {
        result['${entry.key.substring(0, entry.key.length - 3)}_name'] = name;
      }
    }
    final locationId = result['location_id'];
    if (locationId is int) {
      final found = await customSelect(
        'SELECT city, country, description FROM locations WHERE id = ?',
        variables: [Variable.withInt(locationId)],
      ).getSingleOrNull();
      if (found != null) result['location_name'] = locationLabel(found.data);
    }
    return result;
  }

  Future<Map<String, Object?>?> auditRow(String table, int? id) async {
    if (!auditing || id == null) return null;
    final rows = await customSelect(
      'SELECT * FROM "$table" WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    return rows.isEmpty ? null : auditNames(rows.first.data);
  }

  Future<Map<String, Object?>?> auditRowWithItems(
    String table,
    int? id,
    String itemsTable,
    String foreignKey,
  ) async {
    final row = await auditRow(table, id);
    if (row == null) return null;
    final items = await customSelect(
      'SELECT * FROM "$itemsTable" WHERE "$foreignKey" = ? ORDER BY id',
      variables: [Variable.withInt(id!)],
    ).get();
    return {
      ...row,
      'items': [for (final item in items) await auditNames(item.data)],
    };
  }

  Future<Map<String, Object?>?> auditPermissions(int userId) async {
    if (!auditing) return null;
    final rows = await customSelect(
      'SELECT m.name AS module, p.can_read, p.can_create, p.can_update, '
      'p.can_delete FROM module_permissions p '
      'JOIN modules m ON m.id = p.module_id WHERE p.user_id = ? '
      'ORDER BY m.id',
      variables: [Variable.withInt(userId)],
    ).get();
    return {
      for (final row in rows)
        row.read<String>('module'): {
          'can_read': row.data['can_read'],
          'can_create': row.data['can_create'],
          'can_update': row.data['can_update'],
          'can_delete': row.data['can_delete'],
        },
    };
  }

  Future<void> recordAudit({
    required String module,
    required String action,
    String? entity,
    int? recordId,
    String? label,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    int? userId,
    String? actorName,
    bool always = false,
  }) async {
    final actor = userId ?? auditActor.userId;
    if (actor == null && !always) return;
    final name =
        actorName ?? (actor == auditActor.userId ? auditActor.username : null);
    await into(auditLogs).insert(
      AuditLogsCompanion.insert(
        userId: Value(actor),
        actorName: Value(name),
        moduleName: module,
        action: action,
        entityType: Value(entity),
        recordId: Value(recordId),
        recordLabel: Value(
          label ??
              auditRecordLabel(entity, after) ??
              auditRecordLabel(entity, before),
        ),
        oldValue: Value(before == null ? null : jsonEncode(before)),
        newValue: Value(after == null ? null : jsonEncode(after)),
        createdAt: Value(appNow()),
      ),
    );
  }

  Future<void> recordChange({
    required String module,
    required String entity,
    required int id,
    required Map<String, Object?>? before,
    String? action,
    String? label,
    Future<Map<String, Object?>?> Function()? after,
  }) async {
    if (!auditing) return;
    final current = after != null ? await after() : await auditRow(entity, id);
    await recordAudit(
      module: module,
      action: action ?? deriveAuditAction(before, current),
      entity: entity,
      recordId: id,
      label: label,
      before: before,
      after: current,
    );
  }

  Future<void> auditedStockUpdate(
    String table,
    int id,
    Future<void> Function() write,
  ) async {
    final before = await auditRow(table, id);
    await write();
    if (before == null) return;
    final after = await auditRow(table, id);
    if (after == null || jsonEncode(before) == jsonEncode(after)) return;
    await recordAudit(
      module: auditEntityModules[table]!,
      action: deriveStockAction(before, after),
      entity: table,
      recordId: id,
      before: before,
      after: after,
    );
  }

  Future<int> auditedInsert(String table, Future<int> Function() insert) async {
    final id = await insert();
    if (auditing) {
      await recordChange(
        module: auditEntityModules[table]!,
        entity: table,
        id: id,
        before: null,
      );
    }
    return id;
  }
}
