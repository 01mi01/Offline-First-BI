import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/supplier_provider.dart';
import '../../models/supplier_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../../application/form_validation.dart';
import '../../models/default_records.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';

class SupplierDialog extends ConsumerStatefulWidget {
  final SupplierModel? supplier;
  final Function(int supplierId)? onSaved;

  const SupplierDialog({super.key, this.supplier, this.onSaved});

  @override
  ConsumerState<SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends ConsumerState<SupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late bool _isActive;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _contactController = TextEditingController(
      text: widget.supplier?.contactInfo ?? '',
    );
    _isActive = widget.supplier?.isActive ?? true;
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
    if (DefaultRecords.isSupplier(value)) {
      return DefaultRecords.reservedNameMessage;
    }
    final others = ref
        .read(supplierProvider)
        .suppliers
        .where((r) => r.id != widget.supplier?.id)
        .map((r) => r.name);
    return validateUniqueName(value, others, message: 'Ya existe un proveedor con ese nombre');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saveError = null);
    final error = await ref
        .read(supplierProvider.notifier)
        .save(
          id: widget.supplier?.id,
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
      final suppliers = ref.read(supplierProvider).suppliers;
      final saved = suppliers
          .where((s) => s.name == _nameController.text.trim())
          .firstOrNull;
      if (saved != null) widget.onSaved!(saved.id);
    }
    Navigator.pop(context);
  }

  Future<void> _onToggleActive(bool value) async {
    if (!value) {
      final confirm = await confirmCancellation(
        context,
        title: '¿Desactivar proveedor?',
        message: 'El proveedor "${_nameController.text.trim()}" no estará disponible para nuevas compras.',
        confirmLabel: 'Desactivar',
        dismissLabel: 'Cancelar',
      );
      if (confirm != true) return;
    }
    setState(() => _isActive = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplier != null;

    return FormSheet(
      title: isEditing ? 'Editar proveedor' : 'Nuevo proveedor',
      formKey: _formKey,
      children: [
        // Nombre
        LabeledField(
          label: 'Nombre',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Nombre del proveedor'),
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
          const SizedBox(height: AppSpacing.s20),
          AppToggleRow(
            title: 'Proveedor activo',
            subtitle: _isActive
                ? 'Disponible en el sistema'
                : 'No disponible en el sistema',
            value: _isActive,
            onChanged: _onToggleActive,
          ),
        ],

        // Error al guardar
        if (_saveError != null) FormErrorText(_saveError!),
        const SizedBox(height: AppSpacing.s24),

        FormActions(
          onSecondary: () => Navigator.pop(context),
          primaryLabel: isEditing ? 'Guardar' : 'Crear',
          onPrimary: _save,
        ),
      ],
    );
  }
}
