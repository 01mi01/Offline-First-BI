import 'package:drift/drift.dart';
import '../../config/rounding.dart';
import '../../data/db/app_database.dart';
import '../../models/default_records.dart';
import '../../models/product_model.dart';
import '../../config/app_clock.dart';
import 'name_rules.dart';

const String duplicateProductMessage = 'Ya existe un producto con ese nombre';

class ProductRepository {
  final AppDatabase database;

  ProductRepository(this.database);

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

  Future<List<ProductModel>> getAllIncludingInactive() async {
    final rows = await (database.select(database.products)
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
    return rows.map(_toModel).toList();
  }

  Future<List<ProductModel>> getActive() async {
    final rows = await (database.select(database.products)
          ..where((p) => p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
    return rows.map(_toModel).toList();
  }

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
    name = requireName(name);
    await _ensureUniqueName(name, id);
    final prices = resolveProductPrices(priceA, priceB);
    final now = appNow();
    await database.into(database.products).insertOnConflictUpdate(
          ProductsCompanion(
            id: id != null ? Value(id) : const Value.absent(),
            categoryId: Value(categoryId ?? await _defaultCategoryId()),
            name: Value(name),
            description: Value(description),
            image: Value(image),
            priceA: Value(round2(prices.priceA)),
            priceB: Value(round2(prices.priceB)),
            productionCost: Value(
              productionCost == null ? null : round2(productionCost),
            ),
            stock: Value(stock),
            isActive: Value(isActive),
            createdAt: id == null ? Value(now) : const Value.absent(),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> _ensureUniqueName(String name, int? id) async {
    final rows = await database.select(database.products).get();
    for (final row in rows) {
      if (row.id != id && sameName(row.name, name)) {
        throw Exception(duplicateProductMessage);
      }
    }
  }

  Future<int> _defaultCategoryId() async {
    final existing = await (database.select(
      database.categories,
    )..where((c) => c.name.equals(DefaultRecords.category))).getSingleOrNull();
    if (existing != null) return existing.id;
    return await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(name: DefaultRecords.category));
  }
}