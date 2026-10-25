import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/bi_provider.dart';
import '../../application/date_range_filter.dart';
import '../../application/today_provider.dart';
import '../../config/app_clock.dart';

void refreshPresetFilters(WidgetRef ref, DateTime today) {
  void refreshRange(AutoDisposeStateProvider<DateRangeFilter> provider) {
    if (!ref.exists(provider)) return;
    final current = ref.read(provider);
    final preset = current.preset;
    if (preset == null) return;
    final next = DateRangeFilter.forPreset(preset, now: today);
    if (next != current) ref.read(provider.notifier).state = next;
  }

  refreshRange(saleDateFilterProvider);
  refreshRange(purchaseDateFilterProvider);
  refreshRange(eventDateFilterProvider);

  if (ref.exists(biConfigProvider)) {
    final config = ref.read(biConfigProvider);
    final filters = config.filters.refreshedFor(today);
    if (filters != config.filters) {
      ref.read(biConfigProvider.notifier).state = config.copyWith(
        filters: filters,
      );
    }
  }
}

class DayChangeWatcher extends ConsumerStatefulWidget {
  final Widget child;

  const DayChangeWatcher({super.key, required this.child});

  @override
  ConsumerState<DayChangeWatcher> createState() => _DayChangeWatcherState();
}

class _DayChangeWatcherState extends ConsumerState<DayChangeWatcher>
    with WidgetsBindingObserver {
  static const Duration _margin = Duration(seconds: 1);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  void _tick() {
    ref.read(todayProvider.notifier).refresh();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = appNow();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(nextMidnight.difference(now) + _margin, _tick);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime>(todayProvider, (previous, next) {
      refreshPresetFilters(ref, next);
    });
    return widget.child;
  }
}
