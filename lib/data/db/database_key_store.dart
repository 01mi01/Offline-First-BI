import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class DatabaseKeyStore {
  Future<String?> readKey();
  Future<void> writeKey(String key);
}

class SecureDatabaseKeyStore implements DatabaseKeyStore {
  static const String entryName = 'database_encryption_key';

  final FlutterSecureStorage storage;

  const SecureDatabaseKeyStore([
    this.storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    ),
  ]);

  @override
  Future<String?> readKey() => storage.read(key: entryName);

  @override
  Future<void> writeKey(String key) =>
      storage.write(key: entryName, value: key);
}

const int databaseKeyBytes = 32;

final RegExp _keyFormat = RegExp('^[0-9a-f]{${databaseKeyBytes * 2}}\$');

String generateDatabaseKey([Random? random]) {
  final source = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < databaseKeyBytes; i++) {
    buffer.write(source.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

bool isValidDatabaseKey(String? key) => key != null && _keyFormat.hasMatch(key);
