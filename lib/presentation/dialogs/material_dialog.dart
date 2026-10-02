import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/material_pricing.dart';
import '../../application/material_provider.dart';
import '../../application/unit_provider.dart';
import '../../models/material_model.dart';
import '../../models/unit_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/info_hint.dart';
import '../widgets/unit_quantity_input.dart';

// Explicaciones del campo de precio (icono "i").
const String totalPaidInfoTitle = 'Total pagado';
const String totalPaidInfoMessage =
    'Ingresa el total que pagaste por la cantidad indicada, y la aplicación '
    'calculará el precio por unidad completa.';
const String unitPriceInfoTitle = 'Precio por unidad';
const String unitPriceInfoMessage =
    'Este precio corresponde a una unidad completa de medida, por ejemplo un '
    'metro o un litro.';

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
  // Al EDITAR un contenedor: cantidad a la que corresponde el total pagado.
  // Empieza en 1 con el precio actual, así que no cambia nada hasta que la
  // persona escribe un total o una cantidad (_priceTouched).
  final _quantityController = TextEditingController(text: '1');
  bool _priceTouched = false;
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
          ? formatNumber(widget.material!.stock)
          : '',
    );
    _priceController = TextEditingController(
      text: widget.material?.pricePerUnit != null
          ? formatNumber(widget.material!.pricePerUnit)
          : '',
    );
    _selectedUnitId = widget.material?.unitId;
    _isActive = widget.material?.isActive ?? true;

  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // Al CREAR un material tipo contenedor con stock inicial, el campo de precio
  // es el total pagado por ese stock (35 por media botella) y de ahí se calcula
  // el precio de la botella entera. Sin stock, o en cualquier otro tipo de
  // unidad (metro, litro...), el campo sigue siendo el precio por unidad.
  bool _paysTotal(UnitModel? unit) =>
      widget.material == null &&
      unit != null &&
      isFractionFriendlyUnitType(unit.type) &&
      (double.tryParse(_stockController.text.trim()) ?? 0) > 0;

  // Al EDITAR un material tipo contenedor, el precio se corrige con el total
  // pagado por una cantidad (igual que al crearlo).
  bool _editsTotal(UnitModel? unit) =>
      widget.material != null &&
      unit != null &&
      isFractionFriendlyUnitType(unit.type);

  UnitModel? _unitById(List<UnitModel> units) =>
      units.where((u) => u.id == _selectedUnitId).firstOrNull;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final entered = double.tryParse(_priceController.text.trim()) ?? 0;
    final stock = double.tryParse(_stockController.text.trim()) ?? 0;
    final unit = _unitById(ref.read(unitProvider).units);
    final double pricePerUnit;
    if (_editsTotal(unit)) {
      // Sin tocar el total ni la cantidad se conserva el precio exacto.
      pricePerUnit = _priceTouched
          ? (pricePerWholeUnit(
                  totalPaid: entered,
                  quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
                ) ??
                widget.material!.pricePerUnit)
          : widget.material!.pricePerUnit;
    } else if (_paysTotal(unit)) {
      pricePerUnit = pricePerWholeUnit(totalPaid: entered, quantity: stock) ?? 0;
    } else {
      pricePerUnit = entered;
    }
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
    if (!value) {
      final confirm = await confirmCancellation(
        context,
        title: '¿Desactivar material?',
        message: 'El material "${_nameController.text.trim()}" no estará disponible para nuevas compras y productos.',
        confirmLabel: 'Desactivar',
        dismissLabel: 'Cancelar',
      );
      if (confirm != true) return;
    }
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
    final paysTotal = _paysTotal(selectedUnit);
    final stockEntered = double.tryParse(_stockController.text.trim()) ?? 0;
    final totalEntered = double.tryParse(_priceController.text.trim()) ?? 0;
    final computedPrice = paysTotal
        ? pricePerWholeUnit(totalPaid: totalEntered, quantity: stockEntered)
        : null;
    final unitName = selectedUnit?.name ?? 'unidad';
    final editsTotal = _editsTotal(selectedUnit);
    final isMedida = selectedUnit?.type == unitTypeMedida;
    final editQuantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    // Precio de 1 unidad que se guardaría al editar un contenedor.
    final editedPrice = !_priceTouched
        ? widget.material?.pricePerUnit
        : pricePerWholeUnit(totalPaid: totalEntered, quantity: editQuantity);

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
              // Título del diálogo
              Text(
                isEditing ? 'Editar material' : 'Nuevo material',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Nombre
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Nombre del material',
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
              const SizedBox(height: AppSpacing.s16),

              // Unidad de medida
              DropdownButtonFormField<int>(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                value: _selectedUnitId,
                decoration: InputDecoration(
                  labelText: 'Unidad',
                  helperText: currentUnit != null
                      ? 'Solo unidades del mismo tipo'
                      : null,
                ),
                items: units
                    .map(
                      (u) => DropdownMenuItem(value: u.id, child: Text(u.name)),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedUnitId = val);
                },
                validator: (v) => v == null ? 'Selecciona una unidad' : null,
              ),
              const SizedBox(height: AppSpacing.s16),

              // Stock y precio por unidad
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _stockController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Stock',
                  hintText: '0',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: (paysTotal || editsTotal)
                      ? (editsTotal
                            ? 'Total pagado (Bs.)'
                            : 'Total pagado por el stock (Bs.)')
                      : 'Precio por unidad',
                  hintText: '0',
                  // Muestra qué precio por unidad entera se va a guardar.
                  helperText: paysTotal
                      ? (computedPrice != null
                            ? 'Precio de 1 $unitName: Bs. ${computedPrice.toStringAsFixed(2)}'
                            : 'Se calcula el precio de 1 $unitName')
                      : null,
                  // Explicación del campo (contenedor: total pagado; medida:
                  // precio de una unidad completa).
                  suffixIcon: (paysTotal || editsTotal)
                      ? const InfoHintButton(
                          title: totalPaidInfoTitle,
                          message: totalPaidInfoMessage,
                        )
                      : isMedida
                      ? const InfoHintButton(
                          title: unitPriceInfoTitle,
                          message: unitPriceInfoMessage,
                        )
                      : null,
                ),
                onChanged: (_) => setState(() => _priceTouched = true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo requerido';
                  if ((paysTotal || editsTotal) && (double.tryParse(v) ?? 0) <= 0) {
                    return 'Ingresa lo que pagaste';
                  }
                  return null;
                },
              ),
              // Editar un contenedor: la cantidad a la que corresponde el total.
              if (editsTotal) ...[
                const SizedBox(height: AppSpacing.s16),
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Cantidad ($unitName)',
                    hintText: '1',
                    helperText: editedPrice != null
                        ? 'Precio de 1 $unitName: Bs. ${editedPrice.toStringAsFixed(2)}'
                        : 'Se calcula el precio de 1 $unitName',
                  ),
                  onChanged: (_) => setState(() => _priceTouched = true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo requerido';
                    if ((double.tryParse(v) ?? 0) <= 0) {
                      return 'Ingresa la cantidad';
                    }
                    return null;
                  },
                ),
              ],
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
                            'Material activo',
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
