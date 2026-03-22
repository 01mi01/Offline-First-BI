import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/event_repository.dart';
import '../models/event_model.dart';
import 'database_provider.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return EventRepository(db);
});

// Estado de eventos
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

  EventNotifier(this.repository) : super(EventState()) {
    load();
  }

  // Carga todos los eventos
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.getAll();
      state = state.copyWith(events: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Guarda o edita un evento
  Future<void> save({
    int? id,
    required String name,
    int? locationId,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
  }) async {
    await repository.save(
      id: id,
      name: name,
      locationId: locationId,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
    );
    await load();
  }
}

final eventProvider =
    StateNotifierProvider<EventNotifier, EventState>((ref) {
  final repository = ref.watch(eventRepositoryProvider);
  return EventNotifier(repository);
});