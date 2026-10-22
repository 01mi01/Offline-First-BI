import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/client_provider.dart';
import '../../models/client_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/discard_guard.dart';
import '../widgets/live_validation.dart';
import '../widgets/single_flight.dart';
import '../../application/form_validation.dart';
import '../../models/default_records.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';

class ClientDialog extends ConsumerStatefulWidget {
  final ClientModel? client;
  final Function(int clientId)? onSaved;

  const ClientDialog({super.key, this.client, this.onSaved});

  @override
  ConsumerState<ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends ConsumerState<ClientDialog>
    with SingleFlight<ClientDialog>, LiveValidation<ClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late bool _isActive;
  String? _saveError;
  late final String _initialSignature;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client?.name ?? '');
    _contactController = TextEditingController(
      text: widget.client?.contactInfo ?? '',
    );
    _isActive = widget.client?.isActive ?? true;
    _nameController.addListener(_clearSaveError);
    _initialSignature = _signature();
  }

  @override
  GlobalKey<FormState> get validationKey => _formKey;

  @override
  String valuesSnapshot() => _signature();

  @override
  void clearMessages() {_saveError = null;}

  String _signature() => [
    _nameController.text,
    _contactController.text,
    _isActive,
  ].join('\u0000');

  void _clearSaveError() {
    if (_saveError != null) setState(() => _saveError = null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final error = validateName(value);
    if (error != null) return error;
    if (DefaultRecords.isClient(value)) {
      return DefaultRecords.reservedNameMessage;
    }
    final others = ref
        .read(clientProvider)
        .clients
        .where((r) => r.id != widget.client?.id)
        .map((r) => r.name);
    return validateUniqueName(value, others, message: 'Ya existe un cliente con ese nombre');
  }

  Future<void> _save() async {
    if (!validateForm()) return;
    setState(() => _saveError = null);
    final result = await ref
        .read(clientProvider.notifier)
        .saveWithId(
          id: widget.client?.id,
          name: _nameController.text.trim(),
          contactInfo: _contactController.text.trim().isEmpty
              ? null
              : _contactController.text.trim(),
          isActive: _isActive,
        );
    if (!mounted) return;
    final error = result.error;
    if (error != null) {
      setState(() => _saveError = error);
      return;
    }
    if (result.id != null) widget.onSaved?.call(result.id!);
    Navigator.pop(context);
  }

  Future<void> _onToggleActive(bool value) async {
    final confirm = await confirmCancellation(
      context,
      title: value ? 'Activar el cliente' : 'Desactivar el cliente',
      message: value
          ? 'El cliente volverá a estar disponible para nuevas ventas.'
          : 'El cliente no estará disponible para nuevas ventas.',
      confirmLabel: value ? 'Activar' : 'Desactivar',
      confirmKind: value ? AppButtonKind.primary : AppButtonKind.destructive,
    );
    if (!confirm) return;
    setState(() => _isActive = value);
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _signature() != _initialSignature,
      onValuesChanged: syncValues,
      changes: Listenable.merge([
        _nameController,
        _contactController,
      ]),
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final isEditing = widget.client != null;

    return FormSheet(
      title: isEditing ? 'Editar cliente' : 'Nuevo cliente',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.pop(context),
        primaryLabel: isEditing ? 'Guardar' : 'Crear',
        onPrimary: () => runOnce(_save),
        busy: inFlight,
      ),
      children: [
        LabeledField(
          label: 'Nombre',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Nombre del cliente'),
            validator: _validateName,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        LabeledField(
          label: 'Información de contacto',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _contactController,
            decoration: const InputDecoration(
              hintText: 'Dirección, redes sociales, teléfono, etc.',
            ),
            maxLines: 3,
            validator: validateOptionalText,
          ),
        ),

        if (isEditing) ...[
          const SizedBox(height: AppSpacing.s16),
          AppToggleRow(
            title: 'Cliente activo',
            subtitle: _isActive
                ? 'Disponible en el sistema'
                : 'No disponible en el sistema',
            value: _isActive,
            onChanged: _onToggleActive,
          ),
        ],

        if (_saveError != null) FormErrorText(_saveError!),
      ],
    );
  }
}
