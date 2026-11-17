import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/access_control.dart';
import 'module_permission_provider.dart';
import '../data/repositories/category_repository.dart';
import '../models/category_model.dart';
import '../models/default_records.dart';
import 'database_provider.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
});

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
  final AccessGuard guard;

  CategoryNotifier(this.repository, {this.guard = AccessGuard.none})
    : super(CategoryState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAllIncludingInactive();
      state = state.copyWith(categories: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> save({
    int? id,
    required String name,
    String? description,
    String? image,
    bool isActive = true,
  }) async {
    final current = id == null
        ? null
        : state.categories.where((c) => c.id == id).firstOrNull;
    final denied = guard.checkSave(
      AppModule.inventario,
      isNew: id == null,
      activeChanged: current != null && current.isActive != isActive,
    );
    if (denied != null) {
      state = state.copyWith(error: denied);
      return;
    }
    await _persist(
      id: id,
      name: name,
      description: description,
      image: image,
      isActive: isActive,
    );
  }

  Future<void> setActive(int id, bool isActive) async {
    final denied = guard.check(AppModule.inventario, ModuleAction.deactivate);
    if (denied != null) {
      state = state.copyWith(error: denied);
      return;
    }
    final c = state.categories.where((c) => c.id == id).firstOrNull;
    if (c == null) return;
    await _persist(
      id: c.id,
      name: c.name,
      description: c.description,
      image: c.image,
      isActive: isActive,
    );
  }

  Future<void> _persist({
    int? id,
    required String name,
    String? description,
    String? image,
    required bool isActive,
  }) async {
    if (id != null && !isActive) {
      final hasActive = await repository.hasActiveProducts(id);
      if (hasActive) {
        state = state.copyWith(
          error: 'No se puede desactivar una categoría con productos activos.',
        );
        return;
      }
    }
    state = state.copyWith(error: null);
    try {
      await repository.save(
        id: id,
        name: name,
        description: description,
        image: image,
        isActive: isActive,
      );
    } on ProtectedRecordException catch (e) {
      state = state.copyWith(error: e.message);
      return;
    }
    await load();
  }

  Future<void> deactivate(int id) async {
    final denied = guard.check(AppModule.inventario, ModuleAction.deactivate);
    if (denied != null) {
      state = state.copyWith(error: denied);
      return;
    }
    try {
      await repository.deactivate(id);
    } on ProtectedRecordException catch (e) {
      state = state.copyWith(error: e.message);
      return;
    }
    await load();
  }
}

final categoryProvider = StateNotifierProvider<CategoryNotifier, CategoryState>(
  (ref) {
    final repository = ref.watch(categoryRepositoryProvider);
    return CategoryNotifier(repository, guard: ref.watch(accessGuardProvider));
  },
);
