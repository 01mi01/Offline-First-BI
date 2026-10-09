import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_dashboard.dart';

final homePeriodProvider = StateProvider.autoDispose<HomePeriod>((ref) => HomePeriod.month);
