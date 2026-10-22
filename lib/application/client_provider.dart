import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  ClientNotifier(this.repository) : super(ClientState()) {
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

final clientProvider = StateNotifierProvider<ClientNotifier, ClientState>((
  ref,
) {
  final repository = ref.watch(clientRepositoryProvider);
  return ClientNotifier(repository);
});
