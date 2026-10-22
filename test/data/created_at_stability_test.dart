import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/config/app_clock.dart';
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
  var clock = DateTime(2026, 10, 1, 9);

  void at(int seconds) {
    clock = DateTime(2026, 10, 1, 9).add(Duration(seconds: seconds));
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    at(0);
    setAppClockForTesting(() => clock);
  });

  tearDown(() async {
    setAppClockForTesting();
    await db.close();
  });

  Future<void> expectStable({
    required Future<(DateTime, DateTime?)> Function() read,
    required Future<void> Function() edit,
    required Future<void> Function() deactivate,
    required Future<void> Function() reactivate,
  }) async {
    final (created, updatedAtCreation) = await read();
    expect(created, DateTime(2026, 10, 1, 9));

    at(10);
    await edit();
    final (afterEdit, updatedAfterEdit) = await read();
    expect(afterEdit, created, reason: 'created_at changed on edit');
    expect(updatedAfterEdit, DateTime(2026, 10, 1, 9, 0, 10));
    expect(updatedAfterEdit, isNot(updatedAtCreation));

    at(20);
    await deactivate();
    final (afterDeactivation, updatedAfterDeactivation) = await read();
    expect(
      afterDeactivation,
      created,
      reason: 'created_at changed on deactivation',
    );
    expect(updatedAfterDeactivation, DateTime(2026, 10, 1, 9, 0, 20));

    at(30);
    await reactivate();
    final (afterReactivation, updatedAfterReactivation) = await read();
    expect(
      afterReactivation,
      created,
      reason: 'created_at changed on reactivation',
    );
    expect(updatedAfterReactivation, DateTime(2026, 10, 1, 9, 0, 30));
  }

  test('categories keep created_at on edit, deactivation and reactivation', () async {
    final repository = CategoryRepository(db);
    await repository.save(name: 'Pinturas');
    Future<Category> row() => (db.select(
      db.categories,
    )..where((c) => c.name.equals('Pinturas'))).getSingle();
    await expectStable(
      read: () async => ((await row()).createdAt, (await row()).updatedAt),
      edit: () async {
        final id = (await row()).id;
        await repository.save(id: id, name: 'Pinturas', description: 'Cambio');
      },
      deactivate: () async {
        final r = await row();
        await repository.save(id: r.id, name: r.name, isActive: false);
      },
      reactivate: () async {
        final r = await row();
        await repository.save(id: r.id, name: r.name, isActive: true);
      },
    );
  });

  test('the category deactivate method keeps created_at too', () async {
    final repository = CategoryRepository(db);
    await repository.save(name: 'Marcos');
    final before = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Marcos'))).getSingle();
    at(10);
    await repository.deactivate(before.id);
    final after = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(before.id))).getSingle();
    expect(after.createdAt, before.createdAt);
    expect(after.isActive, isFalse);
    expect(after.updatedAt, DateTime(2026, 10, 1, 9, 0, 10));
  });

  test('products keep created_at on edit, deactivation and reactivation', () async {
    final repository = ProductRepository(db);
    await repository.save(name: 'Cuadro', priceA: 20, priceB: 25, stock: 3);
    Future<Product> row() => (db.select(
      db.products,
    )..where((p) => p.name.equals('Cuadro'))).getSingle();
    Future<void> save({required bool active, double priceA = 20}) async {
      final r = await row();
      await repository.save(
        id: r.id,
        categoryId: r.categoryId,
        name: r.name,
        priceA: priceA,
        priceB: r.priceB,
        stock: r.stock,
        isActive: active,
      );
    }

    await expectStable(
      read: () async => ((await row()).createdAt, (await row()).updatedAt),
      edit: () => save(active: true, priceA: 22),
      deactivate: () => save(active: false, priceA: 22),
      reactivate: () => save(active: true, priceA: 22),
    );
  });

  test('materials keep created_at on edit, deactivation and reactivation', () async {
    final repository = MaterialRepository(db);
    final unit = (await db.select(db.units).get()).first;
    final id = await repository.save(
      name: 'Tela',
      unitId: unit.id,
      stock: 0,
      pricePerUnit: 2,
    );
    Future<Material> row() =>
        (db.select(db.materials)..where((m) => m.id.equals(id))).getSingle();
    Future<void> save({required bool active, double price = 2}) async {
      final r = await row();
      await repository.save(
        id: id,
        name: r.name,
        unitId: r.unitId,
        stock: r.stock,
        pricePerUnit: price,
        isActive: active,
      );
    }

    await expectStable(
      read: () async => ((await row()).createdAt, (await row()).updatedAt),
      edit: () => save(active: true, price: 3),
      deactivate: () => save(active: false, price: 3),
      reactivate: () => save(active: true, price: 3),
    );
  });

  test('clients keep created_at on edit, deactivation and reactivation', () async {
    final repository = ClientRepository(db);
    final id = await repository.save(name: 'Ana');
    Future<Client> row() =>
        (db.select(db.clients)..where((c) => c.id.equals(id))).getSingle();
    Future<void> save({required bool active, String? contact}) =>
        repository.save(id: id, name: 'Ana', contactInfo: contact, isActive: active);

    await expectStable(
      read: () async => ((await row()).createdAt, (await row()).updatedAt),
      edit: () => save(active: true, contact: '555'),
      deactivate: () => save(active: false, contact: '555'),
      reactivate: () => save(active: true, contact: '555'),
    );
  });

  test('suppliers keep created_at on edit, deactivation and reactivation', () async {
    final repository = SupplierRepository(db);
    final id = await repository.save(name: 'Papelera');
    Future<Supplier> row() =>
        (db.select(db.suppliers)..where((s) => s.id.equals(id))).getSingle();
    Future<void> save({required bool active, String? contact}) =>
        repository.save(id: id, name: 'Papelera', contactInfo: contact, isActive: active);

    await expectStable(
      read: () async => ((await row()).createdAt, (await row()).updatedAt),
      edit: () => save(active: true, contact: '555'),
      deactivate: () => save(active: false, contact: '555'),
      reactivate: () => save(active: true, contact: '555'),
    );
  });

  test('locations keep created_at on edit, deactivation and reactivation', () async {
    final repository = LocationRepository(db);
    final id = await repository.save(city: 'La Paz', country: 'Bolivia');
    Future<Location> row() =>
        (db.select(db.locations)..where((l) => l.id.equals(id))).getSingle();
    Future<void> save({required bool active, String? zone}) => repository.save(
      id: id,
      city: 'La Paz',
      country: 'Bolivia',
      description: zone,
      isActive: active,
    );

    await expectStable(
      read: () async => ((await row()).createdAt, (await row()).updatedAt),
      edit: () => save(active: true, zone: 'Centro'),
      deactivate: () => save(active: false, zone: 'Centro'),
      reactivate: () => save(active: true, zone: 'Centro'),
    );
  });

  test('events keep created_at on edit, deactivation and reactivation', () async {
    final repository = EventRepository(db);
    await repository.save(name: 'Feria', startDate: DateTime(2026, 10, 5));
    Future<Event> row() => (db.select(
      db.events,
    )..where((e) => e.name.equals('Feria'))).getSingle();
    Future<void> save({required bool active, String? notes}) async {
      final r = await row();
      await repository.save(
        id: r.id,
        name: r.name,
        startDate: r.startDate,
        notes: notes,
        isActive: active,
      );
    }

    await expectStable(
      read: () async => ((await row()).createdAt, (await row()).updatedAt),
      edit: () => save(active: true, notes: 'Nota'),
      deactivate: () => save(active: false, notes: 'Nota'),
      reactivate: () => save(active: true, notes: 'Nota'),
    );
  });
}
