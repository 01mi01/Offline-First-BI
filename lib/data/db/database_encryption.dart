import 'dart:io';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'database_key_store.dart';

class DatabaseUnavailableException implements Exception {
  final String reason;

  const DatabaseUnavailableException(this.reason);

  @override
  String toString() => 'DatabaseUnavailableException: $reason';
}

class DatabaseKeyMissingException extends DatabaseUnavailableException {
  const DatabaseKeyMissingException()
    : super('the database is encrypted and its key is not in secure storage');
}

class DatabaseCipherUnavailableException extends DatabaseUnavailableException {
  const DatabaseCipherUnavailableException()
    : super('the encryption library is not available');
}

class DatabaseMigrationException extends DatabaseUnavailableException {
  const DatabaseMigrationException()
    : super('the encrypted copy did not match the original database');
}

enum DatabaseFileState { missing, plain, encrypted }

const String _plainHeader = 'SQLite format 3\u0000';

DatabaseFileState databaseFileState(File file) {
  if (!file.existsSync() || file.lengthSync() == 0) {
    return DatabaseFileState.missing;
  }
  final handle = file.openSync();
  try {
    final header = String.fromCharCodes(handle.readSync(_plainHeader.length));
    return header == _plainHeader
        ? DatabaseFileState.plain
        : DatabaseFileState.encrypted;
  } finally {
    handle.closeSync();
  }
}

String _keyLiteral(String key) => "'x''$key'''";

void unlockDatabase(Database database, String key) {
  database.execute('PRAGMA key = ${_keyLiteral(key)}');
  database.select('SELECT count(*) FROM sqlite_master');
}

abstract class DatabaseCipher {
  bool get isAvailable;

  void exportEncrypted(File plain, File target, String key);

  String fingerprint(File file, String? key);
}

Future<void> loadSqlCipher() async {
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
}

class SqlCipherDatabaseCipher implements DatabaseCipher {
  const SqlCipherDatabaseCipher();

  Database _open(File file, String? key) {
    final database = sqlite3.open(file.path);
    try {
      if (key != null) {
        unlockDatabase(database, key);
      } else {
        database.select('SELECT count(*) FROM sqlite_master');
      }
      return database;
    } catch (_) {
      database.dispose();
      rethrow;
    }
  }

  @override
  bool get isAvailable {
    final database = sqlite3.openInMemory();
    try {
      final rows = database.select('PRAGMA cipher_version');
      if (rows.isEmpty) return false;
      final version = rows.first.values.first;
      return version is String && version.isNotEmpty;
    } finally {
      database.dispose();
    }
  }

  @override
  void exportEncrypted(File plain, File target, String key) {
    final database = _open(plain, null);
    try {
      final version = database.userVersion;
      final path = target.path.replaceAll("'", "''");
      database.execute(
        "ATTACH DATABASE '$path' AS encrypted KEY ${_keyLiteral(key)}",
      );
      database.select("SELECT sqlcipher_export('encrypted')");
      database.execute('PRAGMA encrypted.user_version = $version');
      database.execute('DETACH DATABASE encrypted');
    } finally {
      database.dispose();
    }
  }

  @override
  String fingerprint(File file, String? key) {
    final database = _open(file, key);
    try {
      final tables = database
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .map((row) => row['name'] as String);
      return [
        'v${database.userVersion}',
        for (final table in tables)
          '$table:${database.select('SELECT count(*) AS c FROM "$table"').first['c']}',
      ].join('|');
    } finally {
      database.dispose();
    }
  }
}

class EncryptedDatabaseOpener {
  final DatabaseKeyStore keyStore;
  final DatabaseCipher cipher;

  const EncryptedDatabaseOpener({required this.keyStore, required this.cipher});

  static File temporaryFile(File file) => File('${file.path}.encrypting');

  static File backupFile(File file) => File('${file.path}.plain-backup');

  Future<String> prepare(File file) async {
    if (!cipher.isAvailable) throw const DatabaseCipherUnavailableException();
    _recover(file);
    switch (databaseFileState(file)) {
      case DatabaseFileState.encrypted:
        final key = await keyStore.readKey();
        if (!isValidDatabaseKey(key)) throw const DatabaseKeyMissingException();
        return key!;
      case DatabaseFileState.missing:
        return _storedOrNewKey();
      case DatabaseFileState.plain:
        final key = await _storedOrNewKey();
        _encryptInPlace(file, key);
        return key;
    }
  }

  Future<String> _storedOrNewKey() async {
    final stored = await keyStore.readKey();
    if (isValidDatabaseKey(stored)) return stored!;
    final created = generateDatabaseKey();
    await keyStore.writeKey(created);
    if (await keyStore.readKey() != created) {
      throw const DatabaseKeyMissingException();
    }
    return created;
  }

  void _recover(File file) {
    final backup = backupFile(file);
    if (backup.existsSync()) {
      if (!file.existsSync()) {
        backup.renameSync(file.path);
      } else if (databaseFileState(file) == DatabaseFileState.encrypted) {
        backup.deleteSync();
      }
    }
    final temporary = temporaryFile(file);
    if (temporary.existsSync()) temporary.deleteSync();
  }

  void _encryptInPlace(File file, String key) {
    final temporary = temporaryFile(file);
    final backup = backupFile(file);
    final expected = cipher.fingerprint(file, null);
    var verified = false;
    try {
      cipher.exportEncrypted(file, temporary, key);
      verified =
          databaseFileState(temporary) == DatabaseFileState.encrypted &&
          cipher.fingerprint(temporary, key) == expected;
    } catch (_) {
      verified = false;
    }
    if (!verified) {
      if (temporary.existsSync()) temporary.deleteSync();
      throw const DatabaseMigrationException();
    }
    for (final suffix in const ['-journal', '-wal', '-shm']) {
      final sidecar = File('${file.path}$suffix');
      if (sidecar.existsSync()) sidecar.deleteSync();
    }
    file.renameSync(backup.path);
    temporary.renameSync(file.path);
    backup.deleteSync();
  }
}
