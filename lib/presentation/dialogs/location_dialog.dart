import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/location_provider.dart';
import '../../models/location_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../../application/form_validation.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';

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
    _descController.addListener(_clearSaveError);
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

  // Una ciudad puede repetirse (hay varias zonas en la misma ciudad), pero no la
  // misma ciudad, país y descripción juntos.
  bool _isDuplicate() {
    final city = comparableName(_cityController.text);
    final country = comparableName(_countryController.text);
    final zone = comparableName(_descController.text);
    return ref
        .read(locationProvider)
        .locations
        .where((l) => l.id != widget.location?.id)
        .any(
          (l) =>
              comparableName(l.city) == city &&
              comparableName(l.country) == country &&
              comparableName(l.description ?? '') == zone,
        );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isDuplicate()) {
      setState(
        () => _saveError =
            'Ya existe una ubicación con esa ciudad, país y descripción',
      );
      return;
    }
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
    final confirm = await confirmCancellation(
      context,
      title: value ? 'Activar la ubicación' : 'Desactivar la ubicación',
      message: value
          ? 'La ubicación volverá a estar disponible para nuevos registros.'
          : 'La ubicación no estará disponible para nuevos registros.',
      confirmLabel: value ? 'Activar' : 'Desactivar',
      confirmKind: value ? AppButtonKind.primary : AppButtonKind.destructive,
      dismissLabel: 'Cancelar',
    );
    if (!confirm) return;
    setState(() => _isActive = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.location != null;

    return FormSheet(
      title: isEditing ? 'Editar ubicación' : 'Nueva ubicación',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.pop(context),
        primaryLabel: isEditing ? 'Guardar' : 'Crear',
        onPrimary: _save,
      ),
      children: [
        // Ciudad
        LabeledField(
          label: 'Ciudad',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _cityController,
            decoration: const InputDecoration(hintText: 'Nombre de la ciudad'),
            validator: validateName,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // País
        LabeledField(
          label: 'País',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _countryController,
            decoration: const InputDecoration(hintText: 'Nombre del país'),
            validator: validateName,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Descripción (la zona)
        LabeledField(
          label: 'Descripción',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _descController,
            decoration: const InputDecoration(hintText: 'Descripción opcional'),
            maxLines: 2,
            validator: validateOptionalText,
          ),
        ),

        // Estado: solo al editar
        if (isEditing) ...[
          const SizedBox(height: AppSpacing.s16),
          AppToggleRow(
            title: 'Ubicación activa',
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
