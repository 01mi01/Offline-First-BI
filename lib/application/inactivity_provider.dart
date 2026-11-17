import 'package:flutter_riverpod/flutter_riverpod.dart';

const Duration inactivityTimeout = Duration(minutes: 10);

final inactivityClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
