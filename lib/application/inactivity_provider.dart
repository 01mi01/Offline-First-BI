import 'package:flutter_riverpod/flutter_riverpod.dart';

// Testing value: 1 minute. Production value is 10 minutes. The inactivity test result is judged with this value.
const Duration inactivityTimeout = Duration(minutes: 1);

final inactivityClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
