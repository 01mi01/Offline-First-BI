import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/access_control.dart';
import 'module_permission_provider.dart';
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

  AccessGuard get _guard => ref.read(accessGuardProvider);

  Future<int> save({
    int? id,
    required String name,
    String? description,
    required int unitId,
    required double stock,
    required double pricePerUnit,
    bool isActive = true,
    AppModule? from,
  }) async {
    final previous = id == null
        ? null
        : state.materials.where((m) => m.id == id).firstOrNull;
    _guard.requireSave(
      AppModule.materiales,
      isNew: id == null,
      activeChanged: previous != null && previous.isActive != isActive,
      from: from,
    );
    return _persist(
      id: id,
      previous: previous,
      name: name,
      description: description,
      unitId: unitId,
      stock: stock,
      pricePerUnit: pricePerUnit,
      isActive: isActive,
    );
  }

  Future<String?> setActive(int id, bool isActive) async {
    final denied = _guard.check(AppModule.materiales, ModuleAction.deactivate);
    if (denied != null) return denied;
    final m = state.materials.where((m) => m.id == id).firstOrNull;
    if (m == null) return 'El material no existe';
    await _persist(
      id: m.id,
      previous: m,
      name: m.name,
      description: m.description,
      unitId: m.unitId,
      stock: m.stock,
      pricePerUnit: m.pricePerUnit,
      isActive: isActive,
    );
    return null;
  }

  Future<int> _persist({
    int? id,
    MaterialModel? previous,
    required String name,
    String? description,
    required int unitId,
    required double stock,
    required double pricePerUnit,
    required bool isActive,
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
    final raised = id == null ? stock > 0 : stock > (previous?.stock ?? stock);
    if (raised) {
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
    final denied = _guard.check(AppModule.materiales, ModuleAction.create);
    if (denied != null) return denied;
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
    final denied = _guard.check(AppModule.materiales, ModuleAction.update);
    if (denied != null) return denied;
    final error = await repository.editMaterialUsage(
      recordId: recordId,
      newQuantity: newQuantity,
    );
    await load();
    return error;
  }

  Future<String?> cancelUsage(int recordId) async {
    final denied = _guard.check(AppModule.materiales, ModuleAction.deactivate);
    if (denied != null) return denied;
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
