import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/material_provider.dart';
import '../../application/unit_provider.dart';
import '../../models/material_model.dart';
import '../../models/unit_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/confirm_cancel_dialog.dart';
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
          ? formatNumber(widget.material!.stock)
          : '',
    );
    _priceController = TextEditingController(
      text: widget.material?.pricePerUnit != null
          ? formatNumber(widget.material!.pricePerUnit)
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

  UnitModel? _unitById(List<UnitModel> units) =>
      units.where((u) => u.id == _selectedUnitId).firstOrNull;

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
    final isMedida = selectedUnit?.type == unitTypeMedida;
    final unitName = selectedUnit?.name ?? 'unidad';

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
                onChanged: (val) => setState(() => _selectedUnitId = val),
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
                // Al crear, el stock es la cantidad a la que corresponde el total.
                onChanged: (v) => setState(() {
                  if (!isEditing) {
                    _container.setQuantity(double.tryParse(v.trim()) ?? 0);
                  }
                }),
                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
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
                  ),
                  onChanged: (v) => setState(
                    () => _container.setQuantity(double.tryParse(v.trim()) ?? 0),
                  ),
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
