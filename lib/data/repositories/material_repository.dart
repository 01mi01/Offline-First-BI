import 'name_rules.dart';
import '../../config/quantity_format.dart';
import 'package:drift/drift.dart';
import '../../config/rounding.dart';
import '../../data/db/app_database.dart';
import '../../models/material_model.dart';
import '../../models/product_material_model.dart';
import '../../models/unit_model.dart';
import 'purchase_repository.dart';
import 'stock_rounding.dart';
import '../../config/app_clock.dart';

class MaterialRepository {
  final AppDatabase database;

  MaterialRepository(this.database);

  MaterialModel _toModel(Material row) {
    return MaterialModel(
      id: row.id,
      name: row.name,
      description: row.description,
      unitId: row.unitId,
      stock: row.stock,
      pricePerUnit: row.pricePerUnit,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  Future<List<MaterialModel>> getAllIncludingInactive() async {
    final rows = await (database.select(
      database.materials,
    )..orderBy([(m) => OrderingTerm.asc(m.name)])).get();
    return rows.map(_toModel).toList();
  }

  static const String initialStockPurchaseNote = 'Stock inicial del material';

  Future<int> save({
    int? id,
    required String name,
    String? description,
    required int unitId,
    required double stock,
    required double pricePerUnit,
    bool isActive = true,
  }) async {
    name = requireName(name);
    final now = appNow();
    stock = await roundForUnit(database, unitId, stock);
    pricePerUnit = round2(pricePerUnit);
    if (id != null) {
      final current = await (database.select(
        database.materials,
      )..where((m) => m.id.equals(id))).getSingleOrNull();
      if (current != null && current.unitId != unitId) {
        final from = await (database.select(
          database.units,
        )..where((u) => u.id.equals(current.unitId))).getSingleOrNull();
        final to = await (database.select(
          database.units,
        )..where((u) => u.id.equals(unitId))).getSingleOrNull();
        if (from == null || to == null || from.type != to.type) {
          throw ArgumentError(unitTypeChangeMessage);
        }
      }
    }
    return database.transaction(() async {
      final savedId = await database
          .into(database.materials)
          .insertOnConflictUpdate(
            MaterialsCompanion(
              id: id != null ? Value(id) : const Value.absent(),
              name: Value(name),
              description: Value(description),
              unitId: Value(unitId),
              stock: Value(stock),
              pricePerUnit: Value(pricePerUnit),
              isActive: Value(isActive),
              createdAt: id == null ? Value(now) : const Value.absent(),
              updatedAt: Value(now),
            ),
          );

      if (id == null && stock > 0) {
        await PurchaseRepository(database).createPurchase(
          supplierId: null,
          isMaterial: true,
          description: null,
          totalAmount: round2(stock * pricePerUnit),
          date: now,
          locationId: null,
          eventId: null,
          notes: initialStockPurchaseNote,
          items: [
            {
              'materialId': savedId,
              'quantity': stock,
              'unitPrice': pricePerUnit,
            },
          ],
          adjustStock: false,
        );
      }
      return id ?? savedId;
    });
  }

  Future<List<ProductMaterialModel>> getMaterialsForProduct(
    int productId,
  ) async {
    final rows =
        await (database.select(database.productMaterials)
              ..where((pm) => pm.productId.equals(productId))
              ..orderBy([(pm) => OrderingTerm.desc(pm.createdAt)]))
            .get();

    final result = <ProductMaterialModel>[];
    for (final row in rows) {
      final materialWithUnit =
          await (database.select(database.materials).join([
                innerJoin(
                  database.units,
                  database.units.id.equalsExp(database.materials.unitId),
                ),
              ])..where(database.materials.id.equals(row.materialId)))
              .getSingleOrNull();
      if (materialWithUnit != null) {
        final material = materialWithUnit.readTable(database.materials);
        final unit = materialWithUnit.readTable(database.units);
        result.add(
          ProductMaterialModel(
            id: row.id,
            productId: row.productId,
            materialId: row.materialId,
            materialName: material.name,
            materialUnitName: unit.name,
            materialUnitType: unit.type,
            quantityUsed: row.quantityUsed,
            pricePerUnit: material.pricePerUnit,
            isCanceled: row.isCanceled,
            canceledAt: row.canceledAt,
          ),
        );
      }
    }
    return result;
  }

  Future<List<String>> getUniqueMaterialNamesForProduct(int productId) async {
    final rows =
        await (database.select(database.productMaterials)..where(
              (pm) =>
                  pm.productId.equals(productId) &
                  pm.isCanceled.equals(false),
            ))
            .get();

    final names = <String>{};
    for (final row in rows) {
      final material = await (database.select(
        database.materials,
      )..where((m) => m.id.equals(row.materialId))).getSingleOrNull();
      if (material != null) names.add(material.name);
    }
    return names.toList();
  }

  Future<List<Map<String, dynamic>>> getMaterialsWithPriceForProduct(
    int productId,
  ) async {
    final rows =
        await (database.select(database.productMaterials)..where(
              (pm) =>
                  pm.productId.equals(productId) &
                  pm.isCanceled.equals(false),
            ))
            .get();

    final seen = <int>{};
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (seen.contains(row.materialId)) continue;
      seen.add(row.materialId);
      final material = await (database.select(
        database.materials,
      )..where((m) => m.id.equals(row.materialId))).getSingleOrNull();
      if (material != null) {
        final unit = await (database.select(
          database.units,
        )..where((u) => u.id.equals(material.unitId))).getSingleOrNull();
        result.add({
          'name': material.name,
          'price': material.pricePerUnit,
          'unit': unit?.name ?? 'unidad',
        });
      }
    }
    return result;
  }

  Future<String?> registerMaterialUsage({
    required int productId,
    required int materialId,
    required double quantityUsed,
  }) async {
    return database.transaction(() async {
      final material = await (database.select(
        database.materials,
      )..where((m) => m.id.equals(materialId))).getSingleOrNull();

      if (material == null) return 'Material no encontrado';
      quantityUsed = await roundForUnit(database, material.unitId, quantityUsed);
      final available = await roundForUnit(
        database,
        material.unitId,
        material.stock,
      );

      final existing = await (database.select(database.productMaterials)..where(
            (pm) =>
                pm.productId.equals(productId) &
                pm.materialId.equals(materialId),
          ))
          .getSingleOrNull();

      if (existing != null && existing.isCanceled) {
        if (quantityUsed > available) {
          return 'Stock insuficiente. Disponible: ${await _fmt(material)}';
        }
        final now = appNow();
        await database.transaction(() async {
          await (database.update(
            database.productMaterials,
          )..where((pm) => pm.id.equals(existing.id))).write(
            ProductMaterialsCompanion(
              quantityUsed: Value(quantityUsed),
              isCanceled: const Value(false),
              canceledAt: const Value(null),
              updatedAt: Value(now),
            ),
          );
          await (database.update(
            database.materials,
          )..where((m) => m.id.equals(materialId))).write(
            MaterialsCompanion(
              stock: Value(
                await roundForUnit(
                  database,
                  material.unitId,
                  material.stock - quantityUsed,
                ),
              ),
              updatedAt: Value(now),
            ),
          );
        });
        return null;
      }

      if (existing != null) {
        return editMaterialUsage(
          recordId: existing.id,
          newQuantity: existing.quantityUsed + quantityUsed,
        );
      }

      if (quantityUsed > available) {
        return 'Stock insuficiente. Disponible: ${await _fmt(material)}';
      }

      await database
          .into(database.productMaterials)
          .insert(
            ProductMaterialsCompanion.insert(
              productId: productId,
              materialId: materialId,
              quantityUsed: quantityUsed,
            ),
          );

      await (database.update(
        database.materials,
      )..where((m) => m.id.equals(materialId))).write(
        MaterialsCompanion(
          stock: Value(
            await roundForUnit(
              database,
              material.unitId,
              material.stock - quantityUsed,
            ),
          ),
          updatedAt: Value(appNow()),
        ),
      );

      return null;
    });
  }

  Future<String?> editMaterialUsage({
    required int recordId,
    required double newQuantity,
  }) async {
    return database.transaction(() async {
      final record = await (database.select(
        database.productMaterials,
      )..where((pm) => pm.id.equals(recordId))).getSingleOrNull();

      if (record == null) return 'Registro no encontrado';
      if (record.isCanceled) {
        return 'El registro está cancelado y no se puede editar';
      }

      final material = await (database.select(
        database.materials,
      )..where((m) => m.id.equals(record.materialId))).getSingleOrNull();

      if (material == null) return 'Material no encontrado';

      newQuantity = await roundForUnit(database, material.unitId, newQuantity);
      final oldQuantity = record.quantityUsed;
      final difference = await roundForUnit(
        database,
        material.unitId,
        newQuantity - oldQuantity,
      );
      final available = await roundForUnit(
        database,
        material.unitId,
        material.stock,
      );

      if (difference > 0 && difference > available) {
        return 'Stock insuficiente. Disponible: ${await _fmt(material)}';
      }

      await (database.update(database.productMaterials)
            ..where((pm) => pm.id.equals(recordId)))
          .write(ProductMaterialsCompanion(
        quantityUsed: Value(newQuantity),
        updatedAt: Value(appNow()),
      ));

      await (database.update(
        database.materials,
      )..where((m) => m.id.equals(record.materialId))).write(
        MaterialsCompanion(
          stock: Value(
            await roundForUnit(
              database,
              material.unitId,
              material.stock - difference,
            ),
          ),
          updatedAt: Value(appNow()),
        ),
      );

      return null;
    });
  }

  Future<String?> cancelMaterialUsage(int recordId) async {
    return database.transaction(() async {
      final record = await (database.select(
        database.productMaterials,
      )..where((pm) => pm.id.equals(recordId))).getSingleOrNull();

      if (record == null) return 'Registro no encontrado';
      if (record.isCanceled) return 'El registro ya está cancelado';

      final material = await (database.select(
        database.materials,
      )..where((m) => m.id.equals(record.materialId))).getSingleOrNull();

      if (material == null) return 'Material no encontrado';

      final now = appNow();
      await (database.update(
        database.materials,
      )..where((m) => m.id.equals(record.materialId))).write(
        MaterialsCompanion(
          stock: Value(
            await roundForUnit(
              database,
              material.unitId,
              material.stock + record.quantityUsed,
            ),
          ),
          updatedAt: Value(now),
        ),
      );
      await (database.update(
        database.productMaterials,
      )..where((pm) => pm.id.equals(recordId))).write(
        ProductMaterialsCompanion(
          isCanceled: const Value(true),
          canceledAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return null;
    });
  }

  Future<String> _fmt(Material material) async {
    final unit = await (database.select(
      database.units,
    )..where((u) => u.id.equals(material.unitId))).getSingleOrNull();
    return quantityWithUnit(material.stock, unit?.name);
  }
}
