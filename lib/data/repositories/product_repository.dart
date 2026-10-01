import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/default_records.dart';
import '../../models/product_model.dart';

class ProductRepository {
  final AppDatabase database;

  ProductRepository(this.database);

  // Convierte fila de la base de datos a modelo
  ProductModel _toModel(Product row) {
    return ProductModel(
      id: row.id,
      categoryId: row.categoryId,
      name: row.name,
      description: row.description,
      image: row.image,
      priceA: row.priceA,
      priceB: row.priceB,
      productionCost: row.productionCost,
      stock: row.stock,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  // Obtiene todos los productos incluyendo inactivos
  Future<List<ProductModel>> getAllIncludingInactive() async {
    final rows = await (database.select(database.products)
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
    return rows.map(_toModel).toList();
  }

  // Obtiene solo productos activos para ventas y dropdowns
  Future<List<ProductModel>> getActive() async {
    final rows = await (database.select(database.products)
          ..where((p) => p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
    return rows.map(_toModel).toList();
  }

  // Guarda o actualiza un producto. Si no se indica categoría, se asigna la
  // categoría "Sin categoría" (creándola si todavía no existe): la categoría
  // es obligatoria a nivel de esquema, pero el usuario nunca debe verse
  // bloqueado por no haber elegido una.
  Future<void> save({
    int? id,
    int? categoryId,
    required String name,
    String? description,
    String? image,
    double? priceA,
    double? priceB,
    double? productionCost,
    required int stock,
    bool isActive = true,
  }) async {
    // Solo hace falta un precio: el otro se iguala (ver resolveProductPrices).
    final prices = resolveProductPrices(priceA, priceB);
    final now = DateTime.now();
    await database.into(database.products).insertOnConflictUpdate(
          ProductsCompanion(
            id: id != null ? Value(id) : const Value.absent(),
            categoryId: Value(categoryId ?? await _defaultCategoryId()),
            name: Value(name),
            description: Value(description),
            image: Value(image),
            priceA: Value(prices.priceA),
            priceB: Value(prices.priceB),
            productionCost: Value(productionCost),
            stock: Value(stock),
            isActive: Value(isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  // Obtiene el id de la categoría "Sin categoría", creándola si hace falta
  Future<int> _defaultCategoryId() async {
    final existing = await (database.select(
      database.categories,
    )..where((c) => c.name.equals(DefaultRecords.category))).getSingleOrNull();
    if (existing != null) return existing.id;
    return await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(name: DefaultRecords.category));
  }

  // Actualiza el stock de un producto
  Future<void> updateStock(int id, int newStock) async {
    await (database.update(database.products)..where((p) => p.id.equals(id)))
        .write(ProductsCompanion(
      stock: Value(newStock),
      updatedAt: Value(DateTime.now()),
    ));
  }
}