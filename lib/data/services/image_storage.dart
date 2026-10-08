import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../../config/app_clock.dart';

// Almacenamiento permanente de las imágenes de productos y categorías.
//
// El selector de imágenes deja la foto elegida en el directorio de caché de la
// aplicación, que Android puede vaciar en cualquier momento sin que la persona
// haga nada. Por eso, al elegir una imagen se copia a una carpeta propia dentro
// del directorio de documentos de la aplicación (el mismo donde vive la base de
// datos) y es esa ruta la que se guarda en la base de datos.
class ImageStorage {
  /// Nombre de la carpeta de imágenes dentro del directorio base.
  static const String folderName = 'images';

  final Future<Directory> Function() _baseDirectory;

  /// [baseDirectory] permite a las pruebas usar una carpeta temporal; por
  /// defecto es el directorio de documentos de la aplicación (no la caché).
  ImageStorage({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final _random = Random();

  /// Carpeta permanente donde se guardan las imágenes (se crea si falta).
  Future<Directory> imagesDirectory() async {
    final base = await _baseDirectory();
    final dir = Directory(p.join(base.path, folderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// true si [path] ya está dentro de la carpeta permanente de imágenes.
  Future<bool> isPermanent(String path) async {
    final dir = await imagesDirectory();
    return p.isWithin(dir.path, path);
  }

  /// Copia la imagen en [sourcePath] a la carpeta permanente y devuelve la
  /// nueva ruta, que es la que se debe guardar en la base de datos. Si ya está
  /// en la carpeta permanente devuelve la misma ruta sin copiarla.
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

  /// Borra una imagen de la carpeta permanente (p. ej. una que se eligió pero
  /// no llegó a guardarse). Nunca toca archivos fuera de esa carpeta.
  Future<void> deleteIfManaged(String? path) async {
    if (path == null || !await isPermanent(path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Traslada a la carpeta permanente las imágenes que aún apuntan a otra
  /// ubicación (típicamente la caché, de versiones anteriores). Si el archivo
  /// original ya no existe la referencia se deja tal cual: la interfaz muestra
  /// un marcador de posición en su lugar. Un fallo con una imagen no impide
  /// migrar las demás. Devuelve cuántas imágenes se trasladaron.
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
