import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/material_provider.dart';
import '../../application/unit_provider.dart';
import '../../config/rounding.dart';
import '../../models/material_model.dart';
import '../../models/unit_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../../application/form_validation.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_widgets.dart';
import '../widgets/linked_price_fields.dart';
import '../widgets/unit_quantity_input.dart';

class MaterialDialog extends ConsumerStatefulWidget {
  final MaterialModel? material;
  final Function(
    int materialId,
    String materialName,
    double pricePerUnit,
    double stock,
  )?
  onSaved;

  const MaterialDialog({super.key, this.material, this.onSaved});

  @override
  ConsumerState<MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends ConsumerState<MaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _stockController;
  late final TextEditingController _priceController;
  // Precio por unidad y total pagado enlazados, para cualquier tipo de unidad.
  // Comparte el campo de precio de arriba.
  late final LinkedPriceController _container;
  // Al EDITAR un contenedor: cantidad a la que corresponde el total pagado
  // (empieza en 1, con el precio actual).
  final _quantityController = TextEditingController(text: '1');
  int? _selectedUnitId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.material?.name ?? '');
    _descController = TextEditingController(
      text: widget.material?.description ?? '',
    );
    _stockController = TextEditingController(
      text: widget.material?.stock != null
          ? _stockText(widget.material!)
          : '',
    );
    _priceController = TextEditingController(
      text: widget.material?.pricePerUnit != null
          ? fixed2(widget.material!.pricePerUnit)
          : '',
    );
    _container = LinkedPriceController(price: _priceController);
    if (widget.material != null) {
      // Cantidad 1 al precio actual: guardar sin tocar nada no cambia el precio.
      _container.setQuantity(1);
      _container.setPrice(widget.material!.pricePerUnit);
    }
    _selectedUnitId = widget.material?.unitId;
    _isActive = widget.material?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    _container.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // Stock tal como se muestra: dos decimales en medidas, fracciones exactas
  // en unidades por fracciones, enteros en piezas.
  String _stockText(MaterialModel material) {
    final unit = ref
        .read(unitProvider)
        .units
        .where((u) => u.id == material.unitId)
        .firstOrNull;
    return formatMaterialQuantity(
      material.stock,
      unitType: unit?.type ?? 'medida',
      unitName: unit?.name ?? '',
    );
  }

  UnitModel? _unitById(List<UnitModel> units) =>
      units.where((u) => u.id == _selectedUnitId).firstOrNull;

  // Stock según la unidad elegida: piezas enteras ("unidad"), cuartos para las
  // unidades por fracciones y hasta dos decimales en medidas. Puede ser 0.
  String? _validateStock(String? value, UnitModel? unit) {
    if (unit != null && wholeNumberUnitNames.contains(unit.name.trim().toLowerCase())) {
      final error = validateDecimal(
        value,
        allowZero: true,
        maxDecimals: 0,
        max: maxQuantity,
      );
      return error;
    }
    final error = validateDecimal(
      value,
      allowZero: true,
      maxDecimals: 2,
      max: maxQuantity,
    );
    if (error != null) return error;
    if (unit != null && unit.type == unitTypeContenedor) {
      final quarters = (parseNumber(value) ?? 0) * 4;
      if ((quarters - quarters.roundToDouble()).abs() > 1e-9) {
        return 'Usa fracciones de un cuarto (0.25, 0.5, 0.75)';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final stock = double.tryParse(_stockController.text.trim()) ?? 0;
    // Manda el último campo escrito (precio por unidad o total pagado).
    final pricePerUnit = _container.resolvedPrice ?? 0;
    await ref
        .read(materialProvider.notifier)
        .save(
          id: widget.material?.id,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          unitId: _selectedUnitId!,
          stock: stock,
          pricePerUnit: pricePerUnit,
          isActive: _isActive,
        );
    if (mounted) Navigator.pop(context);
    if (widget.onSaved != null) {
      final materials = ref.read(materialProvider).materials;
      final saved = materials
          .where((m) => m.name == _nameController.text.trim())
          .firstOrNull;
      if (saved != null) {
        widget.onSaved!(saved.id, saved.name, saved.pricePerUnit, saved.stock);
      }
    }
  }

  Future<void> _onToggleActive(bool value) async {
    final confirm = await confirmCancellation(
      context,
      title: value ? 'Activar el material' : 'Desactivar el material',
      message: value
          ? 'El material volverá a estar disponible para nuevas compras y productos.'
          : 'El material no estará disponible para nuevas compras y productos.',
      confirmLabel: value ? 'Activar' : 'Desactivar',
      confirmKind: value ? AppButtonKind.primary : AppButtonKind.destructive,
      dismissLabel: 'Cancelar',
    );
    if (!confirm) return;
    setState(() => _isActive = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.material != null;
    final allUnits = ref.watch(unitProvider).units;
    // Al editar solo se ofrecen unidades del mismo tipo que la actual.
    final currentUnit = isEditing
        ? allUnits.where((u) => u.id == widget.material!.unitId).firstOrNull
        : null;
    final units = selectableUnitsFor(allUnits, current: currentUnit);
    final selectedUnit = _unitById(allUnits);
    final isMedida = selectedUnit?.type == unitTypeMedida;
    final unitName = selectedUnit?.name ?? 'unidad';

    return FormSheet(
      title: isEditing ? 'Editar material' : 'Nuevo material',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.pop(context),
        primaryLabel: isEditing ? 'Guardar' : 'Crear',
        onPrimary: _save,
      ),
      children: [
        // Nombre
        LabeledField(
          label: 'Nombre',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Nombre del material'),
            validator: validateName,
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
        const SizedBox(height: AppSpacing.s16),

        // Unidad de medida
        AppDropdownField<int>(
          label: 'Unidad',
          value: _selectedUnitId,
          helperText: currentUnit != null ? 'Solo unidades del mismo tipo' : null,
          options: [for (final u in units) DropdownOption<int>(u.id, u.name)],
          onChanged: (val) => setState(() => _selectedUnitId = val),
          validator: (v) => v == null ? 'Selecciona una unidad' : null,
        ),
        const SizedBox(height: AppSpacing.s16),

        // Stock y precio por unidad
        LabeledField(
          label: 'Stock',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _stockController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(hintText: '0'),
            // Al crear, el stock es la cantidad a la que corresponde el total.
            onChanged: (v) => setState(() {
              if (!isEditing) {
                _container.setQuantity(double.tryParse(v.trim()) ?? 0);
              }
            }),
            validator: (v) => _validateStock(v, selectedUnit),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        // Precio por unidad y total pagado, enlazados (todas las unidades).
        LinkedPriceFields(
          controller: _container,
          onChanged: () => setState(() {}),
          extraInfo: isMedida ? measureUnitInfoMessage : null,
        ),
        // Editar: la cantidad a la que corresponde el total.
        if (isEditing) ...[
          const SizedBox(height: AppSpacing.s16),
          LabeledField(
            label: 'Cantidad ($unitName)',
            builder: (_) => TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(hintText: '1'),
              onChanged: (v) => setState(
                () => _container.setQuantity(double.tryParse(v.trim()) ?? 0),
              ),
              validator: (v) =>
                  validateDecimal(v, maxDecimals: 2, max: maxQuantity),
            ),
          ),
        ],

        // Estado: solo al editar
        if (isEditing) ...[
          const SizedBox(height: AppSpacing.s16),
          AppToggleRow(
            title: 'Material activo',
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
