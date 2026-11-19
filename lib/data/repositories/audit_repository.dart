import 'dart:convert';
import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../db/audit_log.dart';
import '../../models/bi_config.dart';

class AuditEntry {
  final int id;
  final int? userId;
  final String? username;
  final String module;
  final String? recordLabel;
  final String action;
  final String? entity;
  final int? recordId;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;
  final DateTime createdAt;

  const AuditEntry({
    required this.id,
    required this.userId,
    required this.username,
    required this.module,
    required this.recordLabel,
    required this.action,
    required this.entity,
    required this.recordId,
    required this.before,
    required this.after,
    required this.createdAt,
  });
}

class AuditQuery {
  final int? userId;
  final String? module;
  final String? action;
  final DateTime? from;
  final DateTime? to;

  const AuditQuery({this.userId, this.module, this.action, this.from, this.to});

  @override
  bool operator ==(Object other) =>
      other is AuditQuery &&
      other.userId == userId &&
      other.module == module &&
      other.action == action &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(userId, module, action, from, to);
}

class AuditUser {
  final int id;
  final String username;

  const AuditUser(this.id, this.username);
}

Map<String, Object?>? _decode(String? value) {
  if (value == null) return null;
  final decoded = jsonDecode(value);
  return decoded is Map<String, Object?> ? decoded : null;
}

class AuditRepository {
  final AppDatabase database;

  AuditRepository(this.database);

  Future<List<AuditEntry>> query(
    AuditQuery filters, {
    required int limit,
  }) async {
    final logs = database.auditLogs;
    final users = database.users;
    final select = database.select(logs).join([
      leftOuterJoin(users, users.id.equalsExp(logs.userId)),
    ]);
    final conditions = <Expression<bool>>[
      if (filters.userId != null) logs.userId.equals(filters.userId!),
      if (filters.module != null) logs.moduleName.equals(filters.module!),
      if (filters.action != null) logs.action.equals(filters.action!),
      if (filters.from != null)
        logs.createdAt.isBiggerOrEqualValue(filters.from!),
      if (filters.to != null) logs.createdAt.isSmallerThanValue(filters.to!),
    ];
    if (conditions.isNotEmpty) {
      select.where(conditions.reduce((a, b) => a & b));
    }
    select
      ..orderBy([OrderingTerm.desc(logs.createdAt), OrderingTerm.desc(logs.id)])
      ..limit(limit);
    final rows = await select.get();
    return [
      for (final row in rows)
        _toEntry(row.readTable(logs), row.readTableOrNull(users)?.username),
    ];
  }

  AuditEntry _toEntry(AuditLog log, String? username) => AuditEntry(
    id: log.id,
    userId: log.userId,
    username: log.actorName ?? username,
    module: log.moduleName,
    recordLabel: log.recordLabel,
    action: log.action,
    entity: log.entityType,
    recordId: log.recordId,
    before: _decode(log.oldValue),
    after: _decode(log.newValue),
    createdAt: log.createdAt,
  );

  Future<List<AuditUser>> users() async {
    final rows = await (database.select(
      database.users,
    )..orderBy([(u) => OrderingTerm.asc(u.username)])).get();
    return [for (final row in rows) AuditUser(row.id, row.username)];
  }

  Future<Map<String, Object?>> _biSummary(BiConfig config) async {
    final f = config.filters;
    final radar = <String>[];
    for (final id in config.radarProductIds) {
      final row = await database.auditNames({'product_id': id});
      final name = row['product_name'];
      if (name is String) radar.add(name);
    }
    final base = await database.auditNames({
      'category_id': f.categoryId,
      'product_id': f.productId,
      'event_id': f.eventId,
      'location_id': f.locationId,
      'client_id': f.clientId,
      'supplier_id': f.supplierId,
    });
    return {
      'start_date': f.startDate == null
          ? null
          : f.startDate!.millisecondsSinceEpoch ~/ 1000,
      'end_date': f.endDate == null
          ? null
          : f.endDate!.millisecondsSinceEpoch ~/ 1000,
      for (final entry in base.entries)
        if (entry.value != null) entry.key: entry.value,
      'price_type': f.priceType,
      'country': f.country,
      'city': f.city,
      'purchase_kind': f.purchaseKind.name,
      'indicators': [
        for (final indicator in BiIndicator.values)
          if (config.indicators.contains(indicator)) indicator.title,
      ].join(', '),
      'chart_types': [
        for (final entry in config.chartTypes.entries)
          '${entry.key.title}: ${entry.value.label}',
      ].join(', '),
      'metrics': [
        for (final entry in config.metrics.entries)
          '${entry.key.title}: ${entry.value}',
      ].join(', '),
      'no_movement_days': config.noMovementDays,
      'radar_products': radar.join(', '),
    };
  }

  Future<void> recordBiSettings(BiConfig before, BiConfig after) async {
    if (!database.auditing) return;
    final old = await _biSummary(before);
    final current = await _biSummary(after);
    if (jsonEncode(old) == jsonEncode(current)) return;
    await database.recordAudit(
      module: AuditModule.businessIntelligence,
      action: AuditAction.biSettingsUpdate,
      entity: 'bi_settings',
      label: 'Configuración de Business Intelligence',
      before: old,
      after: current,
    );
  }

  Future<void> recordExport({
    required String report,
    required String format,
    required String title,
    required String fileName,
    required int rows,
  }) => database.recordAudit(
    module: AuditModule.reportes,
    action: AuditAction.export,
    entity: 'report',
    label: title,
    after: {
      'report': report,
      'format': format,
      'title': title,
      'file_name': fileName,
      'rows': rows,
    },
  );
}
