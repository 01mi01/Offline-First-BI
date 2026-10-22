import 'package:flutter/widgets.dart';

mixin LiveValidation<T extends StatefulWidget> on State<T> {
  bool _attempted = false;
  bool _validated = false;
  String? _seen;

  bool get submitAttempted => _attempted;

  GlobalKey<FormState> get validationKey;

  String valuesSnapshot();

  void clearMessages();

  void markAttempted() {
    if (!_attempted) setState(() => _attempted = true);
  }

  bool validateForm() {
    markAttempted();
    _validated = true;
    return validationKey.currentState?.validate() ?? true;
  }

  void acceptValues() {
    _seen = valuesSnapshot();
  }

  void syncValues() {
    if (!mounted) return;
    final now = valuesSnapshot();
    final previous = _seen;
    _seen = now;
    if (previous == null || previous == now) return;
    setState(clearMessages);
    if (_validated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) validationKey.currentState?.validate();
      });
    }
  }
}
