import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/category_repository.dart';
import 'package:offline_first_bi/data/repositories/client_repository.dart';
import 'package:offline_first_bi/data/repositories/event_repository.dart';
import 'package:offline_first_bi/data/repositories/location_repository.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/data/repositories/product_repository.dart';
import 'package:offline_first_bi/data/repositories/supplier_repository.dart';

void main() {
  late AppDatabase db;
  late ProductRepository products;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    products = ProductRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> saveProduct(String name, {int? id, bool isActive = true}) =>
      products.save(
        id: id,
        name: name,
        priceA: 10,
        priceB: 8,
        stock: 1,
        isActive: isActive,
      );

  group('product names are unique', () {
    test('the same name is rejected', () async {
      await saveProduct('Estuches');
      await expectLater(
        saveProduct('Estuches'),
        throwsA(
          predicate((e) => e.toString().contains(duplicateProductMessage)),
        ),
      );
    });

    test('case, accents and spaces do not make a different name', () async {
      await saveProduct('Café molido');
      for (final variant in ['cafe molido', 'CAFÉ  MOLIDO', '  Cafe Molido ']) {
        await expectLater(saveProduct(variant), throwsException, reason: variant);
      }
      expect(await products.getAllIncludingInactive(), hasLength(1));
    });

    test('inactive products still hold their name', () async {
      await saveProduct('Libro', isActive: false);
      await expectLater(saveProduct('libro'), throwsException);
    });

    test('renaming to an existing name is rejected, keeping the own name is not', () async {
      await saveProduct('Uno');
      await saveProduct('Dos');
      final all = await products.getAllIncludingInactive();
      final dos = all.firstWhere((p) => p.name == 'Dos');
      await expectLater(saveProduct('uno', id: dos.id), throwsException);
      await saveProduct('DOS', id: dos.id);
      expect(
        (await products.getAllIncludingInactive()).map((p) => p.name),
        containsAll(['Uno', 'DOS']),
      );
    });

    test('the database itself rejects an exact duplicate', () async {
      await saveProduct('Pines');
      await expectLater(
        db.into(db.products).insert(
          ProductsCompanion.insert(
            categoryId: 1,
            name: 'Pines',
            priceA: 1,
            priceB: 1,
          ),
        ),
        throwsA(anything),
      );
    });
  });

  group('a blank name cannot be saved by any repository', () {
    test('every entity with a name rejects spaces only', () async {
      final units = await db.select(db.units).get();
      final saves = <String, Future<void> Function()>{
        'category': () => CategoryRepository(db).save(name: '   '),
        'client': () => ClientRepository(db).save(name: '   '),
        'supplier': () => SupplierRepository(db).save(name: '   '),
        'product': () => saveProduct('   '),
        'material': () => MaterialRepository(db).save(
          name: '   ',
          unitId: units.first.id,
          stock: 1,
          pricePerUnit: 1,
        ),
        'location city': () =>
            LocationRepository(db).save(city: '   ', country: 'Bolivia'),
        'location country': () =>
            LocationRepository(db).save(city: 'La Paz', country: '   '),
        'event': () => EventRepository(db).save(
          name: '   ',
          startDate: DateTime(2026, 1, 1),
        ),
      };
      for (final entry in saves.entries) {
        await expectLater(
          entry.value(),
          throwsA(predicate((e) => e.toString() == 'Campo requerido')),
          reason: entry.key,
        );
      }
    });

    test('names are stored trimmed', () async {
      await saveProduct('  Lapicero  ');
      await ClientRepository(db).save(name: '  Ana  ');
      expect(
        (await products.getAllIncludingInactive()).single.name,
        'Lapicero',
      );
      final clients = await ClientRepository(db).getAllIncludingInactive();
      expect(clients.map((c) => c.name), contains('Ana'));
    });
  });
}
