import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/product_repository.dart';
import '../models/product_model.dart';
import 'database_provider.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProductRepository(db);
});

// Estado de productos
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

  ProductNotifier(this.repository) : super(ProductState()) {
    load();
  }

  // Carga todos los productos
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAllIncludingInactive();
      state = state.copyWith(products: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Guarda o edita un producto y recarga
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
    await repository.save(
      id: id,
      categoryId: categoryId,
      name: name,
      description: description,
      image: image,
      salePrice: salePrice,
      productionCost: productionCost,
      stock: stock,
      isActive: isActive,
    );
    await load();
  }

  // Actualiza el stock manualmente
  Future<void> updateStock(int id, int newStock) async {
    await repository.updateStock(id, newStock);
    await load();
  }
}

final productProvider =
    StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductNotifier(repository);
});