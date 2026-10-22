import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'confirm_cancel_dialog.dart';
import 'form_sheet_route.dart';

class DiscardChangesGuard extends StatefulWidget {
  final bool Function() hasChanges;
  final Listenable? changes;
  final VoidCallback? onValuesChanged;
  final Widget child;

  const DiscardChangesGuard({
    super.key,
    required this.hasChanges,
    this.changes,
    this.onValuesChanged,
    required this.child,
  });

  @override
  State<DiscardChangesGuard> createState() => _DiscardChangesGuardState();
}

class _DiscardChangesGuardState extends State<DiscardChangesGuard> {
  FormSheetScope? _scope;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    widget.changes?.addListener(_schedule);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = FormSheetScope.maybeOf(context);
  }

  @override
  void didUpdateWidget(DiscardChangesGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) {
      oldWidget.changes?.removeListener(_schedule);
      widget.changes?.addListener(_schedule);
    }
  }

  @override
  void dispose() {
    widget.changes?.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle) {
      _apply();
    } else if (!_pending) {
      _pending = true;
      binding.addPostFrameCallback((_) {
        _pending = false;
        _apply();
      });
    }
  }

  void _apply() {
    if (!mounted) return;
    widget.onValuesChanged?.call();
    final dirty = _scope?.dirty;
    if (dirty == null) return;
    final value = widget.hasChanges();
    if (dirty.value != value) dirty.value = value;
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final close = !widget.hasChanges() || await confirmDiscardChanges(context);
        if (close && context.mounted) Navigator.pop(context);
      },
      child: widget.child,
    );
  }
}
