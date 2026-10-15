import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../application/image_storage_provider.dart';
import '../../data/services/image_storage.dart';
import '../../application/product_provider.dart';
import '../../application/category_provider.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../config/rounding.dart';
import '../widgets/unit_quantity_input.dart';
import '../widgets/app_buttons.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../../application/form_validation.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_widgets.dart';
import '../../models/default_records.dart';

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
  late final TextEditingController _priceAController;
  late final TextEditingController _priceBController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  // Llaves de los campos de precio y costo: al escribir en un precio se vuelve a
  // validar lo que depende de él, sin esperar a "Guardar".
  final _priceAKey = GlobalKey<FormFieldState<String>>();
  final _priceBKey = GlobalKey<FormFieldState<String>>();
  final _costKey = GlobalKey<FormFieldState<String>>();
  String? _imagePath;
  // Copia permanente de la imagen elegida en esta sesión (aún sin guardar).
  String? _pickedImagePath;
  // Se guarda al iniciar: `ref` ya no se puede usar dentro de dispose().
  late final ImageStorage _imageStorage;
  int? _selectedCategoryId;
  late bool _isActive;

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
  }

  // Los importes se muestran siempre con dos decimales ("50.00").
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
    // Si solo se llenó uno de los dos precios, el repositorio iguala el otro.
    final priceA = double.tryParse(_priceAController.text.trim());
    final priceB = double.tryParse(_priceBController.text.trim());
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
          priceA: priceA,
          priceB: priceB,
          productionCost: double.tryParse(_costController.text.trim()),
          stock: int.parse(_stockController.text.trim()),
          isActive: _isActive,
        );
    // La imagen elegida quedó guardada: ya no se descarta al cerrar. Si
    // reemplazó a otra que tenía el producto, la anterior se borra.
    _pickedImagePath = null;
    final previous = widget.product?.image;
    if (previous != null && previous != _imagePath) {
      await _imageStorage.deleteIfManaged(previous);
    }
    if (mounted) Navigator.pop(context);
  }

  // Solo uno de los dos precios es obligatorio: si este está vacío, basta con
  // que el otro (de [other]) tenga valor. Lo escrito debe ser un importe válido
  // (mayor a 0, hasta dos decimales).
  String? _validatePrice(String? v, TextEditingController other) {
    final text = (v ?? '').trim();
    if (text.isEmpty) {
      return other.text.trim().isEmpty ? 'Indica al menos un precio' : null;
    }
    return validateAmountField(text);
  }

  // Al escribir en un precio se revalida el otro (ya no hace falta si este se
  // llenó) y el costo, que depende de ambos.
  void _onPriceChanged(GlobalKey<FormFieldState<String>> otherPriceKey) {
    otherPriceKey.currentState?.validate();
    _costKey.currentState?.validate();
  }

  String? _validateCost(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final invalid = validateAmountField(v, allowZero: true);
    if (invalid != null) return invalid;
    final cost = double.parse(v.trim());
    // El costo debe ser menor que ambos precios de venta. Si solo hay uno
    // escrito, ese es también el valor del otro.
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
      dismissLabel: 'Cancelar',
    );
    if (!confirm) return;
    setState(() => _isActive = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    // Solo categorías activas en el dropdown (más la que ya tenía el producto
    // que se edita). La categoría predeterminada se ofrece como la opción
    // "Sin categoría" (valor nulo), no como una categoría más.
    final allCategories = ref.watch(categoryProvider).categories;
    final categories = allCategories
        .where(
          (c) => !c.isDefault && (c.isActive || c.id == _selectedCategoryId),
        )
        .toList();
    // El valor del selector solo puede ser una opción que exista en la lista:
    // la categoría predeterminada es la opción nula.
    final categoryValue = categories.any((c) => c.id == _selectedCategoryId)
        ? _selectedCategoryId
        : null;

    return FormSheet(
      title: isEditing ? 'Editar producto' : 'Nuevo producto',
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
            decoration: const InputDecoration(hintText: 'Nombre del producto'),
            validator: validateName,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Categoría
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
        const SizedBox(height: AppSpacing.s16),

        // Precios de venta (A y B, independientes) y costo de producción
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

        // Stock: siempre un número entero (un "." se rechaza con aviso en
        // vez de descartarse o guardarse como 0).
        WholeNumberQuantityField(
          controller: _stockController,
          labelText: 'Stock',
          allowZero: true,
          extraValidator: (qty) =>
              qty > maxQuantity ? 'El valor es demasiado grande' : null,
        ),

        // Estado: solo al editar
        if (isEditing) ...[
          const SizedBox(height: AppSpacing.s16),
          AppToggleRow(
            title: 'Producto activo',
            subtitle: _isActive
                ? 'Disponible para ventas'
                : 'No disponible para ventas',
            value: _isActive,
            onChanged: _onToggleActive,
          ),
        ],
      ],
    );
  }
}
