import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/purchase_repository.dart';
import '../models/purchase_model.dart';
import '../models/purchase_item_model.dart';
import 'database_provider.dart';
import 'material_provider.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PurchaseRepository(db);
});

// Estado de compras
class PurchaseState {
  final List<PurchaseModel> purchases;
  final bool isLoading;
  final String? error;

  PurchaseState({
    this.purchases = const [],
    this.isLoading = false,
    this.error,
  });

  PurchaseState copyWith({
    List<PurchaseModel>? purchases,
    bool? isLoading,
    String? error,
  }) {
    return PurchaseState(
      purchases: purchases ?? this.purchases,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PurchaseNotifier extends StateNotifier<PurchaseState> {
  final PurchaseRepository repository;
  final Ref ref;

  PurchaseNotifier(this.repository, this.ref) : super(PurchaseState()) {
    load();
  }

  // Carga todas las compras
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAll();
      state = state.copyWith(purchases: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Obtiene ítems de una compra
  Future<List<PurchaseItemModel>> getItemsForPurchase(int purchaseId) async {
    return await repository.getItemsForPurchase(purchaseId);
  }

  // Crea una nueva compra
  Future<String?> createPurchase({
    required int? supplierId,
    required int? locationId,
    required int? eventId,
    required bool isMaterial,
    required String? description,
    required double totalAmount,
    required DateTime date,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await repository.createPurchase(
        supplierId: supplierId,
        locationId: locationId,
        eventId: eventId,
        isMaterial: isMaterial,
        description: description,
        totalAmount: totalAmount,
        date: date,
        notes: notes,
        items: items,
      );
      await load();
      ref.invalidate(materialRepositoryProvider);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Edita una compra existente
  Future<String?> editPurchase({
    required int purchaseId,
    required int? supplierId,
    required int? locationId,
    required int? eventId,
    required bool isMaterial,
    required String? description,
    required double totalAmount,
    required DateTime date,
    String? notes,
    required List<Map<String, dynamic>> newItems,
  }) async {
    try {
      await repository.editPurchase(
        purchaseId: purchaseId,
        supplierId: supplierId,
        locationId: locationId,
        eventId: eventId,
        isMaterial: isMaterial,
        description: description,
        totalAmount: totalAmount,
        date: date,
        notes: notes,
        newItems: newItems,
      );
      await load();
      ref.invalidate(materialRepositoryProvider);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final purchaseProvider =
    StateNotifierProvider<PurchaseNotifier, PurchaseState>((ref) {
  final repository = ref.watch(purchaseRepositoryProvider);
  return PurchaseNotifier(repository, ref);
});