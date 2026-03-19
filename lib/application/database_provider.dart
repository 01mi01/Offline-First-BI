import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db/app_database.dart';

// Proveedor global de la base de datos
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

