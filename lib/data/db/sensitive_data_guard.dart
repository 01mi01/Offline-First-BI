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

class SensitiveDataLockedException implements Exception {
  const SensitiveDataLockedException();

  @override
  String toString() => 'SensitiveDataLockedException: no active session';
}

final Object _systemAccess = Object();

class SensitiveDataGate {
  bool _sessionActive = false;

  bool get sessionActive => _sessionActive;

  bool get isOpen => _sessionActive || Zone.current[_systemAccess] == true;

  void openSession() => _sessionActive = true;

  void closeSession() => _sessionActive = false;

  Future<T> runAsSystem<T>(Future<T> Function() action) =>
      runZoned(action, zoneValues: {_systemAccess: true});
}

final RegExp _sensitiveStatement = RegExp(
  '\\b(${sensitiveTables.join('|')})\\b',
  caseSensitive: false,
);

bool readsSensitiveTable(String statement) =>
    _sensitiveStatement.hasMatch(statement);

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
    return executor.runSelect(statement, args);
  }
}
