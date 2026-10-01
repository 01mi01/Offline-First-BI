import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';

enum CategoryStatusFilter { all, active, inactive }

// Búsqueda por nombre y estado de Categorías. El filtro de estado se controla
// desde la vista de lista; el catálogo solo lo refleja.
class CategoryCatalogFilter {
  final String query;
  final CategoryStatusFilter status;

  const CategoryCatalogFilter({
    this.query = '',
    this.status = CategoryStatusFilter.all,
  });

  CategoryCatalogFilter copyWith({String? query, CategoryStatusFilter? status}) {
    return CategoryCatalogFilter(
      query: query ?? this.query,
      status: status ?? this.status,
    );
  }

  // Categorías que cumplen la búsqueda por nombre y el estado, en el orden en
  // que llegan (alfabético por nombre desde el repositorio).
  List<CategoryModel> apply(List<CategoryModel> categories) {
    final q = query.trim().toLowerCase();
    return categories.where((c) {
      switch (status) {
        case CategoryStatusFilter.all:
          break;
        case CategoryStatusFilter.active:
          if (!c.isActive) return false;
        case CategoryStatusFilter.inactive:
          if (c.isActive) return false;
      }
      return q.isEmpty || c.name.toLowerCase().contains(q);
    }).toList();
  }
}

final categoryCatalogFilterProvider =
    StateProvider.autoDispose<CategoryCatalogFilter>(
      (ref) => const CategoryCatalogFilter(),
    );
