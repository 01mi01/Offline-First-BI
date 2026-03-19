import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/category_repository.dart';
import '../models/category_model.dart';
import 'database_provider.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
});

// Estado de categorías
class CategoryState {
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? error;

  CategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  CategoryState copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
    String? error,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CategoryNotifier extends StateNotifier<CategoryState> {
  final CategoryRepository repository;

  CategoryNotifier(this.repository) : super(CategoryState()) {
    load();
  }

  // Carga todas las categorías
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAllIncludingInactive();
      state = state.copyWith(categories: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Guarda o edita una categoría y recarga
  Future<void> save({
    int? id,
    required String name,
    String? description,
    String? image,
    bool isActive = true,
  }) async {
    await repository.save(
      id: id,
      name: name,
      description: description,
      image: image,
      isActive: isActive,
    );
    await load();
  }

  // Desactiva una categoría y recarga
  Future<void> deactivate(int id) async {
    await repository.deactivate(id);
    await load();
  }
}

final categoryProvider =
    StateNotifierProvider<CategoryNotifier, CategoryState>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return CategoryNotifier(repository);
});