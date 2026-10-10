import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/client_provider.dart';
import '../../models/client_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/app_buttons.dart';

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
        message: 'El cliente "${_nameController.text.trim()}" no estará disponible para nuevas ventas.',
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

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        top: AppSpacing.s24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s32,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Text(
                isEditing ? 'Editar cliente' : 'Nuevo cliente',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Nombre
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Nombre del cliente',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: AppSpacing.s16),

              // Información de contacto
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Información de contacto',
                  hintText: 'Dirección, redes sociales, teléfono, etc.',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.s20),

              // Toggle activo/inactivo solo en edición
              if (isEditing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cliente activo',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _isActive
                                ? 'Disponible en el sistema'
                                : 'No disponible en el sistema',
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isActive,
                        onChanged: _onToggleActive,
                        activeColor: AppColors.primaryDark,
                        inactiveTrackColor: AppColors.border,
                        inactiveThumbColor: AppColors.surface,
                        trackOutlineColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.s24),
              // Error al guardar
              if (_saveError != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_rounded,
                        color: AppColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
              ],

              const SizedBox(height: AppSpacing.s24),

              // Botones cancelar y guardar
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'Guardar' : 'Crear'),
                  ),
                  const SizedBox(height: AppButtons.stackGap),
                  AppActionButton(
                    label: 'Cancelar',
                    kind: AppButtonKind.neutral,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
