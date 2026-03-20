import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
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
      salePrice: row.salePrice,
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

  // Guarda o actualiza un producto
  Future<void> save({
    int? id,
    int? categoryId,
    required String name,
    String? description,
    String? image,
    required double salePrice,
    double? productionCost,
    required int stock,
    bool isActive = true,
  }) async {
    final now = DateTime.now();
    await database.into(database.products).insertOnConflictUpdate(
          ProductsCompanion(
            id: id != null ? Value(id) : const Value.absent(),
            categoryId: Value(categoryId),
            name: Value(name),
            description: Value(description),
            image: Value(image),
            salePrice: Value(salePrice),
            productionCost: Value(productionCost),
            stock: Value(stock),
            isActive: Value(isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
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