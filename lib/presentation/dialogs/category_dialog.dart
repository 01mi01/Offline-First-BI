import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../application/image_storage_provider.dart';
import '../../data/services/image_storage.dart';
import '../../application/category_provider.dart';
import '../../models/category_model.dart';
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

class CategoryDialog extends ConsumerStatefulWidget {
  final CategoryModel? category;

  const CategoryDialog({super.key, this.category});

  @override
  ConsumerState<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<CategoryDialog>
    with SingleFlight<CategoryDialog>, LiveValidation<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  String? _imagePath;
  String? _pickedImagePath;
  late final ImageStorage _imageStorage;
  late bool _isActive;
  String? _saveError;
  late final String _initialSignature;

  @override
  void initState() {
    super.initState();
    _imageStorage = ref.read(imageStorageProvider);
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descController = TextEditingController(
      text: widget.category?.description ?? '',
    );
    _imagePath = widget.category?.image;
    _isActive = widget.category?.isActive ?? true;
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
    _descController.text,
    _imagePath ?? '',
    _isActive,
  ].join('\u0000');

  void _clearSaveError() {
    if (_saveError != null) setState(() => _saveError = null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _discardPickedImage();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final permanentPath = await _imageStorage.save(picked.path);
    if (!mounted) {
      await _imageStorage.deleteIfManaged(permanentPath);
      return;
    }
    _discardPickedImage();
    _pickedImagePath = permanentPath;
    setState(() => _imagePath = permanentPath);
  }

  void _discardPickedImage() {
    final path = _pickedImagePath;
    _pickedImagePath = null;
    if (path != null) _imageStorage.deleteIfManaged(path);
  }

  String? _validateName(String? value) {
    final error = validateName(value);
    if (error != null) return error;
    if (DefaultRecords.isCategory(value)) {
      return DefaultRecords.reservedNameMessage;
    }
    final others = ref
        .read(categoryProvider)
        .categories
        .where((c) => c.id != widget.category?.id)
        .map((c) => c.name);
    return validateUniqueName(
      value,
      others,
      message: 'Ya existe una categoría con ese nombre',
    );
  }

  Future<void> _save() async {
    if (!validateForm()) return;

    setState(() => _saveError = null);

    await ref
        .read(categoryProvider.notifier)
        .save(
          id: widget.category?.id,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          image: _imagePath,
          isActive: _isActive,
        );

    if (!mounted) return;

    final error = ref.read(categoryProvider).error;
    if (error != null) {
      setState(() {
        _saveError = error;
        _isActive = true;
      });
      acceptValues();
      return;
    }

    _pickedImagePath = null;
    final previous = widget.category?.image;
    if (previous != null && previous != _imagePath) {
      await _imageStorage.deleteIfManaged(previous);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _onToggleActive(bool value) async {
    final confirm = await confirmCancellation(
      context,
      title: value ? 'Activar la categoría' : 'Desactivar la categoría',
      message: value
          ? 'La categoría volverá a estar disponible para nuevos productos.'
          : 'La categoría no estará disponible para nuevos productos.',
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
        _descController,
      ]),
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final isEditing = widget.category != null;

    return FormSheet(
      title: isEditing ? 'Editar categoría' : 'Nueva categoría',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.pop(context),
        primaryLabel: isEditing ? 'Guardar' : 'Crear',
        onPrimary: () => runOnce(_save),
        busy: inFlight,
      ),
      children: [
        AppPhotoSlot(imagePath: _imagePath, onTap: _pickImage),
        const SizedBox(height: AppSpacing.s16),

        LabeledField(
          label: 'Nombre',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Nombre de la categoría'),
            validator: _validateName,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

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

        if (isEditing) ...[
          const SizedBox(height: AppSpacing.s16),
          AppToggleRow(
            title: 'Categoría activa',
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
