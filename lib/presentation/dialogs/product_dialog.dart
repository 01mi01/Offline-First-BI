import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../application/image_storage_provider.dart';
import '../../data/services/image_storage.dart';
import '../../application/product_provider.dart';
import '../../data/repositories/product_repository.dart' show duplicateProductMessage;
import '../../application/category_provider.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../config/rounding.dart';
import '../widgets/unit_quantity_input.dart';
import '../widgets/app_buttons.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/discard_guard.dart';
import '../widgets/live_validation.dart';
import '../widgets/single_flight.dart';
import '../../application/form_validation.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';
import '../../models/default_records.dart';

class ProductDialog extends ConsumerStatefulWidget {
  final ProductModel? product;

  const ProductDialog({super.key, this.product});

  @override
  ConsumerState<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<ProductDialog>
    with SingleFlight<ProductDialog>, LiveValidation<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceAController;
  late final TextEditingController _priceBController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  final _priceAKey = GlobalKey<FormFieldState<String>>();
  final _priceBKey = GlobalKey<FormFieldState<String>>();
  final _costKey = GlobalKey<FormFieldState<String>>();
  String? _imagePath;
  String? _pickedImagePath;
  late final ImageStorage _imageStorage;
  int? _selectedCategoryId;
  late bool _isActive;
  String? _saveError;
  late final String _initialSignature;

  @override
  void initState() {
    super.initState();
    _imageStorage = ref.read(imageStorageProvider);
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _priceAController = TextEditingController(
      text: _formatPrice(widget.product?.priceA),
    );
    _priceBController = TextEditingController(
      text: _formatPrice(widget.product?.priceB),
    );
    _costController = TextEditingController(
      text: _formatPrice(widget.product?.productionCost),
    );
    _stockController = TextEditingController(
      text: widget.product?.stock != null
          ? widget.product!.stock.toString()
          : '',
    );

    _imagePath = widget.product?.image;
    _selectedCategoryId = widget.product?.categoryId;
    _isActive = widget.product?.isActive ?? true;
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
    _priceAController.text,
    _priceBController.text,
    _costController.text,
    _stockController.text,
    _imagePath ?? '',
    _selectedCategoryId,
    _isActive,
  ].join('\u0000');

  void _clearSaveError() {
    if (_saveError != null) setState(() => _saveError = null);
  }

  static String _formatPrice(double? value) =>
      value == null ? '' : fixed2(value);

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceAController.dispose();
    _priceBController.dispose();
    _costController.dispose();
    _stockController.dispose();
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

  Future<void> _save() async {
    if (!validateForm()) return;
    final priceA = double.tryParse(_priceAController.text.trim());
    final priceB = double.tryParse(_priceBController.text.trim());
    setState(() => _saveError = null);
    final error = await ref
        .read(productProvider.notifier)
        .save(
          id: widget.product?.id,
          categoryId: _selectedCategoryId,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          image: _imagePath,
          priceA: priceA,
          priceB: priceB,
          productionCost: double.tryParse(_costController.text.trim()),
          stock: int.parse(_stockController.text.trim()),
          isActive: _isActive,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() => _saveError = error);
      return;
    }
    _pickedImagePath = null;
    final previous = widget.product?.image;
    if (previous != null && previous != _imagePath) {
      await _imageStorage.deleteIfManaged(previous);
    }
    if (mounted) Navigator.pop(context);
  }

  String? _validateName(String? value) {
    final error = validateName(value);
    if (error != null) return error;
    final others = ref
        .read(productProvider)
        .products
        .where((p) => p.id != widget.product?.id)
        .map((p) => p.name);
    return validateUniqueName(
      value,
      others,
      message: duplicateProductMessage,
    );
  }

  String? _validatePrice(String? v, TextEditingController other) {
    final text = (v ?? '').trim();
    if (text.isEmpty) {
      return other.text.trim().isEmpty ? 'Indica al menos un precio' : null;
    }
    return validateAmountField(text);
  }

  void _onPriceChanged(GlobalKey<FormFieldState<String>> otherPriceKey) {
    otherPriceKey.currentState?.validate();
    _costKey.currentState?.validate();
  }

  String? _validateCost(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final invalid = validateAmountField(v, allowZero: true);
    if (invalid != null) return invalid;
    final cost = double.parse(v.trim());
    final typedA = double.tryParse(_priceAController.text.trim());
    final typedB = double.tryParse(_priceBController.text.trim());
    final priceA = typedA ?? typedB;
    final priceB = typedB ?? typedA;
    if (priceA == null || priceB == null) return null;
    if (cost >= priceA || cost >= priceB) {
      return 'Debe ser menor a los precios de venta';
    }
    return null;
  }

  Future<void> _onToggleActive(bool value) async {
    final confirm = await confirmCancellation(
      context,
      title: value ? 'Activar el producto' : 'Desactivar el producto',
      message: value
          ? 'El producto volverá a estar disponible para nuevas ventas.'
          : 'El producto no estará disponible para nuevas ventas.',
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
        _priceAController,
        _priceBController,
        _costController,
        _stockController,
      ]),
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final isEditing = widget.product != null;
    final allCategories = ref.watch(categoryProvider).categories;
    final categories = allCategories
        .where(
          (c) => !c.isDefault && (c.isActive || c.id == _selectedCategoryId),
        )
        .toList();
    final categoryValue = categories.any((c) => c.id == _selectedCategoryId)
        ? _selectedCategoryId
        : null;

    return FormSheet(
      title: isEditing ? 'Editar producto' : 'Nuevo producto',
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
            decoration: const InputDecoration(hintText: 'Nombre del producto'),
            validator: _validateName,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        AppDropdownField<int>(
          label: 'Categoría',
          value: categoryValue,
          options: [
            const DropdownOption<int>(null, DefaultRecords.category),
            for (final c in categories) DropdownOption<int>(c.id, c.name),
          ],
          onChanged: (val) => setState(() => _selectedCategoryId = val),
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
        const SizedBox(height: AppSpacing.s16),

        LabeledField(
          label: 'Precio A',
          builder: (_) => TextFormField(
            key: _priceAKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _priceAController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0.00'),
            validator: (v) => _validatePrice(v, _priceBController),
            onChanged: (_) => _onPriceChanged(_priceBKey),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        LabeledField(
          label: 'Precio B',
          builder: (_) => TextFormField(
            key: _priceBKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _priceBController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0.00'),
            validator: (v) => _validatePrice(v, _priceAController),
            onChanged: (_) => _onPriceChanged(_priceAKey),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        LabeledField(
          label: 'Costo de producción',
          builder: (_) => TextFormField(
            key: _costKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0.00'),
            validator: _validateCost,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        WholeNumberQuantityField(
          controller: _stockController,
          labelText: 'Stock',
          allowZero: true,
          extraValidator: (qty) =>
              qty > maxQuantity ? 'El valor es demasiado grande' : null,
        ),

        if (_saveError != null) FormErrorText(_saveError!),

        if (isEditing) ...[
          const SizedBox(height: AppSpacing.s16),
          AppToggleRow(
            title: 'Producto activo',
            subtitle: _isActive
                ? 'Disponible en el sistema'
                : 'No disponible en el sistema',
            value: _isActive,
            onChanged: _onToggleActive,
          ),
        ],
      ],
    );
  }
}
