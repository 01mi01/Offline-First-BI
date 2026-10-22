import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/image_storage_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/services/image_storage.dart';
import 'package:offline_first_bi/models/product_model.dart';
import 'package:offline_first_bi/presentation/dialogs/category_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/product_dialog.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'package:path/path.dart' as p;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'form_finders.dart';

class _FakeImagePicker extends Fake
    with MockPlatformInterfaceMixin
    implements ImagePickerPlatform {
  final String path;

  _FakeImagePicker(this.path);

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile(path);
}

class _TrackedStorage extends ImageStorage {
  final inflight = <Future<Object?>>[];

  _TrackedStorage({super.baseDirectory});

  @override
  Future<String> save(String sourcePath) {
    final result = super.save(sourcePath);
    inflight.add(result);
    return result;
  }

  @override
  Future<void> deleteIfManaged(String? path) {
    final result = super.deleteIfManaged(path);
    inflight.add(result);
    return result;
  }
}

void main() {
  late Directory root;
  late Directory cache;
  late Directory documents;
  late AppDatabase db;
  late _TrackedStorage storage;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('image_pick_test');
    cache = Directory(p.join(root.path, 'cache'))..createSync();
    documents = Directory(p.join(root.path, 'documents'))..createSync();
    storage = _TrackedStorage(baseDirectory: () async => documents);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  File cachedImage() {
    const png = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
      0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
      0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
    final dir = Directory(p.join(cache.path, 'picker-uuid'))..createSync();
    return File(p.join(dir.path, 'foto.png'))..writeAsBytesSync(png);
  }

  Future<void> openSheet(
    WidgetTester tester,
    Widget sheet, {
    double width = 412,
  }) async {
    tester.view.physicalSize = Size(width, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStorageProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => sheet,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  String? shownImagePath(WidgetTester tester) {
    final images = tester.widgetList<Image>(find.byType(Image));
    for (final image in images) {
      final provider = image.image;
      if (provider is FileImage) return provider.file.path;
    }
    return null;
  }

  Future<void> until(WidgetTester tester, bool Function() done) async {
    while (!done()) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  Future<void> settleIO(WidgetTester tester) async {
    var quiet = 0;
    while (quiet < 3) {
      await tester.pump();
      final pending = List.of(storage.inflight);
      storage.inflight.clear();
      var completed = 0;
      for (final future in pending) {
        future.then<void>((_) => completed++, onError: (Object _) => completed++);
      }
      await until(tester, () => completed == pending.length);
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      var loaded = 0;
      final images = [
        for (final image in tester.widgetList<Image>(find.byType(Image)))
          if (image.image is FileImage) image.image,
      ];
      for (final provider in images) {
        final stream = provider.resolve(ImageConfiguration.empty);
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (_, _) {
            loaded++;
            stream.removeListener(listener);
          },
          onError: (_, _) {
            loaded++;
            stream.removeListener(listener);
          },
        );
        stream.addListener(listener);
      }
      await until(tester, () => loaded == images.length);
      quiet = pending.isEmpty ? quiet + 1 : 0;
    }
    await tester.pumpAndSettle();
  }

  Future<void> pickImage(WidgetTester tester, File source) async {
    ImagePickerPlatform.instance = _FakeImagePicker(source.path);
    await tester.tap(find.byIcon(Icons.add_a_photo_rounded));
    await settleIO(tester);
  }

  group('picking an image in the product form', () {
    testWidgets('keeps a copy in the permanent directory and shows that one, not the cache file', (
      tester,
    ) async {
      final picked = cachedImage();
      await openSheet(tester, const ProductDialog());

      await pickImage(tester, picked);

      final shown = shownImagePath(tester);
      expect(shown, isNotNull);
      expect(p.isWithin(p.join(documents.path, ImageStorage.folderName), shown!), isTrue);
      expect(p.isWithin(cache.path, shown), isFalse);
      expect(File(shown).existsSync(), isTrue);
    });

    testWidgets('closing without saving removes the unused copy', (tester) async {
      final picked = cachedImage();
      await openSheet(tester, const ProductDialog());
      await pickImage(tester, picked);
      final shown = shownImagePath(tester)!;
      expect(File(shown).existsSync(), isTrue);

      await tester.ensureVisible(find.text('Volver'));
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      await settleIO(tester);

      expect(File(shown).existsSync(), isFalse);
    });

    testWidgets('saving stores the permanent path in the database', (tester) async {
      final picked = cachedImage();
      await openSheet(tester, const ProductDialog());
      await pickImage(tester, picked);
      final shown = shownImagePath(tester)!;

      await tester.enterText(fieldLabeled('Nombre'), 'Estuches');
      await tester.enterText(fieldLabeled('Precio A'), '10');
      await tester.enterText(fieldLabeled('Precio B'), '8');
      await tester.enterText(fieldLabeled('Stock'), '3');
      await tester.tap(find.text('Crear'));
      await settleIO(tester);

      final product = (await tester.runAsync(() => db.select(db.products).get()))!.single;
      expect(product.image, shown);
      expect(File(product.image!).existsSync(), isTrue);
    });

    testWidgets('a product whose image file is gone shows the placeholder instead of crashing', (
      tester,
    ) async {
      final missing = p.join(cache.path, 'ya-no-existe.png');
      await openSheet(
        tester,
        ProductDialog(
          product: ProductModel(
            id: 1,
            categoryId: 1,
            name: 'Estuches',
            image: missing,
            priceA: 10,
            priceB: 8,
            stock: 3,
            isActive: true,
            createdAt: DateTime(2024),
          ),
        ),
        width: 700,
      );
      await settleIO(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('picking an image in the category form', () {
    testWidgets('keeps a copy in the permanent directory and shows that one', (
      tester,
    ) async {
      final picked = cachedImage();
      await openSheet(tester, const CategoryDialog());

      await pickImage(tester, picked);

      final shown = shownImagePath(tester);
      expect(shown, isNotNull);
      expect(p.isWithin(p.join(documents.path, ImageStorage.folderName), shown!), isTrue);
      expect(p.isWithin(cache.path, shown), isFalse);
    });
  });
}
