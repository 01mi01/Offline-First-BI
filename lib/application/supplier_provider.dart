import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/access_control.dart';
import 'module_permission_provider.dart';
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
  final AccessGuard guard;

  SupplierNotifier(this.repository, {this.guard = AccessGuard.none})
    : super(SupplierState()) {
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
    AppModule? from,
  }) async {
    final current = id == null
        ? null
        : state.suppliers.where((r) => r.id == id).firstOrNull;
    final denied = guard.checkSave(
      AppModule.proveedores,
      isNew: id == null,
      activeChanged: current != null && current.isActive != isActive,
      from: from,
    );
    if (denied != null) return (id: null, error: denied);
    return _persist(
      id: id,
      name: name,
      contactInfo: contactInfo,
      isActive: isActive,
    );
  }

  Future<String?> setActive(int id, bool isActive) async {
    final denied = guard.check(AppModule.proveedores, ModuleAction.deactivate);
    if (denied != null) return denied;
    final r = state.suppliers.where((r) => r.id == id).firstOrNull;
    if (r == null) return 'El registro no existe';
    return (await _persist(
      id: r.id,
      name: r.name,
      contactInfo: r.contactInfo,
      isActive: isActive,
    )).error;
  }

  Future<({int? id, String? error})> _persist({
    int? id,
    required String name,
    String? contactInfo,
    required bool isActive,
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
    AppModule? from,
  }) async => (await saveWithId(
    id: id,
    name: name,
    contactInfo: contactInfo,
    isActive: isActive,
    from: from,
  )).error;
}

final supplierProvider = StateNotifierProvider<SupplierNotifier, SupplierState>(
  (ref) {
    final repository = ref.watch(supplierRepositoryProvider);
    return SupplierNotifier(repository, guard: ref.watch(accessGuardProvider));
  },
);
