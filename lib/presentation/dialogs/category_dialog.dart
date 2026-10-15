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

class _CategoryDialogState extends ConsumerState<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  String? _imagePath;
  // Copia permanente de la imagen elegida en esta sesión (aún sin guardar).
  String? _pickedImagePath;
  // Se guarda al iniciar: `ref` ya no se puede usar dentro de dispose().
  late final ImageStorage _imageStorage;
  late bool _isActive;
  String? _saveError;

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
  }

  // Un error de guardado (p. ej. nombre repetido) deja de mostrarse en
  // cuanto se corrige el nombre.
  void _clearSaveError() {
    if (_saveError != null) setState(() => _saveError = null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    // Si se cierra sin guardar, la copia elegida no se usa.
    _discardPickedImage();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    // La foto elegida vive en la caché, que Android puede vaciar: se copia a
    // la carpeta permanente y se guarda esa ruta.
    final permanentPath = await _imageStorage.save(picked.path);
    if (!mounted) {
      await _imageStorage.deleteIfManaged(permanentPath);
      return;
    }
    // Una imagen elegida antes en esta misma sesión y reemplazada ya no se usa.
    _discardPickedImage();
    _pickedImagePath = permanentPath;
    setState(() => _imagePath = permanentPath);
  }

  // Borra la imagen elegida en esta sesión (si la hay) para no dejar copias
  // huérfanas. La imagen que ya tenía el registro nunca se borra aquí.
  void _discardPickedImage() {
    final path = _pickedImagePath;
    _pickedImagePath = null;
    if (path != null) _imageStorage.deleteIfManaged(path);
  }

  // Nombre obligatorio, distinto del reservado del sistema y sin repetirse con
  // otra categoría (sin distinguir mayúsculas ni tildes).
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
    if (!_formKey.currentState!.validate()) return;

    // Limpiar error anterior
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
      // Mostrar error en el formulario y revertir toggle
      setState(() {
        _saveError = error;
        _isActive = true;
      });
      return;
    }

    // La imagen elegida quedó guardada: ya no se descarta al cerrar. Si
    // reemplazó a otra que tenía la categoría, la anterior se borra.
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
      dismissLabel: 'Cancelar',
    );
    if (!confirm) return;
    setState(() => _isActive = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return FormSheet(
      title: isEditing ? 'Editar categoría' : 'Nueva categoría',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.pop(context),
        primaryLabel: isEditing ? 'Guardar' : 'Crear',
        onPrimary: _save,
      ),
      children: [
        // Selector de imagen
        AppPhotoSlot(imagePath: _imagePath, onTap: _pickImage),
        const SizedBox(height: AppSpacing.s16),

        // Nombre
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

        // Descripción
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
            title: 'Categoría activa',
            subtitle: _isActive ? 'Visible en el sistema' : 'Oculta en el sistema',
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
