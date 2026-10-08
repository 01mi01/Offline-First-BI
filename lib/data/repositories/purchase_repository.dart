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

  // Calcula el total de una compra de materiales a partir de sus ítems
  double calculateMaterialsTotal(List<Map<String, dynamic>> items) {
    // Cada línea y la suma van a dos decimales (centavos).
    double total = 0;
    for (final item in items) {
      total += round2(
        (item['quantity'] as double) * (item['unitPrice'] as double),
      );
    }
    return round2(total);
  }

  // Obtiene el id del proveedor "Sin proveedor", creándolo si hace falta
  // (mismo patrón que la categoría por defecto de ProductRepository): las
  // compras sin proveedor elegido nunca deben quedar bloqueadas ni sin
  // proveedor.
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

  // ¿Hay otra compra de este material con fecha posterior a [date]? Si la hay,
  // el precio vigente del material ya viene de esa compra más reciente.
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
            database.purchases.date.isBiggerThanValue(date),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  // Convierte fila a modelo
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

  // Obtiene todas las compras ordenadas por fecha descendente
  Future<List<PurchaseModel>> getAll() async {
    final rows = await (database.select(
      database.purchases,
    )..orderBy([(p) => OrderingTerm.desc(p.date)])).get();
    return rows.map(_toModel).toList();
  }

  // Obtiene los ítems de una compra con nombre del material
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

  // Registra una nueva compra y actualiza stock y precio del material
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
    // false cuando el stock de los materiales ya se registró por otro camino
    // (p. ej. la compra automática del stock inicial de un material nuevo): la
    // compra y sus ítems se guardan, pero no se vuelve a sumar el stock.
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
          // Cantidad según el tipo de unidad del material; precio a centavos.
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

          // Suma stock y actualiza precio del material
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
                // Una compra con fecha pasada no pisa el precio que ya fijó
                // una compra posterior del mismo material.
                pricePerUnit: later
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

  // Cancela una compra en vez de borrarla: resta del stock de cada material lo
  // que se compró (un gasto general no toca el stock) y la marca como
  // cancelada, conservándola como historial. Todo en una transacción. Si algún
  // material quedaría con stock negativo (porque ya se usó), no cambia nada y
  // devuelve [cancelBlockedMessage]. Devuelve un mensaje de error, o null si
  // salió bien.
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

      // Cantidad comprada por material (un material puede repetirse).
      final byMaterial = <int, double>{};
      for (final item in items) {
        byMaterial[item.materialId] =
            (byMaterial[item.materialId] ?? 0) + item.quantity;
      }

      // Primero se valida todo: nada cambia si alguno quedaría en negativo.
      final stocks = <int, double>{};
      for (final entry in byMaterial.entries) {
        final material = await (database.select(
          database.materials,
        )..where((m) => m.id.equals(entry.key))).getSingleOrNull();
        if (material == null) continue;
        // Se compara el valor ya redondeado: el ruido de coma flotante
        // (72.6 - 15) no provoca un bloqueo falso ni deja pasar uno real.
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

  // Edita una compra existente y ajusta stock. Devuelve un mensaje de error
  // (p. ej. si la compra está cancelada), o null si salió bien.
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

      // Devuelve el stock de los ítems anteriores
      final oldItems = await (database.select(
        database.purchaseItems,
      )..where((pi) => pi.purchaseId.equals(purchaseId))).get();

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

      // Elimina ítems anteriores
      await (database.delete(
        database.purchaseItems,
      )..where((pi) => pi.purchaseId.equals(purchaseId))).go();

      // Actualiza la compra
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

      // Inserta nuevos ítems y suma stock con precio actualizado
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
                pricePerUnit: later
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
