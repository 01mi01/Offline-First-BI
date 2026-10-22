import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final materialStatusFilterProvider = StateProvider.autoDispose<StatusFilter>(
  (ref) => StatusFilter.all,
);
final eventStatusFilterProvider = StateProvider.autoDispose<StatusFilter>(
  (ref) => StatusFilter.all,
);
final locationStatusFilterProvider = StateProvider.autoDispose<StatusFilter>(
  (ref) => StatusFilter.all,
);

final clientStatusFilterProvider = StateProvider.autoDispose<StatusFilter>(
  (ref) => StatusFilter.all,
);
final supplierStatusFilterProvider = StateProvider.autoDispose<StatusFilter>(
  (ref) => StatusFilter.all,
);

final locationCountryFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final locationCityFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final eventCountryFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final eventCityFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final clientListQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final supplierListQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final eventListQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final locationListQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final materialListQueryProvider = StateProvider.autoDispose<String>((ref) => '');
