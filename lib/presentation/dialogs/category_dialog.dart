import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../application/category_provider.dart';
import '../../models/category_model.dart';
import '../../theme/app_theme.dart';

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
  late bool _isActive;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descController = TextEditingController(
      text: widget.category?.description ?? '',
    );
    _imagePath = widget.category?.image;
    _isActive = widget.category?.isActive ?? true;

    _nameController.addListener(_checkChanges);
    _descController.addListener(_checkChanges);
  }

  void _checkChanges() {
    final changed =
        _nameController.text.trim() != (widget.category?.name ?? '') ||
        _descController.text.trim() != (widget.category?.description ?? '') ||
        _imagePath != widget.category?.image ||
        _isActive != (widget.category?.isActive ?? true);
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imagePath = picked.path);
      _checkChanges();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(categoryProvider.notifier)
        .save(
          id: widget.category?.id,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          image: _imagePath,
          isActive: _isActive,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onToggleActive(bool value) async {
    if (!value) {
      // Confirmar antes de desactivar
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '¿Desactivar categoría?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'La categoría "${_nameController.text.trim()}" no estará disponible para nuevos productos.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Cancelar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Desactivar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    setState(() => _isActive = value);
    _checkChanges();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

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
                          )
                        : Container(
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
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nombre
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Nombre de la categoría',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Descripción opcional',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Toggle activo/inactivo solo en edición
              if (isEditing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
                            style: const TextStyle(
                              fontSize: 12,
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
                        inactiveThumbColor: Colors.white,
                        trackOutlineColor: MaterialStateProperty.all(
                          Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _hasChanges ? _save : null,
                      child: Text(
                        isEditing ? 'Guardar' : 'Crear',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
