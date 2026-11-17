import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/access_control.dart';
import 'module_permission_provider.dart';
import '../data/repositories/location_repository.dart';
import '../models/location_model.dart';
import 'database_provider.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LocationRepository(db);
});

class LocationState {
  final List<LocationModel> locations;
  final bool isLoading;
  final String? error;

  LocationState({
    this.locations = const [],
    this.isLoading = false,
    this.error,
  });

  LocationState copyWith({
    List<LocationModel>? locations,
    bool? isLoading,
    String? error,
  }) {
    return LocationState(
      locations: locations ?? this.locations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  final LocationRepository repository;
  final AccessGuard guard;

  LocationNotifier(this.repository, {this.guard = AccessGuard.none})
    : super(LocationState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAllIncludingInactive();
      state = state.copyWith(locations: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<int> save({
    int? id,
    required String city,
    required String country,
    String? description,
    bool isActive = true,
    AppModule? from,
  }) async {
    final current = id == null
        ? null
        : state.locations.where((l) => l.id == id).firstOrNull;
    guard.requireSave(
      AppModule.ubicaciones,
      isNew: id == null,
      activeChanged: current != null && current.isActive != isActive,
      from: from,
    );
    return _persist(
      id: id,
      city: city,
      country: country,
      description: description,
      isActive: isActive,
    );
  }

  Future<String?> setActive(int id, bool isActive) async {
    final denied = guard.check(AppModule.ubicaciones, ModuleAction.deactivate);
    if (denied != null) return denied;
    final l = state.locations.where((l) => l.id == id).firstOrNull;
    if (l == null) return 'La ubicación no existe';
    await _persist(
      id: l.id,
      city: l.city,
      country: l.country,
      description: l.description,
      isActive: isActive,
    );
    return null;
  }

  Future<int> _persist({
    int? id,
    required String city,
    required String country,
    String? description,
    required bool isActive,
  }) async {
    final savedId = await repository.save(
      id: id,
      city: city,
      country: country,
      description: description,
      isActive: isActive,
    );
    await load();
    return savedId;
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final repository = ref.watch(locationRepositoryProvider);
  return LocationNotifier(repository, guard: ref.watch(accessGuardProvider));
});