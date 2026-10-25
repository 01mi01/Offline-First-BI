import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/config/app_clock.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';

void main() {
  late AppDatabase db;
  late PurchaseRepository repository;

  setUp(() async {
    setAppClockForTesting(() => DateTime(2026, 10, 25, 10));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PurchaseRepository(db);
    final unit = await (db.select(
      db.units,
    )..where((u) => u.name.equals('unidad'))).getSingle();
    await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Material 1',
        unitId: unit.id,
        pricePerUnit: 2.0,
        stock: const Value(10.0),
      ),
    );
  });

  tearDown(() async {
    setAppClockForTesting();
    await db.close();
  });

  Future<Material> material() => (db.select(
    db.materials,
  )..where((m) => m.id.equals(1))).getSingle();

  Future<void> buy(DateTime date, double quantity, double unitPrice) =>
      repository.createPurchase(
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: quantity * unitPrice,
        date: date,
        locationId: null,
        eventId: null,
        items: [
          {'materialId': 1, 'quantity': quantity, 'unitPrice': unitPrice},
        ],
      );

  test('a purchase dated after today raises the stock and keeps the price', () async {
    await buy(DateTime(2026, 10, 26, 12), 5, 9);

    final m = await material();
    expect(m.stock, 15);
    expect(m.pricePerUnit, 2.0);
  });

  test('a purchase dated today or earlier updates the price', () async {
    await buy(DateTime(2026, 10, 25, 9), 1, 7);
    expect((await material()).pricePerUnit, 7.0);

    await buy(DateTime(2026, 10, 24, 9), 1, 5);
    expect((await material()).pricePerUnit, 7.0);

    await buy(DateTime(2026, 10, 25, 11), 2, 8);
    final m = await material();
    expect(m.pricePerUnit, 8.0);
    expect(m.stock, 14);
  });

  test('a future purchase does not stop a purchase of today from setting the price', () async {
    await buy(DateTime(2026, 11, 3, 12), 5, 50);
    expect((await material()).pricePerUnit, 2.0);

    await buy(DateTime(2026, 10, 25, 9), 1, 12);
    final m = await material();
    expect(m.pricePerUnit, 12.0);
    expect(m.stock, 16);
  });

  test('editing a purchase to a future date does not change the price', () async {
    await buy(DateTime(2026, 10, 25, 9), 1, 7);
    final purchase = (await repository.getAll()).single;

    final result = await repository.editPurchase(
      purchaseId: purchase.id,
      supplierId: null,
      isMaterial: true,
      description: null,
      totalAmount: 3 * 99.0,
      date: DateTime(2026, 10, 30, 12),
      locationId: null,
      eventId: null,
      newItems: [
        {'materialId': 1, 'quantity': 3.0, 'unitPrice': 99.0},
      ],
    );

    expect(result, isNull);
    final m = await material();
    expect(m.pricePerUnit, 7.0);
    expect(m.stock, 13);
  });
}
