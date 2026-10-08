import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/location_options.dart';
import 'package:offline_first_bi/application/report_service.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/models/location_model.dart';
import 'package:offline_first_bi/models/purchase_kind.dart';
import 'package:offline_first_bi/models/report_filters.dart';

// Cancelación de compras (igual que la de ventas): resta del stock lo comprado,
// se bloquea si algún material ya se usó, deja la compra como historial, no se
// puede editar ni cancelar otra vez y no cuenta en los reportes. También los
// filtros País y Ciudad de los reportes.
void main() {
  late AppDatabase db;
  late PurchaseRepository repository;

  Future<double> stockOf(int materialId) async => (await (db.select(
    db.materials,
  )..where((m) => m.id.equals(materialId))).getSingle()).stock;

  Future<int> createMaterialPurchase(
    List<Map<String, dynamic>> items, {
    int? locationId,
    DateTime? date,
  }) async {
    await repository.createPurchase(
      supplierId: null,
      isMaterial: true,
      description: null,
      totalAmount: repository.calculateMaterialsTotal(items),
      date: date ?? DateTime(2024, 1, 1),
      locationId: locationId,
      eventId: null,
      items: items,
    );
    final all = await repository.getAll();
    return all.map((p) => p.id).reduce((a, b) => a > b ? a : b);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PurchaseRepository(db);
    final unit = await (db.select(
      db.units,
    )..where((u) => u.name.equals('unidad'))).getSingle();
    for (final (name, stock) in [('Material 1', 10.0), ('Material 2', 4.0)]) {
      await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: name,
          unitId: unit.id,
          pricePerUnit: 2.0,
          stock: Value(stock),
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  group('cancelPurchase', () {
    test(
      'a materials purchase subtracts what was bought from each material and '
      'stays in the list as canceled, with its items',
      () async {
        final id = await createMaterialPurchase([
          {'materialId': 1, 'quantity': 5.0, 'unitPrice': 3.0},
          {'materialId': 2, 'quantity': 2.0, 'unitPrice': 4.0},
        ]);
        expect(await stockOf(1), 15);
        expect(await stockOf(2), 6);

        final error = await repository.cancelPurchase(id);

        expect(error, isNull);
        expect(await stockOf(1), 10);
        expect(await stockOf(2), 4);
        final all = await repository.getAll();
        expect(all, hasLength(1));
        expect(all.single.isCanceled, isTrue);
        expect(all.single.canceledAt, isNotNull);
        expect(all.single.totalAmount, 23);
        expect(await repository.getItemsForPurchase(id), hasLength(2));
      },
    );

    test('a general expense is canceled without touching any stock', () async {
      await repository.createPurchase(
        supplierId: null,
        isMaterial: false,
        description: 'Pasaje',
        totalAmount: 20,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        items: const [],
      );
      final id = (await repository.getAll()).single.id;

      expect(await repository.cancelPurchase(id), isNull);

      expect(await stockOf(1), 10);
      expect(await stockOf(2), 4);
      expect((await repository.getAll()).single.isCanceled, isTrue);
    });

    test(
      'is blocked, changing nothing, when a material no longer has the '
      'quantity that was bought (it was already used)',
      () async {
        final id = await createMaterialPurchase([
          {'materialId': 1, 'quantity': 5.0, 'unitPrice': 3.0},
          {'materialId': 2, 'quantity': 2.0, 'unitPrice': 4.0},
        ]);
        // Material 2 se usó casi todo: queda 1 (< 2 comprados).
        await (db.update(db.materials)..where((m) => m.id.equals(2)))
            .write(const MaterialsCompanion(stock: Value(1)));

        final error = await repository.cancelPurchase(id);

        expect(
          error,
          'No se puede cancelar la compra porque el stock actual de uno de '
          'los materiales es menor a la cantidad comprada.',
        );
        // Nada cambió: ni el material que sí alcanzaba, ni la compra.
        expect(await stockOf(1), 15);
        expect(await stockOf(2), 1);
        expect((await repository.getAll()).single.isCanceled, isFalse);
      },
    );

    test('also blocks when a real material usage record consumed the stock', () async {
      final productId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Producto',
          priceA: 10,
          priceB: 10,
        ),
      );
      final id = await createMaterialPurchase([
        {'materialId': 1, 'quantity': 5.0, 'unitPrice': 3.0},
      ]);
      expect(await stockOf(1), 15);
      // Se usan 12 de 15: quedan 3 (< 5 comprados).
      expect(
        await MaterialRepository(db).registerMaterialUsage(
          productId: productId,
          materialId: 1,
          quantityUsed: 12,
        ),
        isNull,
      );

      expect(
        await repository.cancelPurchase(id),
        PurchaseRepository.cancelBlockedMessage,
      );
      expect(await stockOf(1), 3);
    });

    test('subtracting decimals leaves a clean stock (no 57.599999999999994)', () async {
      await (db.update(db.materials)..where((m) => m.id.equals(1)))
          .write(const MaterialsCompanion(stock: Value(57.6)));
      final id = await createMaterialPurchase([
        {'materialId': 1, 'quantity': 15.0, 'unitPrice': 33.0},
      ]);
      expect(await stockOf(1), 72.6);
      expect(await repository.cancelPurchase(id), isNull);
      expect(await stockOf(1), 57.6);
    });

    test('exactly using up the stock is allowed (stock 0, never negative)', () async {
      final id = await createMaterialPurchase([
        {'materialId': 2, 'quantity': 6.0, 'unitPrice': 1.0},
      ]);
      expect(await stockOf(2), 10);
      await (db.update(db.materials)..where((m) => m.id.equals(2)))
          .write(const MaterialsCompanion(stock: Value(6)));

      expect(await repository.cancelPurchase(id), isNull);
      expect(await stockOf(2), 0);
    });

    test('canceling twice is rejected and does not subtract the stock twice', () async {
      final id = await createMaterialPurchase([
        {'materialId': 1, 'quantity': 5.0, 'unitPrice': 3.0},
      ]);
      expect(await repository.cancelPurchase(id), isNull);
      expect(await stockOf(1), 10);

      expect(await repository.cancelPurchase(id), 'La compra ya está cancelada');
      expect(await stockOf(1), 10);
      expect(await repository.cancelPurchase(999), 'Compra no encontrada');
    });

    test('a canceled purchase can no longer be edited', () async {
      final id = await createMaterialPurchase([
        {'materialId': 1, 'quantity': 5.0, 'unitPrice': 3.0},
      ]);
      await repository.cancelPurchase(id);

      final error = await repository.editPurchase(
        purchaseId: id,
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 60,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        newItems: [
          {'materialId': 1, 'quantity': 20.0, 'unitPrice': 3.0},
        ],
      );

      expect(error, 'La compra está cancelada y no se puede editar');
      expect(await stockOf(1), 10); // sin cambios
      expect((await repository.getItemsForPurchase(id)).single.quantity, 5);
    });

    test('editing a live purchase still works and returns no error', () async {
      final id = await createMaterialPurchase([
        {'materialId': 1, 'quantity': 5.0, 'unitPrice': 3.0},
      ]);
      final error = await repository.editPurchase(
        purchaseId: id,
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 24,
        date: DateTime(2024, 1, 1),
        locationId: null,
        eventId: null,
        newItems: [
          {'materialId': 1, 'quantity': 8.0, 'unitPrice': 3.0},
        ],
      );
      expect(error, isNull);
      expect(await stockOf(1), 18); // 10 + 8
    });
  });

  group('reports ignore canceled purchases, like canceled sales', () {
    test('filterPurchases leaves a canceled purchase out of every total', () async {
      final keep = await createMaterialPurchase([
        {'materialId': 1, 'quantity': 1.0, 'unitPrice': 10.0},
      ]);
      final cancel = await createMaterialPurchase([
        {'materialId': 1, 'quantity': 2.0, 'unitPrice': 10.0},
      ]);
      await repository.cancelPurchase(cancel);

      final service = ReportService();
      final result = service.filterPurchases(
        purchases: await repository.getAll(),
        filters: const ReportFilters(),
      );
      expect(result.map((p) => p.id), [keep]);
      expect(service.summarizePurchases(result).totalAmount, 10);
      // Tampoco con el filtro de tipo.
      expect(
        service
            .filterPurchases(
              purchases: await repository.getAll(),
              filters: const ReportFilters(purchaseKind: PurchaseKind.material),
            )
            .map((p) => p.id),
        [keep],
      );
    });
  });

  group('País y Ciudad', () {
    final lpz = LocationModel(
      id: 1,
      city: 'La Paz',
      country: 'Bolivia',
      isActive: true,
      createdAt: DateTime(2024),
    );
    final scz = LocationModel(
      id: 2,
      city: 'Santa Cruz',
      country: 'Bolivia',
      isActive: true,
      createdAt: DateTime(2024),
    );
    final lima = LocationModel(
      id: 3,
      city: 'Lima',
      country: 'Perú',
      isActive: false,
      createdAt: DateTime(2024),
    );
    final locations = [lpz, scz, lima];

    test('options come from the existing locations and cities narrow to the country', () {
      expect(countryOptions(locations), ['Bolivia', 'Perú']);
      expect(cityOptions(locations), ['La Paz', 'Lima', 'Santa Cruz']);
      expect(cityOptions(locations, country: 'Bolivia'), ['La Paz', 'Santa Cruz']);
      expect(cityOptions(locations, country: 'Perú'), ['Lima']);
    });

    test('locationMatches: no location is left out as soon as a country or city is chosen', () {
      expect(locationMatches(null), isTrue);
      expect(locationMatches(null, country: 'Bolivia'), isFalse);
      expect(locationMatches(null, city: 'La Paz'), isFalse);
      expect(locationMatches(lpz, country: 'Bolivia'), isTrue);
      expect(locationMatches(lpz, country: 'Perú'), isFalse);
      expect(locationMatches(lpz, country: 'Bolivia', city: 'La Paz'), isTrue);
      expect(locationMatches(lpz, country: 'Bolivia', city: 'Santa Cruz'), isFalse);
    });

    test('purchases are filtered by the city and country of their linked location', () async {
      for (final l in locations) {
        await db.into(db.locations).insert(
          LocationsCompanion.insert(city: l.city, country: l.country),
        );
      }
      Future<int> inLocation(int? locationId) => createMaterialPurchase([
        {'materialId': 1, 'quantity': 1.0, 'unitPrice': 1.0},
      ], locationId: locationId);
      final inLpz = await inLocation(1);
      final inScz = await inLocation(2);
      final inLima = await inLocation(3);
      final noLocation = await inLocation(null);
      final all = await repository.getAll();
      final service = ReportService();
      List<int> ids(ReportFilters f) =>
          service
              .filterPurchases(purchases: all, filters: f, locations: locations)
              .map((p) => p.id)
              .toList()
            ..sort();

      expect(ids(const ReportFilters()), [inLpz, inScz, inLima, noLocation]);
      expect(ids(const ReportFilters(country: 'Bolivia')), [inLpz, inScz]);
      expect(ids(const ReportFilters(country: 'Perú')), [inLima]);
      expect(ids(const ReportFilters(city: 'La Paz')), [inLpz]);
      expect(ids(const ReportFilters(country: 'Bolivia', city: 'Lima')), isEmpty);
      // Se combinan con el filtro de Ubicación existente.
      expect(ids(const ReportFilters(country: 'Bolivia', locationId: 2)), [inScz]);
      expect(ids(const ReportFilters(country: 'Perú', locationId: 2)), isEmpty);
    });
  });
}
