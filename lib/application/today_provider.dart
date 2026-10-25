import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_clock.dart';
import 'date_range_filter.dart';

class TodayNotifier extends StateNotifier<DateTime> {
  TodayNotifier() : super(dateOnly(appNow()));

  void refresh() {
    final today = dateOnly(appNow());
    if (today != state) state = today;
  }
}

final todayProvider = StateNotifierProvider<TodayNotifier, DateTime>(
  (ref) => TodayNotifier(),
);
