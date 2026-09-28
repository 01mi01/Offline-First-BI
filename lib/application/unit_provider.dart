import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/unit_repository.dart';
import '../models/unit_model.dart';
import 'database_provider.dart';

final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UnitRepository(db);
});

// Estado de unidades (datos de referencia, no editables desde la app)
class UnitState {
  final List<UnitModel> units;
  final bool isLoading;
  final String? error;

  UnitState({this.units = const [], this.isLoading = false, this.error});

  UnitState copyWith({List<UnitModel>? units, bool? isLoading, String? error}) {
    return UnitState(
      units: units ?? this.units,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UnitNotifier extends StateNotifier<UnitState> {
  final UnitRepository repository;

  UnitNotifier(this.repository) : super(UnitState()) {
    load();
  }

  // Carga todas las unidades
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAll();
      state = state.copyWith(units: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final unitProvider = StateNotifierProvider<UnitNotifier, UnitState>((ref) {
  final repository = ref.watch(unitRepositoryProvider);
  return UnitNotifier(repository);
});
