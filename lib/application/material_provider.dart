import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/material_repository.dart';
import '../models/material_model.dart';
import '../models/product_material_model.dart';
import 'database_provider.dart';
import 'purchase_provider.dart';

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return MaterialRepository(db);
});

class MaterialState {
  final List<MaterialModel> materials;
  final bool isLoading;
  final String? error;

  MaterialState({
    this.materials = const [],
    this.isLoading = false,
    this.error,
  });

  MaterialState copyWith({
    List<MaterialModel>? materials,
    bool? isLoading,
    String? error,
  }) {
    return MaterialState(
      materials: materials ?? this.materials,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MaterialNotifier extends StateNotifier<MaterialState> {
  final MaterialRepository repository;
  final Ref ref;

  MaterialNotifier(this.repository, this.ref) : super(MaterialState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAllIncludingInactive();
      state = state.copyWith(materials: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<int> save({
    int? id,
    required String name,
    String? description,
    required int unitId,
    required double stock,
    required double pricePerUnit,
    bool isActive = true,
  }) async {
    final savedId = await repository.save(
      id: id,
      name: name,
      description: description,
      unitId: unitId,
      stock: stock,
      pricePerUnit: pricePerUnit,
      isActive: isActive,
    );
    await load();
    if (id == null && stock > 0) {
      await ref.read(purchaseProvider.notifier).load();
    }
    return savedId;
  }

  Future<List<ProductMaterialModel>> getMaterialsForProduct(
    int productId,
  ) async {
    return await repository.getMaterialsForProduct(productId);
  }

  Future<List<Map<String, dynamic>>> getMaterialsWithPriceForProduct(
    int productId,
  ) async {
    return await repository.getMaterialsWithPriceForProduct(productId);
  }

  Future<String?> registerUsage({
    required int productId,
    required int materialId,
    required double quantityUsed,
  }) async {
    final error = await repository.registerMaterialUsage(
      productId: productId,
      materialId: materialId,
      quantityUsed: quantityUsed,
    );
    await load();
    return error;
  }

  Future<String?> editUsage({
    required int recordId,
    required double newQuantity,
  }) async {
    final error = await repository.editMaterialUsage(
      recordId: recordId,
      newQuantity: newQuantity,
    );
    await load();
    return error;
  }

  Future<String?> cancelUsage(int recordId) async {
    final error = await repository.cancelMaterialUsage(recordId);
    await load();
    return error;
  }
}

final materialProvider = StateNotifierProvider<MaterialNotifier, MaterialState>(
  (ref) {
    final repository = ref.watch(materialRepositoryProvider);
    return MaterialNotifier(repository, ref);
  },
);
