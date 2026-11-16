import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../application/inactivity_provider.dart';
import '../pages/login_page.dart';

class InactivityWatcher extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const InactivityWatcher({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  @override
  ConsumerState<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends ConsumerState<InactivityWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _lastActivity;
  bool _closing = false;

  bool get _signedIn => ref.read(authProvider).user != null;

  DateTime _now() => ref.read(inactivityClockProvider)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<int?>(
      authProvider.select((s) => s.user?.id),
      (previous, next) {
        if (next == null) {
          _stop();
        } else if (previous != next) {
          _registerActivity();
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkElapsed();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _lastActivity = null;
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _expire);
  }

  void _registerActivity() {
    if (!_signedIn || _closing) return;
    _lastActivity = _now();
    _schedule(inactivityTimeout);
  }

  void _checkElapsed() {
    final last = _lastActivity;
    if (!_signedIn || last == null || _closing) return;
    final elapsed = _now().difference(last);
    if (elapsed >= inactivityTimeout) {
      _expire();
    } else {
      _schedule(inactivityTimeout - elapsed);
    }
  }

  Future<void> _expire() async {
    if (_closing || !_signedIn) return;
    _closing = true;
    _stop();
    try {
      await ref.read(authProvider.notifier).logoutForInactivity();
      widget.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } finally {
      _closing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _registerActivity(),
      onPointerMove: (_) => _registerActivity(),
      onPointerUp: (_) => _registerActivity(),
      onPointerSignal: (_) => _registerActivity(),
      child: widget.child,
    );
  }
}
