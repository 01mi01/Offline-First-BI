import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/sale_repository.dart';
import '../models/sale_model.dart';
import '../models/sale_item_model.dart';
import 'product_provider.dart';
import 'database_provider.dart';

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SaleRepository(db);
});

class SaleState {
  final List<SaleModel> sales;
  final bool isLoading;
  final String? error;

  SaleState({this.sales = const [], this.isLoading = false, this.error});

  SaleState copyWith({List<SaleModel>? sales, bool? isLoading, String? error}) {
    return SaleState(
      sales: sales ?? this.sales,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SaleNotifier extends StateNotifier<SaleState> {
  final SaleRepository repository;
  final Ref ref;

  SaleNotifier(this.repository, this.ref) : super(SaleState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAll();
      state = state.copyWith(sales: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<List<SaleItemModel>> getItemsForSale(int saleId) async {
    return await repository.getItemsForSale(saleId);
  }

  Future<String?> createSale({
    required int? clientId,
    required int? locationId,
    required int? eventId,
    required double totalAmount,
    required double discount,
    required double finalAmount,
    required DateTime date,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    if (discount < 0 || discount.isNaN) {
      return SaleRepository.negativeDiscountMessage;
    }
    try {
      await repository.createSale(
        clientId: clientId,
        locationId: locationId,
        eventId: eventId,
        totalAmount: totalAmount,
        discount: discount,
        finalAmount: finalAmount,
        date: date,
        notes: notes,
        items: items,
      );
      await load();
      ref.invalidate(productRepositoryProvider);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> editSale({
    required int saleId,
    required int? clientId,
    required int? locationId,
    required int? eventId,
    required double totalAmount,
    required double discount,
    required double finalAmount,
    required DateTime date,
    String? notes,
    required List<Map<String, dynamic>> newItems,
  }) async {
    try {
      final error = await repository.editSale(
        saleId: saleId,
        clientId: clientId,
        locationId: locationId,
        eventId: eventId,
        totalAmount: totalAmount,
        discount: discount,
        finalAmount: finalAmount,
        date: date,
        notes: notes,
        newItems: newItems,
      );
      await load();
      ref.invalidate(productRepositoryProvider);
      return error;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> cancelSale(int saleId) async {
    try {
      final error = await repository.cancelSale(saleId);
      await load();
      ref.invalidate(productRepositoryProvider);
      return error;
    } catch (e) {
      return e.toString();
    }
  }

  Future<Map<int, int>> getReservedQuantities(int saleId) async {
    return await repository.getReservedQuantities(saleId);
  }
}

final saleProvider = StateNotifierProvider<SaleNotifier, SaleState>((ref) {
  final repository = ref.watch(saleRepositoryProvider);
  return SaleNotifier(repository, ref);
});
