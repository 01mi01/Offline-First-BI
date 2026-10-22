import '../../data/db/app_database.dart';
import '../../models/category_model.dart';
import '../../models/default_records.dart';
import 'package:drift/drift.dart';
import '../../config/app_clock.dart';
import 'name_rules.dart';

class CategoryRepository {
  final AppDatabase database;

  CategoryRepository(this.database);

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

  Future<List<CategoryModel>> getAllIncludingInactive() async {
    final rows = await (database.select(
      database.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
    return rows.map(_toModel).toList();
  }

  Future<void> _ensureNotProtected({int? id, String? newName}) async {
    if (id != null) {
      final current = await (database.select(
        database.categories,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (current != null && DefaultRecords.isCategory(current.name)) {
        throw const ProtectedRecordException(DefaultRecords.protectedCategoryMessage);
      }
    }
    if (newName != null && DefaultRecords.isCategory(newName)) {
      throw const ProtectedRecordException(DefaultRecords.reservedNameMessage);
    }
  }

  Future<void> save({
    int? id,
    required String name,
    String? description,
    String? image,
    bool isActive = true,
  }) async {
    name = requireName(name);
    await _ensureNotProtected(id: id, newName: name);
    final now = appNow();
    await database
        .into(database.categories)
        .insertOnConflictUpdate(
          CategoriesCompanion(
            id: id != null ? Value(id) : const Value.absent(),
            name: Value(name),
            description: Value(description),
            image: Value(image),
            isActive: Value(isActive),
            createdAt: id == null ? Value(now) : const Value.absent(),
            updatedAt: Value(now),
          ),
        );
  }

  Future<bool> hasActiveProducts(int categoryId) async {
    final rows =
        await (database.select(database.products)..where(
              (p) => p.categoryId.equals(categoryId) & p.isActive.equals(true),
            ))
            .get();
    return rows.isNotEmpty;
  }

  Future<void> deactivate(int id) async {
    await _ensureNotProtected(id: id);
    await (database.update(
      database.categories,
    )..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        isActive: const Value(false),
        updatedAt: Value(appNow()),
      ),
    );
  }
}
