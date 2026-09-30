import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../application/image_storage_provider.dart';
import '../../data/services/image_storage.dart';
import '../../application/category_provider.dart';
import '../../models/category_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/confirm_cancel_dialog.dart';

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

  // Marcador para elegir una foto (también se muestra si el archivo de la
  // imagen ya no existe).
  Widget _imagePlaceholder() => Container(
    width: 100,
    height: 100,
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Icon(
      Icons.add_a_photo_outlined,
      color: AppColors.primary,
      size: 32,
    ),
  );

  Future<void> _onToggleActive(bool value) async {
    if (!value) {
      // Confirmar antes de desactivar
      final confirm = await confirmCancellation(
        context,
        title: '¿Desactivar categoría?',
        message: 'La categoría "${_nameController.text.trim()}" no estará disponible para nuevos productos.',
        confirmLabel: 'Desactivar',
        dismissLabel: 'Cancelar',
      );
      if (confirm != true) return;
    }
    setState(() => _isActive = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

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
                isEditing ? 'Editar categoría' : 'Nueva categoría',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Selector de imagen
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _imagePath != null
                        ? Image.file(
                            File(_imagePath!),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            // Si el archivo ya no existe, se muestra el
                            // marcador para elegir otra foto.
                            errorBuilder: (_, __, ___) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),

              // Nombre
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Nombre de la categoría',
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Categoría activa',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _isActive
                                ? 'Visible en el sistema'
                                : 'Oculta en el sistema',
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
                        activeColor: AppColors.primary,
                        inactiveTrackColor: AppColors.border,
                        inactiveThumbColor: AppColors.surface,
                        trackOutlineColor: MaterialStateProperty.all(
                          Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
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
                        Icons.error_outline,
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

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: Text(
                        isEditing ? 'Guardar' : 'Crear',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
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
