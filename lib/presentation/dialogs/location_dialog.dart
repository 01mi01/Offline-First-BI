import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/location_provider.dart';
import '../../models/location_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/app_buttons.dart';

class LocationDialog extends ConsumerStatefulWidget {
  final LocationModel? location;
  final Function(int locationId)? onSaved;

  const LocationDialog({super.key, this.location, this.onSaved});

  @override
  ConsumerState<LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends ConsumerState<LocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _descController;
  late bool _isActive;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _cityController =
        TextEditingController(text: widget.location?.city ?? '');
    _countryController =
        TextEditingController(text: widget.location?.country ?? '');
    _descController =
        TextEditingController(text: widget.location?.description ?? '');
    _isActive = widget.location?.isActive ?? true;
    _cityController.addListener(_clearSaveError);
    _countryController.addListener(_clearSaveError);
  }

  // Un error de guardado (p. ej. nombre repetido) deja de mostrarse en
  // cuanto se corrige el nombre.
  void _clearSaveError() {
    if (_saveError != null) setState(() => _saveError = null);
  }

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saveError = null);

    await ref.read(locationProvider.notifier).save(
          id: widget.location?.id,
          city: _cityController.text.trim(),
          country: _countryController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          isActive: _isActive,
        );

    if (!mounted) return;

    if (widget.onSaved != null) {
      final locations = ref.read(locationProvider).locations;
      final saved = locations
          .where((l) => l.city == _cityController.text.trim())
          .firstOrNull;
      if (saved != null) widget.onSaved!(saved.id);
    }
    Navigator.pop(context);
  }

  Future<void> _onToggleActive(bool value) async {
    if (!value) {
      final confirm = await confirmCancellation(
        context,
        title: '¿Desactivar ubicación?',
        message: 'La ubicación "${_cityController.text.trim()}" no estará disponible para nuevos registros.',
        confirmLabel: 'Desactivar',
        dismissLabel: 'Cancelar',
      );
      if (confirm != true) return;
    }
    setState(() => _isActive = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.location != null;

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
              Text(
                isEditing ? 'Editar ubicación' : 'Nueva ubicación',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Ciudad
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Ciudad',
                  hintText: 'Nombre de la ciudad',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: AppSpacing.s16),

              // País
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'País',
                  hintText: 'Nombre del país',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: AppSpacing.s16),

              // Descripción
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Descripción opcional',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.s20),

              // Toggle activo/inactivo solo en edición
              if (isEditing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ubicación activa',
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
                        activeColor: AppColors.cyanDark,
                        inactiveTrackColor: AppColors.border,
                        inactiveThumbColor: AppColors.surface,
                        trackOutlineColor:
                            WidgetStateProperty.all(Colors.transparent),
                      ),
                    ],
                  ),
                ),

              if (_saveError != null) ...[
                const SizedBox(height: AppSpacing.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_rounded,
                          color: AppColors.error, size: 16),
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
              ],

              const SizedBox(height: AppSpacing.s24),

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