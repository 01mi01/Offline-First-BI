DateTime Function() _now = DateTime.now;

DateTime appNow() => _now();

void setAppClockForTesting([DateTime Function()? now]) {
  _now = now ?? DateTime.now;
}
