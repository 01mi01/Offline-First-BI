import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/location_repository.dart';
import '../models/location_model.dart';
import 'database_provider.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LocationRepository(db);
});

// Estado de ubicaciones
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

  LocationNotifier(this.repository) : super(LocationState()) {
    load();
  }

  // Carga todas las ubicaciones
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAllIncludingInactive();
      state = state.copyWith(locations: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Guarda o edita una ubicación
  Future<void> save({
    int? id,
    required String city,
    required String country,
    String? description,
    bool isActive = true,
  }) async {
    await repository.save(
      id: id,
      city: city,
      country: country,
      description: description,
      isActive: isActive,
    );
    await load();
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final repository = ref.watch(locationRepositoryProvider);
  return LocationNotifier(repository);
});