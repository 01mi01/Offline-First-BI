import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/purchase_model.dart';
import '../../models/purchase_item_model.dart';

class PurchaseRepository {
  final AppDatabase database;

  PurchaseRepository(this.database);

  // Calcula el total de una compra de materiales a partir de sus ítems
  double calculateMaterialsTotal(List<Map<String, dynamic>> items) {
    double total = 0;
    for (final item in items) {
      total += (item['quantity'] as double) * (item['unitPrice'] as double);
    }
    return total;
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
    final now = DateTime.now();
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
      result.add(
        PurchaseItemModel(
          id: row.id,
          purchaseId: row.purchaseId,
          materialId: row.materialId,
          materialName: material?.name ?? 'Material eliminado',
          quantity: row.quantity,
          unitPrice: row.unitPrice,
          subtotal: row.subtotal,
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
              totalAmount: totalAmount,
              date: date,
              locationId: Value(locationId),
              eventId: Value(eventId),
              notes: Value(notes),
            ),
          );

      if (isMaterial) {
        for (final item in items) {
          final materialId = item['materialId'] as int;
          final quantity = item['quantity'] as double;
          final unitPrice = item['unitPrice'] as double;

          await database
              .into(database.purchaseItems)
              .insert(
                PurchaseItemsCompanion.insert(
                  purchaseId: purchaseId,
                  materialId: materialId,
                  quantity: quantity,
                  unitPrice: unitPrice,
                  subtotal: quantity * unitPrice,
                ),
              );

          if (!adjustStock) continue;

          // Suma stock y actualiza precio del material
          final material = await (database.select(
            database.materials,
          )..where((m) => m.id.equals(materialId))).getSingleOrNull();

          if (material != null) {
            await (database.update(
              database.materials,
            )..where((m) => m.id.equals(materialId))).write(
              MaterialsCompanion(
                stock: Value(material.stock + quantity),
                pricePerUnit: Value(unitPrice),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }
      }
    });
  }

  // Edita una compra existente y ajusta stock
  Future<void> editPurchase({
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
    await database.transaction(() async {
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
              stock: Value(material.stock - oldItem.quantity),
              updatedAt: Value(DateTime.now()),
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
          totalAmount: Value(totalAmount),
          date: Value(date),
          locationId: Value(locationId),
          eventId: Value(eventId),
          notes: Value(notes),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Inserta nuevos ítems y suma stock con precio actualizado
      if (isMaterial) {
        for (final item in newItems) {
          final materialId = item['materialId'] as int;
          final quantity = item['quantity'] as double;
          final unitPrice = item['unitPrice'] as double;

          await database
              .into(database.purchaseItems)
              .insert(
                PurchaseItemsCompanion.insert(
                  purchaseId: purchaseId,
                  materialId: materialId,
                  quantity: quantity,
                  unitPrice: unitPrice,
                  subtotal: quantity * unitPrice,
                ),
              );

          final material = await (database.select(
            database.materials,
          )..where((m) => m.id.equals(materialId))).getSingleOrNull();

          if (material != null) {
            await (database.update(
              database.materials,
            )..where((m) => m.id.equals(materialId))).write(
              MaterialsCompanion(
                stock: Value(material.stock + quantity),
                pricePerUnit: Value(unitPrice),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }
      }
    });
  }
}
