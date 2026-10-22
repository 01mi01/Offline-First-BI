import 'package:flutter/widgets.dart';

mixin SingleFlight<T extends StatefulWidget> on State<T> {
  bool _inFlight = false;

  bool get inFlight => _inFlight;

  Future<void> runOnce(Future<void> Function() action) async {
    if (_inFlight) return;
    setState(() => _inFlight = true);
    try {
      await action();
    } finally {
      if (mounted && (ModalRoute.of(context)?.isActive ?? true)) {
        setState(() => _inFlight = false);
      }
    }
  }
}
