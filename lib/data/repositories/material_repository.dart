import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/material_model.dart';
import '../../models/product_material_model.dart';

class MaterialRepository {
  final AppDatabase database;

  MaterialRepository(this.database);

  // Convierte fila a modelo
  MaterialModel _toModel(Material row) {
    return MaterialModel(
      id: row.id,
      name: row.name,
      description: row.description,
      stock: row.stock,
      pricePerUnit: row.pricePerUnit,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  // Obtiene todos los materiales incluyendo inactivos
  Future<List<MaterialModel>> getAllIncludingInactive() async {
    final rows = await (database.select(database.materials)
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .get();
    return rows.map(_toModel).toList();
  }

  // Obtiene solo materiales activos
  Future<List<MaterialModel>> getActive() async {
    final rows = await (database.select(database.materials)
          ..where((m) => m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .get();
    return rows.map(_toModel).toList();
  }

  // Guarda o actualiza un material
  Future<void> save({
    int? id,
    required String name,
    String? description,
    required double stock,
    required double pricePerUnit,
    bool isActive = true,
  }) async {
    final now = DateTime.now();
    await database.into(database.materials).insertOnConflictUpdate(
          MaterialsCompanion(
            id: id != null ? Value(id) : const Value.absent(),
            name: Value(name),
            description: Value(description),
            stock: Value(stock),
            pricePerUnit: Value(pricePerUnit),
            isActive: Value(isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  // Obtiene el log de uso de materiales para un producto
  Future<List<ProductMaterialModel>> getMaterialsForProduct(
      int productId) async {
    final rows = await (database.select(database.productMaterials)
          ..where((pm) => pm.productId.equals(productId))
          ..orderBy([(pm) => OrderingTerm.desc(pm.createdAt)]))
        .get();

    final result = <ProductMaterialModel>[];
    for (final row in rows) {
      final material = await (database.select(database.materials)
            ..where((m) => m.id.equals(row.materialId)))
          .getSingleOrNull();
      if (material != null) {
        result.add(ProductMaterialModel(
          id: row.id,
          productId: row.productId,
          materialId: row.materialId,
          materialName: material.name,
          quantityUsed: row.quantityUsed,
          pricePerUnit: material.pricePerUnit,
        ));
      }
    }
    return result;
  }

  // Obtiene nombres únicos de materiales usados en un producto
  Future<List<String>> getUniqueMaterialNamesForProduct(
      int productId) async {
    final rows = await (database.select(database.productMaterials)
          ..where((pm) => pm.productId.equals(productId)))
        .get();

    final names = <String>{};
    for (final row in rows) {
      final material = await (database.select(database.materials)
            ..where((m) => m.id.equals(row.materialId)))
          .getSingleOrNull();
      if (material != null) names.add(material.name);
    }
    return names.toList();
  }

  // Registra uso de material y descuenta del stock
  Future<String?> registerMaterialUsage({
    required int productId,
    required int materialId,
    required double quantityUsed,
  }) async {
    final material = await (database.select(database.materials)
          ..where((m) => m.id.equals(materialId)))
        .getSingleOrNull();

    if (material == null) return 'Material no encontrado';
    if (quantityUsed > material.stock) {
      return 'Stock insuficiente. Disponible: ${_fmt(material.stock)}';
    }

    await database.into(database.productMaterials).insert(
          ProductMaterialsCompanion.insert(
            productId: productId,
            materialId: materialId,
            quantityUsed: quantityUsed,
          ),
        );

    // Descuenta stock
    await (database.update(database.materials)
          ..where((m) => m.id.equals(materialId)))
        .write(MaterialsCompanion(
      stock: Value(material.stock - quantityUsed),
      updatedAt: Value(DateTime.now()),
    ));

    return null;
  }

  // Edita un registro de uso y ajusta el stock según la diferencia
  Future<String?> editMaterialUsage({
    required int recordId,
    required double newQuantity,
  }) async {
    final record = await (database.select(database.productMaterials)
          ..where((pm) => pm.id.equals(recordId)))
        .getSingleOrNull();

    if (record == null) return 'Registro no encontrado';

    final material = await (database.select(database.materials)
          ..where((m) => m.id.equals(record.materialId)))
        .getSingleOrNull();

    if (material == null) return 'Material no encontrado';

    final oldQuantity = record.quantityUsed;
    final difference = newQuantity - oldQuantity;

    // Si aumenta la cantidad, verificar que haya stock suficiente
    if (difference > 0 && difference > material.stock) {
      return 'Stock insuficiente. Disponible: ${_fmt(material.stock)}';
    }

    // Actualiza el registro
    await (database.update(database.productMaterials)
          ..where((pm) => pm.id.equals(recordId)))
        .write(ProductMaterialsCompanion(
      quantityUsed: Value(newQuantity),
    ));

    // Ajusta el stock según la diferencia
    await (database.update(database.materials)
          ..where((m) => m.id.equals(record.materialId)))
        .write(MaterialsCompanion(
      stock: Value(material.stock - difference),
      updatedAt: Value(DateTime.now()),
    ));

    return null;
  }

  // Formatea número eliminando decimales innecesarios
  String _fmt(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value.toString();
  }
}