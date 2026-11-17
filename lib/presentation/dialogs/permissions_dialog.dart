import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../models/access_control.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/discard_guard.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';
import '../widgets/single_flight.dart';

const String permissionsNextLoginNotice =
    'Los cambios se aplican la próxima vez que el empleado inicie sesión.';

Key permissionSwitchKey(AppModule module, ModuleAction action) =>
    ValueKey('permission_${module.dbName}_${action.name}');

class PermissionsDialog extends ConsumerStatefulWidget {
  final UserModel user;

  const PermissionsDialog({super.key, required this.user});

  @override
  ConsumerState<PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends ConsumerState<PermissionsDialog>
    with SingleFlight<PermissionsDialog> {
  Map<AppModule, PermissionSet>? _initial;
  Map<AppModule, PermissionSet>? _current;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final permissions = await ref
        .read(employeePermissionsProvider)
        .load(widget.user.id);
    if (!mounted) return;
    setState(() {
      _initial = Map.of(permissions);
      _current = Map.of(permissions);
    });
  }

  bool _hasChanges() {
    final initial = _initial;
    final current = _current;
    if (initial == null || current == null) return false;
    return AppModule.configurable.any((m) => initial[m] != current[m]);
  }

  void _toggle(AppModule module, ModuleAction action, bool value) {
    setState(() {
      _error = null;
      _current![module] = _current![module]!.withAction(action, value);
    });
  }

  Future<void> _save() async {
    final current = _current;
    if (current == null) return;
    setState(() => _error = null);
    final error = await ref
        .read(employeePermissionsProvider)
        .save(
          userId: widget.user.id,
          role: widget.user.role,
          permissions: current,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _initial = Map.of(current);
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Permisos de ${widget.user.username} guardados'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return DiscardChangesGuard(
      hasChanges: _hasChanges,
      child: FormSheet(
        title: 'Permisos de ${widget.user.username}',
        actions: FormActions(
          onSecondary: () => Navigator.pop(context),
          primaryLabel: 'Guardar',
          onPrimary: current == null ? null : () => runOnce(_save),
          busy: inFlight,
        ),
        children: [
          const LockedFormNotice(permissionsNextLoginNotice),
          if (current == null)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.s24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final module in AppModule.configurable)
              AppSection(
                header: module.label,
                padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                children: [
                  for (final action in module.actions)
                    _PermissionSwitchRow(
                      key: permissionSwitchKey(module, action),
                      label: action.label,
                      value: current[module]!.allows(action),
                      onChanged: (value) => _toggle(module, action, value),
                    ),
                ],
              ),
          if (_error != null) FormErrorText(_error!),
        ],
      ),
    );
  }
}

class _PermissionSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppRow(
      title: label,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.cyanDark,
        inactiveTrackColor: AppColors.border,
        inactiveThumbColor: AppColors.switchThumbOff,
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
