import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../../config/app_clock.dart';

class ImageStorage {
  static const String folderName = 'images';

  final Future<Directory> Function() _baseDirectory;

  ImageStorage({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final _random = Random();

  Future<Directory> imagesDirectory() async {
    final base = await _baseDirectory();
    final dir = Directory(p.join(base.path, folderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<bool> isPermanent(String path) async {
    final dir = await imagesDirectory();
    return p.isWithin(dir.path, path);
  }

  Future<String> save(String sourcePath) async {
    if (await isPermanent(sourcePath)) return sourcePath;
    final dir = await imagesDirectory();
    final extension = p.extension(sourcePath);
    final name =
        '${appNow().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}'
        '$extension';
    final copy = await File(sourcePath).copy(p.join(dir.path, name));
    return copy.path;
  }

  Future<void> deleteIfManaged(String? path) async {
    if (path == null || !await isPermanent(path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<int> migrateLegacyImages(AppDatabase db) async {
    var moved = 0;

    Future<String?> relocate(String? path) async {
      if (path == null || path.isEmpty) return null;
      try {
        if (await isPermanent(path)) return null;
        if (!await File(path).exists()) return null;
        return await save(path);
      } catch (_) {
        return null;
      }
    }

    for (final product in await db.select(db.products).get()) {
      final newPath = await relocate(product.image);
      if (newPath == null) continue;
      await (db.update(db.products)..where((t) => t.id.equals(product.id)))
          .write(ProductsCompanion(image: Value(newPath)));
      moved++;
    }
    for (final category in await db.select(db.categories).get()) {
      final newPath = await relocate(category.image);
      if (newPath == null) continue;
      await (db.update(db.categories)..where((t) => t.id.equals(category.id)))
          .write(CategoriesCompanion(image: Value(newPath)));
      moved++;
    }
    return moved;
  }
}
