import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/access_control.dart';
import 'module_permission_provider.dart';
import '../data/repositories/client_repository.dart';
import '../models/client_model.dart';
import 'database_provider.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ClientRepository(db);
});

class ClientState {
  final List<ClientModel> clients;
  final bool isLoading;
  final String? error;

  ClientState({this.clients = const [], this.isLoading = false, this.error});

  ClientState copyWith({
    List<ClientModel>? clients,
    bool? isLoading,
    String? error,
  }) {
    return ClientState(
      clients: clients ?? this.clients,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ClientNotifier extends StateNotifier<ClientState> {
  final ClientRepository repository;
  final AccessGuard guard;

  ClientNotifier(this.repository, {this.guard = AccessGuard.none})
    : super(ClientState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAllIncludingInactive();
      state = state.copyWith(clients: data, isLoading: false);
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
        : state.clients.where((r) => r.id == id).firstOrNull;
    final denied = guard.checkSave(
      AppModule.clientes,
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
    final denied = guard.check(AppModule.clientes, ModuleAction.deactivate);
    if (denied != null) return denied;
    final r = state.clients.where((r) => r.id == id).firstOrNull;
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

final clientProvider = StateNotifierProvider<ClientNotifier, ClientState>((
  ref,
) {
  final repository = ref.watch(clientRepositoryProvider);
  return ClientNotifier(repository, guard: ref.watch(accessGuardProvider));
});
