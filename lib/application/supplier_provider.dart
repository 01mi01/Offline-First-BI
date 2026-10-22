import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/supplier_repository.dart';
import '../models/supplier_model.dart';
import 'database_provider.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SupplierRepository(db);
});

class SupplierState {
  final List<SupplierModel> suppliers;
  final bool isLoading;
  final String? error;

  SupplierState({
    this.suppliers = const [],
    this.isLoading = false,
    this.error,
  });

  SupplierState copyWith({
    List<SupplierModel>? suppliers,
    bool? isLoading,
    String? error,
  }) {
    return SupplierState(
      suppliers: suppliers ?? this.suppliers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SupplierNotifier extends StateNotifier<SupplierState> {
  final SupplierRepository repository;

  SupplierNotifier(this.repository) : super(SupplierState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAllIncludingInactive();
      state = state.copyWith(suppliers: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<({int? id, String? error})> saveWithId({
    int? id,
    required String name,
    String? contactInfo,
    bool isActive = true,
  }) async {
    try {
      final savedId = await repository.save(
        id: id,
        name: name,
        contactInfo: contactInfo,
        isActive: isActive,
      );
      await load();
      return (id: id ?? savedId, error: null);
    } catch (e) {
      return (id: null, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<String?> save({
    int? id,
    required String name,
    String? contactInfo,
    bool isActive = true,
  }) async => (await saveWithId(
    id: id,
    name: name,
    contactInfo: contactInfo,
    isActive: isActive,
  )).error;
}

final supplierProvider = StateNotifierProvider<SupplierNotifier, SupplierState>(
  (ref) {
    final repository = ref.watch(supplierRepositoryProvider);
    return SupplierNotifier(repository);
  },
);
