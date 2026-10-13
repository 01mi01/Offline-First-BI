import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/client_provider.dart';
import '../../models/client_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/confirm_cancel_dialog.dart';
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

class _ClientDialogState extends ConsumerState<ClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late bool _isActive;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client?.name ?? '');
    _contactController = TextEditingController(
      text: widget.client?.contactInfo ?? '',
    );
    _isActive = widget.client?.isActive ?? true;
    _nameController.addListener(_clearSaveError);
  }

  // Un error de guardado (p. ej. nombre repetido) deja de mostrarse en
  // cuanto se corrige el nombre.
  void _clearSaveError() {
    if (_saveError != null) setState(() => _saveError = null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  // Nombre obligatorio, distinto del reservado del sistema y sin repetirse con
  // otro registro (sin distinguir mayúsculas ni tildes).
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saveError = null);
    final error = await ref
        .read(clientProvider.notifier)
        .save(
          id: widget.client?.id,
          name: _nameController.text.trim(),
          contactInfo: _contactController.text.trim().isEmpty
              ? null
              : _contactController.text.trim(),
          isActive: _isActive,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() => _saveError = error);
      return;
    }
    if (widget.onSaved != null) {
      final clients = ref.read(clientProvider).clients;
      final saved = clients
          .where((c) => c.name == _nameController.text.trim())
          .firstOrNull;
      if (saved != null) widget.onSaved!(saved.id);
    }
    Navigator.pop(context);
  }

  Future<void> _onToggleActive(bool value) async {
    if (!value) {
      final confirm = await confirmCancellation(
        context,
        title: '¿Desactivar cliente?',
        message: 'El cliente no estará disponible para nuevas ventas.',
        confirmLabel: 'Desactivar',
        dismissLabel: 'Cancelar',
      );
      if (confirm != true) return;
    }
    setState(() => _isActive = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.client != null;

    return FormSheet(
      title: isEditing ? 'Editar cliente' : 'Nuevo cliente',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.pop(context),
        primaryLabel: isEditing ? 'Guardar' : 'Crear',
        onPrimary: _save,
      ),
      children: [
        // Nombre
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

        // Información de contacto
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

        // Estado: solo al editar
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

        // Error al guardar
        if (_saveError != null) FormErrorText(_saveError!),
      ],
    );
  }
}
