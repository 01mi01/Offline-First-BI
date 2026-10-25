import 'package:drift/drift.dart';
import '../../config/rounding.dart';
import '../../data/db/app_database.dart';
import 'stock_rounding.dart';
import '../../models/purchase_model.dart';
import '../../models/purchase_item_model.dart';
import '../../config/app_clock.dart';

class PurchaseRepository {
  final AppDatabase database;

  PurchaseRepository(this.database);

  double calculateMaterialsTotal(List<Map<String, dynamic>> items) {
    double total = 0;
    for (final item in items) {
      total += round2(
        (item['quantity'] as double) * (item['unitPrice'] as double),
      );
    }
    return round2(total);
  }

  Future<int> _defaultSupplierId() async {
    final existing =
        await (database.select(database.suppliers)
              ..where((s) => s.name.equals(AppDatabase.defaultSupplierName)))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    final now = appNow();
    return database
        .into(database.suppliers)
        .insert(
          SuppliersCompanion.insert(
            name: AppDatabase.defaultSupplierName,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  DateTime get _startOfTomorrow {
    final now = appNow();
    return DateTime(now.year, now.month, now.day + 1);
  }

  bool _isFutureDated(DateTime date) => !date.isBefore(_startOfTomorrow);

  Future<bool> _hasLaterPurchaseOf(
    int materialId, {
    required int excludingPurchaseId,
    required DateTime date,
  }) async {
    final query = database.select(database.purchaseItems).join([
      innerJoin(
        database.purchases,
        database.purchases.id.equalsExp(database.purchaseItems.purchaseId),
      ),
    ])
      ..where(
        database.purchaseItems.materialId.equals(materialId) &
            database.purchaseItems.purchaseId.equals(excludingPurchaseId).not() &
            database.purchases.isCanceled.equals(false) &
            database.purchases.date.isBiggerThanValue(date) &
            database.purchases.date.isSmallerThanValue(_startOfTomorrow),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  PurchaseModel _toModel(Purchase row) {
    return PurchaseModel(
      id: row.id,
      supplierId: row.supplierId,
      locationId: row.locationId,
      eventId: row.eventId,
      isMaterial: row.isMaterial,
      description: row.description,
      totalAmount: row.totalAmount,
      date: row.date,
      notes: row.notes,
      createdAt: row.createdAt,
      isCanceled: row.isCanceled,
      canceledAt: row.canceledAt,
    );
  }

  Future<List<PurchaseModel>> getAll() async {
    final rows = await (database.select(
      database.purchases,
    )..orderBy([(p) => OrderingTerm.desc(p.date)])).get();
    return rows.map(_toModel).toList();
  }

  Future<List<PurchaseItemModel>> getItemsForPurchase(int purchaseId) async {
    final rows = await (database.select(
      database.purchaseItems,
    )..where((pi) => pi.purchaseId.equals(purchaseId))).get();

    final result = <PurchaseItemModel>[];
    for (final row in rows) {
      final material = await (database.select(
        database.materials,
      )..where((m) => m.id.equals(row.materialId))).getSingleOrNull();
      final unit = material == null
          ? null
          : await (database.select(
              database.units,
            )..where((u) => u.id.equals(material.unitId))).getSingleOrNull();
      result.add(
        PurchaseItemModel(
          id: row.id,
          purchaseId: row.purchaseId,
          materialId: row.materialId,
          materialName: material?.name ?? 'Material eliminado',
          quantity: row.quantity,
          unitPrice: row.unitPrice,
          subtotal: row.subtotal,
          unitName: unit?.name ?? '',
          unitType: unit?.type ?? 'medida',
        ),
      );
    }
    return result;
  }

  Future<void> createPurchase({
    required int? supplierId,
    required bool isMaterial,
    required String? description,
    required double totalAmount,
    required DateTime date,
    required int? locationId,
    required int? eventId,
    String? notes,
    required List<Map<String, dynamic>> items,
    bool adjustStock = true,
  }) async {
    await database.transaction(() async {
      final resolvedSupplierId = supplierId ?? await _defaultSupplierId();
      final purchaseId = await database
          .into(database.purchases)
          .insert(
            PurchasesCompanion.insert(
              supplierId: Value(resolvedSupplierId),
              isMaterial: Value(isMaterial),
              description: Value(description),
              totalAmount: round2(totalAmount),
              date: date,
              locationId: Value(locationId),
              eventId: Value(eventId),
              notes: Value(notes),
            ),
          );

      if (isMaterial) {
        for (final item in items) {
          final materialId = item['materialId'] as int;
          final quantity = await roundForMaterial(
            database,
            materialId,
            item['quantity'] as double,
          );
          final unitPrice = round2(item['unitPrice'] as double);

          await database
              .into(database.purchaseItems)
              .insert(
                PurchaseItemsCompanion.insert(
                  purchaseId: purchaseId,
                  materialId: materialId,
                  quantity: quantity,
                  unitPrice: unitPrice,
                  subtotal: round2(quantity * unitPrice),
                ),
              );

          if (!adjustStock) continue;

          final later = await _hasLaterPurchaseOf(
            materialId,
            excludingPurchaseId: purchaseId,
            date: date,
          );
          final material = await (database.select(
            database.materials,
          )..where((m) => m.id.equals(materialId))).getSingleOrNull();

          if (material != null) {
            await (database.update(
              database.materials,
            )..where((m) => m.id.equals(materialId))).write(
              MaterialsCompanion(
                stock: Value(
                  await roundForUnit(
                    database,
                    material.unitId,
                    material.stock + quantity,
                  ),
                ),
                pricePerUnit: later || _isFutureDated(date)
                    ? const Value.absent()
                    : Value(unitPrice),
                updatedAt: Value(appNow()),
              ),
            );
          }
        }
      }
    });
  }

  static const cancelBlockedMessage =
      'No se puede cancelar la compra porque el stock actual de uno de los '
      'materiales es menor a la cantidad comprada.';

  static const editBlockedMessage =
      'No se puede guardar la edición porque el stock actual de uno de los '
      'materiales es menor a la cantidad que se quitaría de la compra.';

  Future<String?> cancelPurchase(int purchaseId) async {
    return database.transaction(() async {
      final purchase = await (database.select(
        database.purchases,
      )..where((p) => p.id.equals(purchaseId))).getSingleOrNull();
      if (purchase == null) return 'Compra no encontrada';
      if (purchase.isCanceled) return 'La compra ya está cancelada';

      final items = purchase.isMaterial
          ? await (database.select(
              database.purchaseItems,
            )..where((pi) => pi.purchaseId.equals(purchaseId))).get()
          : const <PurchaseItem>[];

      final byMaterial = <int, double>{};
      for (final item in items) {
        byMaterial[item.materialId] =
            (byMaterial[item.materialId] ?? 0) + item.quantity;
      }

      final stocks = <int, double>{};
      for (final entry in byMaterial.entries) {
        final material = await (database.select(
          database.materials,
        )..where((m) => m.id.equals(entry.key))).getSingleOrNull();
        if (material == null) continue;
        final remaining = await roundForUnit(
          database,
          material.unitId,
          material.stock - entry.value,
        );
        if (remaining < 0) return cancelBlockedMessage;
        stocks[entry.key] = remaining;
      }

      final now = appNow();
      for (final entry in stocks.entries) {
        await (database.update(
          database.materials,
        )..where((m) => m.id.equals(entry.key))).write(
          MaterialsCompanion(
            stock: Value(entry.value),
            updatedAt: Value(now),
          ),
        );
      }

      await (database.update(
        database.purchases,
      )..where((p) => p.id.equals(purchaseId))).write(
        PurchasesCompanion(
          isCanceled: const Value(true),
          canceledAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return null;
    });
  }

  Future<String?> editPurchase({
    required int purchaseId,
    required int? supplierId,
    required bool isMaterial,
    required String? description,
    required double totalAmount,
    required DateTime date,
    required int? locationId,
    required int? eventId,
    String? notes,
    required List<Map<String, dynamic>> newItems,
  }) async {
    return database.transaction(() async {
      final current = await (database.select(
        database.purchases,
      )..where((p) => p.id.equals(purchaseId))).getSingleOrNull();
      if (current == null) return 'Compra no encontrada';
      if (current.isCanceled) {
        return 'La compra está cancelada y no se puede editar';
      }

      final resolvedSupplierId = supplierId ?? await _defaultSupplierId();

      final oldItems = await (database.select(
        database.purchaseItems,
      )..where((pi) => pi.purchaseId.equals(purchaseId))).get();

      final stockChange = <int, double>{};
      for (final oldItem in oldItems) {
        stockChange[oldItem.materialId] =
            (stockChange[oldItem.materialId] ?? 0) - oldItem.quantity;
      }
      if (isMaterial) {
        for (final item in newItems) {
          final materialId = item['materialId'] as int;
          final quantity = await roundForMaterial(
            database,
            materialId,
            item['quantity'] as double,
          );
          stockChange[materialId] = (stockChange[materialId] ?? 0) + quantity;
        }
      }
      for (final entry in stockChange.entries) {
        if (entry.value >= 0) continue;
        final material = await (database.select(
          database.materials,
        )..where((m) => m.id.equals(entry.key))).getSingleOrNull();
        if (material == null) continue;
        final remaining = await roundForUnit(
          database,
          material.unitId,
          material.stock + entry.value,
        );
        if (remaining < 0) return editBlockedMessage;
      }

      for (final oldItem in oldItems) {
        final material = await (database.select(
          database.materials,
        )..where((m) => m.id.equals(oldItem.materialId))).getSingleOrNull();
        if (material != null) {
          await (database.update(
            database.materials,
          )..where((m) => m.id.equals(oldItem.materialId))).write(
            MaterialsCompanion(
              stock: Value(
                await roundForUnit(
                  database,
                  material.unitId,
                  material.stock - oldItem.quantity,
                ),
              ),
              updatedAt: Value(appNow()),
            ),
          );
        }
      }

      await (database.delete(
        database.purchaseItems,
      )..where((pi) => pi.purchaseId.equals(purchaseId))).go();

      await (database.update(
        database.purchases,
      )..where((p) => p.id.equals(purchaseId))).write(
        PurchasesCompanion(
          supplierId: Value(resolvedSupplierId),
          isMaterial: Value(isMaterial),
          description: Value(description),
          totalAmount: Value(round2(totalAmount)),
          date: Value(date),
          locationId: Value(locationId),
          eventId: Value(eventId),
          notes: Value(notes),
          updatedAt: Value(appNow()),
        ),
      );

      if (isMaterial) {
        for (final item in newItems) {
          final materialId = item['materialId'] as int;
          final quantity = await roundForMaterial(
            database,
            materialId,
            item['quantity'] as double,
          );
          final unitPrice = round2(item['unitPrice'] as double);

          await database
              .into(database.purchaseItems)
              .insert(
                PurchaseItemsCompanion.insert(
                  purchaseId: purchaseId,
                  materialId: materialId,
                  quantity: quantity,
                  unitPrice: unitPrice,
                  subtotal: round2(quantity * unitPrice),
                ),
              );

          final later = await _hasLaterPurchaseOf(
            materialId,
            excludingPurchaseId: purchaseId,
            date: date,
          );
          final material = await (database.select(
            database.materials,
          )..where((m) => m.id.equals(materialId))).getSingleOrNull();

          if (material != null) {
            await (database.update(
              database.materials,
            )..where((m) => m.id.equals(materialId))).write(
              MaterialsCompanion(
                stock: Value(
                  await roundForUnit(
                    database,
                    material.unitId,
                    material.stock + quantity,
                  ),
                ),
                pricePerUnit: later || _isFutureDated(date)
                    ? const Value.absent()
                    : Value(unitPrice),
                updatedAt: Value(appNow()),
              ),
            );
          }
        }
      }
      return null;
    });
  }
}
