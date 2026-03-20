import '../../data/db/app_database.dart';
import '../../models/category_model.dart';
import 'package:drift/drift.dart';

class CategoryRepository {
  final AppDatabase database;

  CategoryRepository(this.database);

  // Convierte fila de la base de datos a modelo
  CategoryModel _toModel(Category row) {
    return CategoryModel(
      id: row.id,
      name: row.name,
      description: row.description,
      image: row.image,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  // Obtiene todas las categorías activas
  Future<List<CategoryModel>> getAll() async {
    final rows =
        await (database.select(database.categories)
              ..where((c) => c.isActive.equals(true))
              ..orderBy([(c) => OrderingTerm.asc(c.name)]))
            .get();
    return rows.map(_toModel).toList();
  }

  // Obtiene todas incluyendo inactivas
  Future<List<CategoryModel>> getAllIncludingInactive() async {
    final rows = await (database.select(
      database.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
    return rows.map(_toModel).toList();
  }

  // Guarda o actualiza una categoría
  Future<void> save({
    int? id,
    required String name,
    String? description,
    String? image,
    bool isActive = true,
  }) async {
    final now = DateTime.now();
    await database
        .into(database.categories)
        .insertOnConflictUpdate(
          CategoriesCompanion(
            id: id != null ? Value(id) : const Value.absent(),
            name: Value(name),
            description: Value(description),
            image: Value(image),
            isActive: Value(isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  // Verifica si la categoría tiene productos activos
  Future<bool> hasActiveProducts(int categoryId) async {
    final rows =
        await (database.select(database.products)..where(
              (p) => p.categoryId.equals(categoryId) & p.isActive.equals(true),
            ))
            .get();
    return rows.isNotEmpty;
  }

  // Desactiva una categoría
  Future<void> deactivate(int id) async {
    await (database.update(
      database.categories,
    )..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
