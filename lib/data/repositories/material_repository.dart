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

  // Convierte fila a modelo
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

  // Obtiene todos los materiales incluyendo inactivos
  Future<List<MaterialModel>> getAllIncludingInactive() async {
    final rows = await (database.select(
      database.materials,
    )..orderBy([(m) => OrderingTerm.asc(m.name)])).get();
    return rows.map(_toModel).toList();
  }

  // Obtiene solo materiales activos
  Future<List<MaterialModel>> getActive() async {
    final rows =
        await (database.select(database.materials)
              ..where((m) => m.isActive.equals(true))
              ..orderBy([(m) => OrderingTerm.asc(m.name)]))
            .get();
    return rows.map(_toModel).toList();
  }

  // Nota de la compra que se crea sola con el stock inicial de un material.
  static const String initialStockPurchaseNote = 'Stock inicial del material';

  // Guarda o actualiza un material. Al CREAR uno con stock inicial mayor a
  // cero se registra también la compra (tipo Material) que lo respalda, en la
  // misma transacción: el material y su compra nunca quedan desfasados. El
  // stock no se suma dos veces (el material ya nace con él).
  Future<void> save({
    int? id,
    required String name,
    String? description,
    required int unitId,
    required double stock,
    required double pricePerUnit,
    bool isActive = true,
  }) async {
    final now = appNow();
    // Lo que se guarda va redondeado: precio a centavos y stock según el tipo
    // de su unidad (dos decimales, o fracciones sin ruido).
    stock = await roundForUnit(database, unitId, stock);
    pricePerUnit = round2(pricePerUnit);
    // Al editar, la unidad solo puede cambiar a otra del mismo tipo (ver
    // selectableUnitsFor): la interfaz ya solo ofrece esas, y esto lo garantiza
    // también al guardar.
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
    await database.transaction(() async {
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
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      if (id == null && stock > 0) {
        await PurchaseRepository(database).createPurchase(
          supplierId: null, // "Sin proveedor"
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
    });
  }

  // Obtiene el log de uso de materiales para un producto
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

  // Obtiene nombres únicos de materiales usados en un producto
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

  // Obtiene materiales únicos con nombre y precio para un producto
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

  // Vincula un material a un producto y descuenta del stock. product_materials
  // es la receta del producto (una fila por par producto+material, con
  // índice único), no un historial: si el par ya existe, esto suma la nueva
  // cantidad a esa fila en vez de crear un duplicado, delegando en
  // editMaterialUsage para reutilizar su ajuste de stock por diferencia.
  Future<String?> registerMaterialUsage({
    required int productId,
    required int materialId,
    required double quantityUsed,
  }) async {
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
      // El par producto+material es único: volver a registrar el uso de un
      // registro cancelado reactiva esa misma fila.
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
      // Registrar de nuevo un par ya vinculado SUMA a lo ya registrado (0.25 +
      // 0.75 = 1.0). El stock baja solo por lo nuevo: editMaterialUsage
      // descuenta la diferencia entre la cantidad nueva y la anterior, que
      // aquí es justamente [quantityUsed]. Para corregir una cantidad (reemplazo
      // directo) está el flujo de edición, que llama a editMaterialUsage con la
      // cantidad final.
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

    // Descuenta stock
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
  }

  // Edita un registro de uso y ajusta el stock según la diferencia
  Future<String?> editMaterialUsage({
    required int recordId,
    required double newQuantity,
  }) async {
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

    // Si aumenta la cantidad, verificar que haya stock suficiente
    if (difference > 0 && difference > available) {
      return 'Stock insuficiente. Disponible: ${await _fmt(material)}';
    }

    // Actualiza el registro
    await (database.update(database.productMaterials)
          ..where((pm) => pm.id.equals(recordId)))
        .write(ProductMaterialsCompanion(
      quantityUsed: Value(newQuantity),
      updatedAt: Value(appNow()),
    ));

    // Ajusta el stock según la diferencia
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
  }

  // Cancela un registro de uso en vez de borrarlo: devuelve al material la
  // cantidad que había descontado y marca el registro como cancelado,
  // conservándolo como historial. Devuelve un mensaje de error, o null si
  // salió bien.
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

  // Stock de un material tal como se muestra en los mensajes: según su unidad
  // (dos decimales para medidas; fracciones sin ruido).
  Future<String> _fmt(Material material) async {
    final unit = await (database.select(
      database.units,
    )..where((u) => u.id.equals(material.unitId))).getSingleOrNull();
    return formatMaterialQuantity(
      material.stock,
      unitType: unit?.type ?? 'medida',
      unitName: unit?.name ?? '',
    );
  }
}
