import 'dart:async';
import 'dart:io';

import 'package:offline_first_bi/config/app_clock.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final fake = Platform.environment['FAKE_NOW'];
  if (fake != null && fake.isNotEmpty) {
    final fixed = DateTime.parse(fake);
    setAppClockForTesting(() => fixed);
  }
  await testMain();
}
