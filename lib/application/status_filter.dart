import 'package:flutter_riverpod/flutter_riverpod.dart';

// Filtro por estado de una lista: activos, inactivos o todos.
enum StatusFilter {
  all,
  active,
  inactive;

  bool matches(bool isActive) => switch (this) {
    StatusFilter.all => true,
    StatusFilter.active => isActive,
    StatusFilter.inactive => !isActive,
  };
}

// Estado del filtro de cada pantalla. Viven mientras la pantalla está abierta.
final materialStatusFilterProvider = StateProvider.autoDispose<StatusFilter>(
  (ref) => StatusFilter.all,
);
final eventStatusFilterProvider = StateProvider.autoDispose<StatusFilter>(
  (ref) => StatusFilter.all,
);
final locationStatusFilterProvider = StateProvider.autoDispose<StatusFilter>(
  (ref) => StatusFilter.all,
);

// Texto del buscador de la pestaña "Materiales".
final materialListQueryProvider = StateProvider.autoDispose<String>((ref) => '');
