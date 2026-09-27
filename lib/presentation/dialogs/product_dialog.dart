import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../application/product_provider.dart';
import '../../application/category_provider.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';

class ProductDialog extends ConsumerStatefulWidget {
  final ProductModel? product;

  const ProductDialog({super.key, this.product});

  @override
  ConsumerState<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  String? _imagePath;
  int? _selectedCategoryId;
  late bool _isActive;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product?.priceA.toString() ?? '',
    );
    _costController = TextEditingController(
      text: widget.product?.productionCost?.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: widget.product?.stock != null
          ? widget.product!.stock.toString()
          : '',
    );

    _imagePath = widget.product?.image;
    _selectedCategoryId = widget.product?.categoryId;
    _isActive = widget.product?.isActive ?? true;

    _nameController.addListener(_checkChanges);
    _descController.addListener(_checkChanges);
    _priceController.addListener(_checkChanges);
    _costController.addListener(_checkChanges);
    _stockController.addListener(_checkChanges);
  }

  void _checkChanges() {
    final changed =
        _nameController.text.trim() != (widget.product?.name ?? '') ||
        _descController.text.trim() != (widget.product?.description ?? '') ||
        _priceController.text.trim() !=
            (widget.product?.priceA.toString() ?? '') ||
        _costController.text.trim() !=
            (widget.product?.productionCost?.toString() ?? '') ||
        _stockController.text.trim() !=
            (widget.product?.stock.toString() ?? '0') ||
        _imagePath != widget.product?.image ||
        _selectedCategoryId != widget.product?.categoryId ||
        _isActive != (widget.product?.isActive ?? true);
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
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
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    await ref
        .read(productProvider.notifier)
        .save(
          id: widget.product?.id,
          // Si no se eligió categoría, el repositorio asigna "Sin categoría":
          // este campo nunca debe bloquear el guardado.
          categoryId: _selectedCategoryId,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          image: _imagePath,
          // La app todavía no tiene una UI para diferenciar precio A/B, así
          // que por ahora ambos quedan iguales al único precio ingresado.
          priceA: price,
          priceB: price,
          productionCost: double.tryParse(_costController.text.trim()),
          stock: int.tryParse(_stockController.text.trim()) ?? 0,
          isActive: _isActive,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onToggleActive(bool value) async {
    if (!value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '¿Desactivar producto?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'El producto "${_nameController.text.trim()}" no estará disponible para nuevas ventas.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  0,
                  AppSpacing.s16,
                  AppSpacing.s8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s14,
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Cancelar',
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
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s14,
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Desactivar',
                          style: TextStyle(color: AppColors.surface),
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
    final isEditing = widget.product != null;
    // Solo categorías activas en el dropdown
    final categories = ref
        .watch(categoryProvider)
        .categories
        .where((c) => c.isActive)
        .toList();

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
                isEditing ? 'Editar producto' : 'Nuevo producto',
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
              const SizedBox(height: AppSpacing.s20),

              // Nombre
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Nombre del producto',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: AppSpacing.s16),

              // Categoría
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: categories
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedCategoryId = val);
                  _checkChanges();
                },
              ),
              const SizedBox(height: AppSpacing.s16),

              // Descripción
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Descripción opcional',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.s16),

              // Precio de venta y costo de producción
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Precio de venta',
                  hintText: '0.00',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo requerido';
                  final price = double.tryParse(v);
                  if (price == null) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Costo de producción',
                  hintText: '0.00',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final cost = double.tryParse(v);
                  if (cost == null) return 'Valor inválido';
                  final price =
                      double.tryParse(_priceController.text.trim()) ?? 0;
                  if (cost >= price) {
                    return 'Debe ser menor al precio de venta';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.s16),

              // Stock
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Stock inicial',
                  hintText: '0',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
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
                            'Producto activo',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _isActive
                                ? 'Disponible para ventas'
                                : 'No disponible para ventas',
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
                        trackOutlineColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.s24),

              // Botones cancelar y guardar
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
                      onPressed: _hasChanges ? _save : null,
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
