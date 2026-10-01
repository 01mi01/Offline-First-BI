import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';

enum CategoryStatusFilter { all, active, inactive }

enum CategorySort { nameAsc, nameDesc }

// Búsqueda, estado y orden de Categorías (vistas de lista y de catálogo). Las
// categorías no tienen precio, así que los filtros son por texto y por estado.
class CategoryCatalogFilter {
  final String query;
  final CategoryStatusFilter status;
  final CategorySort sort;

  const CategoryCatalogFilter({
    this.query = '',
    this.status = CategoryStatusFilter.all,
    this.sort = CategorySort.nameAsc,
  });

  CategoryCatalogFilter copyWith({
    String? query,
    CategoryStatusFilter? status,
    CategorySort? sort,
  }) {
    return CategoryCatalogFilter(
      query: query ?? this.query,
      status: status ?? this.status,
      sort: sort ?? this.sort,
    );
  }

  List<CategoryModel> apply(List<CategoryModel> categories) {
    final q = query.trim().toLowerCase();
    final result = categories.where((c) {
      switch (status) {
        case CategoryStatusFilter.all:
          break;
        case CategoryStatusFilter.active:
          if (!c.isActive) return false;
        case CategoryStatusFilter.inactive:
          if (c.isActive) return false;
      }
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          (c.description ?? '').toLowerCase().contains(q);
    }).toList();

    result.sort((a, b) {
      final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return sort == CategorySort.nameAsc ? c : -c;
    });
    return result;
  }
}

final categoryCatalogFilterProvider =
    StateProvider.autoDispose<CategoryCatalogFilter>(
      (ref) => const CategoryCatalogFilter(),
    );
