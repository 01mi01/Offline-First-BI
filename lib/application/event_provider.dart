import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/access_control.dart';
import 'module_permission_provider.dart';
import '../data/repositories/event_repository.dart';
import '../models/event_model.dart';
import 'database_provider.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return EventRepository(db);
});

class EventState {
  final List<EventModel> events;
  final bool isLoading;
  final String? error;

  EventState({
    this.events = const [],
    this.isLoading = false,
    this.error,
  });

  EventState copyWith({
    List<EventModel>? events,
    bool? isLoading,
    String? error,
  }) {
    return EventState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EventNotifier extends StateNotifier<EventState> {
  final EventRepository repository;
  final AccessGuard guard;

  EventNotifier(this.repository, {this.guard = AccessGuard.none})
    : super(EventState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAll();
      state = state.copyWith(events: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> save({
    int? id,
    required String name,
    int? locationId,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
    bool isActive = true,
  }) async {
    final current = id == null
        ? null
        : state.events.where((e) => e.id == id).firstOrNull;
    guard.requireSave(
      AppModule.eventos,
      isNew: id == null,
      activeChanged: current != null && current.isActive != isActive,
    );
    await _persist(
      id: id,
      name: name,
      locationId: locationId,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      isActive: isActive,
    );
  }

  Future<String?> setActive(int id, bool isActive) async {
    final denied = guard.check(AppModule.eventos, ModuleAction.deactivate);
    if (denied != null) return denied;
    final e = state.events.where((e) => e.id == id).firstOrNull;
    if (e == null) return 'El evento no existe';
    await _persist(
      id: e.id,
      name: e.name,
      locationId: e.locationId,
      startDate: e.startDate,
      endDate: e.endDate,
      notes: e.notes,
      isActive: isActive,
    );
    return null;
  }

  Future<void> _persist({
    int? id,
    required String name,
    int? locationId,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
    required bool isActive,
  }) async {
    await repository.save(
      id: id,
      name: name,
      locationId: locationId,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      isActive: isActive,
    );
    await load();
  }
}

final eventProvider =
    StateNotifierProvider<EventNotifier, EventState>((ref) {
  final repository = ref.watch(eventRepositoryProvider);
  return EventNotifier(repository, guard: ref.watch(accessGuardProvider));
});