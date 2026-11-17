import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/access_control.dart';
import 'module_permission_provider.dart';
import '../data/repositories/name_rules.dart';
import '../data/repositories/product_repository.dart';
import '../models/product_model.dart';
import 'database_provider.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProductRepository(db);
});

class ProductState {
  final List<ProductModel> products;
  final bool isLoading;
  final String? error;

  ProductState({
    this.products = const [],
    this.isLoading = false,
    this.error,
  });

  ProductState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    String? error,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProductNotifier extends StateNotifier<ProductState> {
  final ProductRepository repository;
  final AccessGuard guard;

  ProductNotifier(this.repository, {this.guard = AccessGuard.none})
    : super(ProductState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAllIncludingInactive();
      state = state.copyWith(products: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<String?> save({
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
    final current = id == null
        ? null
        : state.products.where((p) => p.id == id).firstOrNull;
    final denied = guard.checkSave(
      AppModule.inventario,
      isNew: id == null,
      activeChanged: current != null && current.isActive != isActive,
    );
    if (denied != null) return denied;
    return _persist(
      id: id,
      categoryId: categoryId,
      name: name,
      description: description,
      image: image,
      priceA: priceA,
      priceB: priceB,
      productionCost: productionCost,
      stock: stock,
      isActive: isActive,
    );
  }

  Future<String?> setActive(int id, bool isActive) async {
    final denied = guard.check(AppModule.inventario, ModuleAction.deactivate);
    if (denied != null) return denied;
    final p = state.products.where((p) => p.id == id).firstOrNull;
    if (p == null) return 'El producto no existe';
    return _persist(
      id: p.id,
      categoryId: p.categoryId,
      name: p.name,
      description: p.description,
      image: p.image,
      priceA: p.priceA,
      priceB: p.priceB,
      productionCost: p.productionCost,
      stock: p.stock,
      isActive: isActive,
    );
  }

  Future<String?> _persist({
    int? id,
    int? categoryId,
    required String name,
    String? description,
    String? image,
    double? priceA,
    double? priceB,
    double? productionCost,
    required int stock,
    required bool isActive,
  }) async {
    try {
      await repository.save(
        id: id,
        categoryId: categoryId,
        name: name,
        description: description,
        image: image,
        priceA: priceA,
        priceB: priceB,
        productionCost: productionCost,
        stock: stock,
        isActive: isActive,
      );
    } on InvalidNameException catch (e) {
      return e.message;
    } on Exception catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
    await load();
    return null;
  }
}

final productProvider =
    StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductNotifier(repository, guard: ref.watch(accessGuardProvider));
});