import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import 'record_search.dart';

enum CategoryStatusFilter { all, active, inactive }

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

  List<CategoryModel> apply(
    List<CategoryModel> categories, {
    SearchIndex<CategoryModel>? index,
  }) {
    final found = (index ?? SearchIndex(categories, (c) => c.name))
        .search(query);
    return found.where((c) {
      switch (status) {
        case CategoryStatusFilter.all:
          return true;
        case CategoryStatusFilter.active:
          return c.isActive;
        case CategoryStatusFilter.inactive:
          return !c.isActive;
      }
    }).toList();
  }
}

final categoryCatalogFilterProvider =
    StateProvider.autoDispose<CategoryCatalogFilter>(
      (ref) => const CategoryCatalogFilter(),
    );
