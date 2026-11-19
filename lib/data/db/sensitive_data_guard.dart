import 'dart:async';
import 'package:drift/drift.dart';

const List<String> sensitiveTables = [
  'sales',
  'sale_items',
  'purchases',
  'purchase_items',
  'products',
  'materials',
  'product_materials',
  'clients',
  'suppliers',
];

const String auditTable = 'audit_logs';

class SensitiveDataLockedException implements Exception {
  const SensitiveDataLockedException();

  @override
  String toString() => 'SensitiveDataLockedException: no active session';
}

final Object _systemAccess = Object();

class SensitiveDataGate {
  bool _sessionActive = false;
  bool _auditReader = false;

  bool get sessionActive => _sessionActive;

  bool get _system => Zone.current[_systemAccess] == true;

  bool get isOpen => _sessionActive || _system;

  bool get canReadAudit => (_sessionActive && _auditReader) || _system;

  void openSession({bool canReadAudit = false}) {
    _sessionActive = true;
    _auditReader = canReadAudit;
  }

  void closeSession() {
    _sessionActive = false;
    _auditReader = false;
  }

  Future<T> runAsSystem<T>(Future<T> Function() action) =>
      runZoned(action, zoneValues: {_systemAccess: true});
}

final RegExp _sensitiveStatement = RegExp(
  '\\b(${sensitiveTables.join('|')})\\b',
  caseSensitive: false,
);

bool readsSensitiveTable(String statement) =>
    _sensitiveStatement.hasMatch(statement);

final RegExp _auditStatement = RegExp(
  '\\b$auditTable\\b',
  caseSensitive: false,
);

bool readsAuditTable(String statement) => _auditStatement.hasMatch(statement);

class SensitiveDataGuard extends QueryInterceptor {
  final SensitiveDataGate gate;

  SensitiveDataGuard(this.gate);

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      gate.runAsSystem(() => executor.ensureOpen(user));

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (!gate.isOpen && readsSensitiveTable(statement)) {
      return Future.error(const SensitiveDataLockedException());
    }
    if (!gate.canReadAudit && readsAuditTable(statement)) {
      return Future.error(const SensitiveDataLockedException());
    }
    return executor.runSelect(statement, args);
  }
}
