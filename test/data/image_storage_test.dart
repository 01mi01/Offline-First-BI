import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/services/image_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// path_provider simulado con las carpetas separadas, como en Android: la caché
// (que el sistema puede vaciar) y los documentos (permanentes).
class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String cachePath;
  final String documentsPath;

  _FakePathProvider({required this.cachePath, required this.documentsPath});

  @override
  Future<String?> getTemporaryPath() async => cachePath;

  @override
  Future<String?> getApplicationCachePath() async => cachePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => documentsPath;
}

void main() {
  late Directory root;
  late Directory cache;
  late Directory documents;
  late AppDatabase db;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('image_storage_test');
    cache = await Directory(p.join(root.path, 'cache')).create();
    documents = await Directory(p.join(root.path, 'documents')).create();
    PathProviderPlatform.instance = _FakePathProvider(
      cachePath: cache.path,
      documentsPath: documents.path,
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  // Imagen como la deja el selector: en la caché.
  Future<File> cachedImage(String name, [String content = 'pixels']) async {
    final dir = await Directory(p.join(cache.path, 'picker-uuid')).create();
    return File(p.join(dir.path, name)).writeAsString(content).then((f) => f);
  }

  group('save', () {
    test('the saved image lives in the permanent documents directory, not in the cache', () async {
      final picked = await cachedImage('foto.png');

      // ImageStorage() sin argumentos = la configuración real de la app.
      final savedPath = await ImageStorage().save(picked.path);

      expect(p.isWithin(documents.path, savedPath), isTrue);
      expect(p.isWithin(cache.path, savedPath), isFalse);
      expect(savedPath, isNot(contains('cache')));
      expect(p.extension(savedPath), '.png');
      expect(await File(savedPath).readAsString(), 'pixels');
    });

    test('the image survives the cache being cleared', () async {
      final picked = await cachedImage('foto.jpg');
      final savedPath = await ImageStorage().save(picked.path);

      // Android vacía la caché por su cuenta.
      await cache.delete(recursive: true);

      expect(await File(picked.path).exists(), isFalse);
      expect(await File(savedPath).exists(), isTrue);
    });

    test('two images with the same file name do not overwrite each other', () async {
      final storage = ImageStorage();
      final first = await storage.save((await cachedImage('image.png', 'uno')).path);
      final second = await storage.save((await cachedImage('image.png', 'dos')).path);

      expect(first, isNot(second));
      expect(await File(first).readAsString(), 'uno');
      expect(await File(second).readAsString(), 'dos');
    });

    test('an image that is already in the permanent folder is returned as is', () async {
      final storage = ImageStorage();
      final savedPath = await storage.save((await cachedImage('a.png')).path);

      expect(await storage.save(savedPath), savedPath);
      expect(await storage.imagesDirectory().then((d) => d.listSync()), hasLength(1));
    });

    test('a custom base directory is honored (for tests)', () async {
      final other = await Directory(p.join(root.path, 'other')).create();
      final storage = ImageStorage(baseDirectory: () async => other);

      final savedPath = await storage.save((await cachedImage('a.png')).path);

      expect(p.isWithin(p.join(other.path, ImageStorage.folderName), savedPath), isTrue);
    });
  });

  group('deleteIfManaged', () {
    test('deletes a saved copy, and never a file outside the permanent folder', () async {
      final storage = ImageStorage();
      final picked = await cachedImage('a.png');
      final savedPath = await storage.save(picked.path);

      await storage.deleteIfManaged(picked.path); // en la caché: no se toca
      expect(await picked.exists(), isTrue);

      await storage.deleteIfManaged(savedPath);
      expect(await File(savedPath).exists(), isFalse);

      await storage.deleteIfManaged(null); // sin imagen: no falla
    });
  });

  group('migrateLegacyImages', () {
    test('moves product and category images out of the cache and updates the database', () async {
      final productImage = await cachedImage('producto.png', 'p');
      final categoryImage = await cachedImage('categoria.png', 'c');
      final productId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Estuches',
          priceA: 10,
          priceB: 8,
          image: Value(productImage.path),
        ),
      );
      final categoryId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'Miniaturas',
          image: Value(categoryImage.path),
        ),
      );

      final moved = await ImageStorage().migrateLegacyImages(db);

      expect(moved, 2);
      final product = await (db.select(db.products)
            ..where((t) => t.id.equals(productId)))
          .getSingle();
      final category = await (db.select(db.categories)
            ..where((t) => t.id.equals(categoryId)))
          .getSingle();
      expect(p.isWithin(documents.path, product.image!), isTrue);
      expect(p.isWithin(documents.path, category.image!), isTrue);
      expect(await File(product.image!).readAsString(), 'p');
      expect(await File(category.image!).readAsString(), 'c');

      // Aunque la caché se vacíe, las imágenes siguen ahí.
      await cache.delete(recursive: true);
      expect(await File(product.image!).exists(), isTrue);
    });

    test('an image whose file is already gone is left alone, without failing', () async {
      final gone = p.join(cache.path, 'ya-no-existe.png');
      final productId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Estuches',
          priceA: 10,
          priceB: 8,
          image: Value(gone),
        ),
      );

      final moved = await ImageStorage().migrateLegacyImages(db);

      expect(moved, 0);
      final product = await (db.select(db.products)
            ..where((t) => t.id.equals(productId)))
          .getSingle();
      expect(product.image, gone); // la interfaz muestra un marcador
    });

    test('images already in the permanent folder and records without image are untouched, and running twice moves nothing new', () async {
      final storage = ImageStorage();
      final savedPath = await storage.save((await cachedImage('a.png')).path);
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Tote bag negra',
          priceA: 1,
          priceB: 1,
          image: Value(savedPath),
        ),
      );
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Libro',
          priceA: 1,
          priceB: 1,
        ),
      );
      final legacy = await cachedImage('b.png');
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Libros', image: Value(legacy.path)),
      );

      expect(await storage.migrateLegacyImages(db), 1);
      expect(await storage.migrateLegacyImages(db), 0);

      final products = await db.select(db.products).get();
      expect(products.firstWhere((x) => x.name == 'Tote bag negra').image, savedPath);
      expect(products.firstWhere((x) => x.name == 'Libro').image, isNull);
    });
  });
}
