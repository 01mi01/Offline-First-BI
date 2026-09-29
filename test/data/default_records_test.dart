import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/category_provider.dart';
import 'package:offline_first_bi/application/client_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/event_provider.dart';
import 'package:offline_first_bi/application/supplier_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/category_repository.dart';
import 'package:offline_first_bi/data/repositories/client_repository.dart';
import 'package:offline_first_bi/data/repositories/event_repository.dart';
import 'package:offline_first_bi/data/repositories/product_repository.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/data/repositories/supplier_repository.dart';
import 'package:offline_first_bi/models/default_records.dart';

// Registros predeterminados ("Sin categoría", "Sin nombre", "Sin proveedor"):
// protegidos contra renombrar / editar / desactivar, y destino automático de
// lo que se guarda sin elegir categoría, cliente o proveedor.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Category> categoryNamed(String name) =>
      (db.select(db.categories)..where((c) => c.name.equals(name))).getSingle();
  Future<Client> clientNamed(String name) =>
      (db.select(db.clients)..where((c) => c.name.equals(name))).getSingle();
  Future<Supplier> supplierNamed(String name) =>
      (db.select(db.suppliers)..where((s) => s.name.equals(name))).getSingle();

  test('a fresh database seeds the three default records, active', () async {
    expect((await categoryNamed(DefaultRecords.category)).isActive, isTrue);
    expect((await clientNamed(DefaultRecords.client)).isActive, isTrue);
    expect((await supplierNamed(DefaultRecords.supplier)).isActive, isTrue);
  });

  group('the default category is protected', () {
    late CategoryRepository repository;
    late int defaultId;

    setUp(() async {
      repository = CategoryRepository(db);
      defaultId = (await categoryNamed(DefaultRecords.category)).id;
    });

    test('it cannot be renamed', () async {
      await expectLater(
        repository.save(id: defaultId, name: 'Otro nombre'),
        throwsA(isA<ProtectedRecordException>()),
      );
      expect((await categoryNamed(DefaultRecords.category)).id, defaultId);
    });

    test('it cannot be edited even keeping the name (description, image, ...)', () async {
      await expectLater(
        repository.save(
          id: defaultId,
          name: DefaultRecords.category,
          description: 'Descripción nueva',
        ),
        throwsA(isA<ProtectedRecordException>()),
      );
      expect((await categoryNamed(DefaultRecords.category)).description, isNull);
    });

    test('it cannot be deactivated, via save or via deactivate', () async {
      await expectLater(
        repository.save(id: defaultId, name: DefaultRecords.category, isActive: false),
        throwsA(isA<ProtectedRecordException>()),
      );
      await expectLater(
        repository.deactivate(defaultId),
        throwsA(isA<ProtectedRecordException>()),
      );
      expect((await categoryNamed(DefaultRecords.category)).isActive, isTrue);
    });

    test('no other category can take its name (any casing / spacing)', () async {
      for (final name in ['Sin categoría', 'sin categoría', '  SIN CATEGORÍA ']) {
        await expectLater(
          repository.save(name: name),
          throwsA(isA<ProtectedRecordException>()),
          reason: '"$name" debe estar reservado',
        );
      }
      // Renombrar otra categoría a ese nombre tampoco vale.
      await repository.save(name: 'Bisutería');
      final bisuteria = await categoryNamed('Bisutería');
      await expectLater(
        repository.save(id: bisuteria.id, name: 'Sin categoría'),
        throwsA(isA<ProtectedRecordException>()),
      );
    });

    test('other categories are still editable and deactivatable', () async {
      await repository.save(name: 'Bisutería');
      final bisuteria = await categoryNamed('Bisutería');
      await repository.save(id: bisuteria.id, name: 'Joyería');
      await repository.deactivate((await categoryNamed('Joyería')).id);
      expect((await categoryNamed('Joyería')).isActive, isFalse);
    });

    test('the provider surfaces the protection as an error message, not a crash', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(categoryProvider.notifier);

      await notifier.save(id: defaultId, name: 'Renombrada');

      expect(container.read(categoryProvider).error, DefaultRecords.protectedMessage);
      expect((await categoryNamed(DefaultRecords.category)).id, defaultId);
    });
  });

  group('the default client is protected', () {
    late ClientRepository repository;
    late int defaultId;

    setUp(() async {
      repository = ClientRepository(db);
      defaultId = (await clientNamed(DefaultRecords.client)).id;
    });

    test('it cannot be renamed, edited or deactivated', () async {
      await expectLater(
        repository.save(id: defaultId, name: 'Otro nombre'),
        throwsA(isA<ProtectedRecordException>()),
      );
      await expectLater(
        repository.save(id: defaultId, name: DefaultRecords.client, contactInfo: '777'),
        throwsA(isA<ProtectedRecordException>()),
      );
      await expectLater(
        repository.save(id: defaultId, name: DefaultRecords.client, isActive: false),
        throwsA(isA<ProtectedRecordException>()),
      );
      final row = await clientNamed(DefaultRecords.client);
      expect(row.isActive, isTrue);
      expect(row.contactInfo, isNull);
    });

    test('no other client can take its name', () async {
      await expectLater(
        repository.save(name: 'sin nombre'),
        throwsA(isA<ProtectedRecordException>()),
      );
    });

    test('other clients are still editable and deactivatable', () async {
      final id = await repository.save(name: 'Maria');
      await repository.save(id: id, name: 'Maria P.', isActive: false);
      final row = await (db.select(db.clients)..where((c) => c.id.equals(id))).getSingle();
      expect(row.name, 'Maria P.');
      expect(row.isActive, isFalse);
    });

    test('the provider returns the protection message to the form', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final error = await container
          .read(clientProvider.notifier)
          .save(id: defaultId, name: 'Renombrado');

      expect(error, DefaultRecords.protectedMessage);
    });
  });

  group('the default supplier is protected', () {
    late SupplierRepository repository;
    late int defaultId;

    setUp(() async {
      repository = SupplierRepository(db);
      defaultId = (await supplierNamed(DefaultRecords.supplier)).id;
    });

    test('it cannot be renamed, edited or deactivated', () async {
      await expectLater(
        repository.save(id: defaultId, name: 'Otro proveedor'),
        throwsA(isA<ProtectedRecordException>()),
      );
      await expectLater(
        repository.save(id: defaultId, name: DefaultRecords.supplier, contactInfo: '777'),
        throwsA(isA<ProtectedRecordException>()),
      );
      await expectLater(
        repository.save(id: defaultId, name: DefaultRecords.supplier, isActive: false),
        throwsA(isA<ProtectedRecordException>()),
      );
      final row = await supplierNamed(DefaultRecords.supplier);
      expect(row.isActive, isTrue);
      expect(row.contactInfo, isNull);
    });

    test('no other supplier can take its name', () async {
      await expectLater(
        repository.save(name: 'SIN PROVEEDOR'),
        throwsA(isA<ProtectedRecordException>()),
      );
    });

    test('other suppliers are still editable and deactivatable', () async {
      final id = await repository.save(name: 'Andino');
      await repository.save(id: id, name: 'Andino SRL', isActive: false);
      final row = await (db.select(db.suppliers)..where((s) => s.id.equals(id))).getSingle();
      expect(row.name, 'Andino SRL');
      expect(row.isActive, isFalse);
    });

    test('the provider returns the protection message to the form', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final error = await container
          .read(supplierProvider.notifier)
          .save(id: defaultId, name: 'Renombrado');

      expect(error, DefaultRecords.protectedMessage);
    });
  });

  group('saving without choosing goes silently to the default record', () {
    test('a sale with no client is saved under the default client', () async {
      final repository = SaleRepository(db);
      final defaultId = (await clientNamed(DefaultRecords.client)).id;
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Collar',
          priceA: 10,
          priceB: 10,
          stock: const Value(5),
        ),
      );

      await repository.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 10,
        discount: 0,
        finalAmount: 10,
        date: DateTime(2024, 1, 1),
        items: [
          {'productId': 1, 'quantity': 1, 'unitPrice': 10.0},
        ],
      );

      final sale = (await repository.getAll()).single;
      expect(sale.clientId, defaultId);
    });

    test('editing a sale and leaving the client empty keeps it on the default client', () async {
      final repository = SaleRepository(db);
      final defaultId = (await clientNamed(DefaultRecords.client)).id;
      final other = await ClientRepository(db).save(name: 'Maria');
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Collar',
          priceA: 10,
          priceB: 10,
          stock: const Value(5),
        ),
      );
      await repository.createSale(
        clientId: other,
        locationId: null,
        eventId: null,
        totalAmount: 10,
        discount: 0,
        finalAmount: 10,
        date: DateTime(2024, 1, 1),
        items: [
          {'productId': 1, 'quantity': 1, 'unitPrice': 10.0},
        ],
      );
      final sale = (await repository.getAll()).single;
      expect(sale.clientId, other);

      // La persona quita el cliente en el formulario (opción "Sin nombre").
      await repository.editSale(
        saleId: sale.id,
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 10,
        discount: 0,
        finalAmount: 10,
        date: sale.date,
        newItems: [
          {'productId': 1, 'quantity': 1, 'unitPrice': 10.0},
        ],
      );

      expect((await repository.getAll()).single.clientId, defaultId);
    });

    test('if the default client row is missing it is recreated, never left null', () async {
      await db.delete(db.clients).go();
      final repository = SaleRepository(db);
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Collar',
          priceA: 10,
          priceB: 10,
          stock: const Value(5),
        ),
      );

      await repository.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 10,
        discount: 0,
        finalAmount: 10,
        date: DateTime(2024, 1, 1),
        items: [
          {'productId': 1, 'quantity': 1, 'unitPrice': 10.0},
        ],
      );

      final defaultClient = await clientNamed(DefaultRecords.client);
      expect((await repository.getAll()).single.clientId, defaultClient.id);
    });

    test('a purchase with no supplier goes to the default supplier', () async {
      final defaultId = (await supplierNamed(DefaultRecords.supplier)).id;
      final repository = PurchaseRepository(db);

      await repository.createPurchase(
        supplierId: null,
        isMaterial: false,
        description: 'Alquiler',
        totalAmount: 50,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: const [],
      );

      expect((await repository.getAll()).single.supplierId, defaultId);
    });

    test('a product with no category goes to the default category', () async {
      final defaultId = (await categoryNamed(DefaultRecords.category)).id;

      await ProductRepository(db).save(
        name: 'Collar',
        priceA: 10,
        priceB: 8,
        stock: 1,
      );

      final products = await ProductRepository(db).getAllIncludingInactive();
      expect(products.single.categoryId, defaultId);
    });
  });

  group('events can be deactivated (soft state, never deleted)', () {
    late EventRepository repository;

    setUp(() {
      repository = EventRepository(db);
    });

    Future<void> saveEvent(String name, {int? id, bool isActive = true}) =>
        repository.save(
          id: id,
          name: name,
          startDate: DateTime(2024, 3, 5),
          isActive: isActive,
        );

    test('a new event is active by default', () async {
      await saveEvent('Feria');
      expect((await repository.getAll()).single.isActive, isTrue);
    });

    test('deactivating keeps the record (no hard delete) with its data', () async {
      await saveEvent('Feria');
      final event = (await repository.getAll()).single;

      await saveEvent('Feria', id: event.id, isActive: false);

      final all = await repository.getAll();
      expect(all, hasLength(1)); // sigue existiendo
      expect(all.single.id, event.id);
      expect(all.single.isActive, isFalse);
      expect(all.single.name, 'Feria');
    });

    test('an event can be reactivated', () async {
      await saveEvent('Feria');
      final id = (await repository.getAll()).single.id;
      await saveEvent('Feria', id: id, isActive: false);
      await saveEvent('Feria', id: id, isActive: true);

      expect((await repository.getAll()).single.isActive, isTrue);
    });

    test('the provider keeps inactive events in its list (pickers filter by isActive)', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(eventProvider.notifier);
      await notifier.load();
      await notifier.save(name: 'Feria', startDate: DateTime(2024, 3, 5));
      await notifier.save(name: 'Expo', startDate: DateTime(2024, 4, 5));
      final expo = container.read(eventProvider).events.firstWhere((e) => e.name == 'Expo');

      await notifier.save(
        id: expo.id,
        name: 'Expo',
        startDate: DateTime(2024, 4, 5),
        isActive: false,
      );

      final events = container.read(eventProvider).events;
      expect(events, hasLength(2));
      expect(events.where((e) => e.isActive).map((e) => e.name), ['Feria']);
    });
  });
}
