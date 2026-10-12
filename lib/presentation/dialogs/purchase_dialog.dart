import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/purchase_provider.dart';
import '../../application/location_options.dart';
import '../../application/supplier_provider.dart';
import '../../application/material_provider.dart';
import '../../application/unit_provider.dart';
import '../../models/purchase_model.dart';
import '../../models/unit_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/supplier_dialog.dart';
import '../dialogs/material_dialog.dart';
import '../widgets/linked_price_fields.dart'
    show
        LinkedPriceController,
        LinkedPriceFields,
        measureUnitInfoMessage,
        priceInfoMessage;
import '../widgets/unit_quantity_input.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../widgets/focus_utils.dart';
import '../widgets/app_controls.dart';
import '../../application/form_validation.dart';
import '../../config/date_formatters.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/transaction_date_field.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_style.dart';
import '../../models/default_records.dart';
import '../../config/app_clock.dart';
import '../../config/rounding.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/app_buttons.dart';

class PurchaseDialog extends ConsumerStatefulWidget {
  final PurchaseModel? purchase;

  const PurchaseDialog({super.key, this.purchase});

  @override
  ConsumerState<PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends ConsumerState<PurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _totalController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedSupplierId;
  bool _isMaterial = true;
  int? _selectedLocationId;
  int? _selectedEventId;
  final List<Map<String, dynamic>> _materialItems = [];
  bool _isLoading = false;
  // Error de la lista de materiales (vacía) y error general al registrar.
  String? _itemsError;
  String? _error;
  // Un total escrito a mano manda sobre el calculado de los ítems (solo el monto).
  bool _totalOverridden = false;
  late DateTime _date = widget.purchase?.date ?? appNow();
  bool _dateChanged = false;

  @override
  void initState() {
    super.initState();
    _totalController.addListener(_clearError);
    if (widget.purchase != null) {
      _selectedSupplierId = widget.purchase!.supplierId;
      _isMaterial = widget.purchase!.isMaterial;
      _selectedLocationId = widget.purchase?.locationId;
      _selectedEventId = widget.purchase?.eventId;
      _descriptionController.text = widget.purchase!.description ?? '';
      _totalController.text = widget.purchase!.totalAmount > 0
          ? fixed2(widget.purchase!.totalAmount)
          : '';
      _notesController.text = widget.purchase!.notes ?? '';
      _loadExistingItems();
    }
  }

  Future<void> _loadExistingItems() async {
    if (widget.purchase == null || !widget.purchase!.isMaterial) return;
    final items = await ref
        .read(purchaseProvider.notifier)
        .getItemsForPurchase(widget.purchase!.id);
    if (mounted) {
      setState(() {
        for (final item in items) {
          _materialItems.add({
            'materialId': item.materialId,
            'materialName': item.materialName,
            'quantity': item.quantity,
            'unitPrice': item.unitPrice,
          });
        }
        // Un total guardado distinto de la suma de los ítems fue editado a mano.
        final calculated = ref
            .read(purchaseRepositoryProvider)
            .calculateMaterialsTotal(_materialItems);
        _totalOverridden =
            (widget.purchase!.totalAmount - calculated).abs() > 0.005;
        _recalcTotal();
      });
    }
  }

  void _clearError() {
    if (_error != null && mounted) setState(() => _error = null);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _totalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recalcTotal() {
    if (!_isMaterial || _totalOverridden) return;
    final total = ref
        .read(purchaseRepositoryProvider)
        .calculateMaterialsTotal(_materialItems);
    _totalController.text = fixed2(total);
  }

  static TextInputFormatter _amountFormatter() =>
      TextInputFormatter.withFunction((oldValue, newValue) {
        final text = newValue.text;
        if (text.isEmpty || text == '0') return newValue;
        if (!RegExp(r'^[0-9.]*$').hasMatch(text)) return oldValue;
        if (text.startsWith('0') && !text.startsWith('0.')) return oldValue;
        if (double.tryParse(text) == null && text != '.') return oldValue;
        return newValue;
      });

  String _quantityWithUnit(double quantity, UnitModel? unit) {
    final number = formatMaterialQuantity(
      quantity,
      unitType: unit?.type ?? 'medida',
      unitName: unit?.name ?? '',
    );
    final unitName = unit?.name;
    if (unitName == null || unitName.isEmpty) return number;
    return '$number ${unitLabel(unitName, quantity)}';
  }

  void _showAddSupplierSheet() {
    dismissKeyboard();
    showAppSheet<void>(
      context,
      builder: (_) => SupplierDialog(
        onSaved: (supplierId) {
          setState(() {
            _selectedSupplierId = supplierId;
            _error = null;
          });
        },
      ),
    );
  }

  void _showAddMaterialItem() {
    dismissKeyboard();
    showAppSheet<void>(
      context,
      heightFactor: 0.94,
      builder: (_) => _AddMaterialItemSheet(
        // Un material ya agregado no se repite: se quita de la lista o se
        // cambia su cantidad con + y −.
        existingMaterialIds: {
          for (final item in _materialItems) item['materialId'] as int,
        },
        onAdded: (item) {
          setState(() {
            _error = null;
            _itemsError = null;
            _materialItems.add(item);
            _recalcTotal();
          });
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await pickTransactionDate(context, _date);
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateChanged = true;
      });
    }
  }

  // Total: obligatorio en un gasto; en una compra de materiales puede quedar
  // vacío (se calcula de los materiales). Mayor a 0 y con dos decimales.
  String? _validateTotal(String? value) =>
      validateAmountField(value, required: !_isMaterial);

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    if (_isMaterial && _materialItems.isEmpty) {
      setState(() => _itemsError = 'Agrega al menos un material');
      return;
    }
    if (!valid) return;

    var total = round2(double.tryParse(_totalController.text.trim()) ?? 0);
    if (_isMaterial && _totalController.text.trim().isEmpty) {
      total = ref
          .read(purchaseRepositoryProvider)
          .calculateMaterialsTotal(_materialItems);
    }
    if (total <= 0) {
      setState(() => _error = 'El total debe ser mayor a 0');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    String? error;
    if (widget.purchase == null) {
      error = await ref
          .read(purchaseProvider.notifier)
          .createPurchase(
            supplierId: _selectedSupplierId,
            locationId: _selectedLocationId,
            eventId: _selectedEventId,
            isMaterial: _isMaterial,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            totalAmount: total,
            date: _dateChanged ? _date : appNow(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            items: _isMaterial ? _materialItems : [],
          );
    } else {
      error = await ref
          .read(purchaseProvider.notifier)
          .editPurchase(
            purchaseId: widget.purchase!.id,
            supplierId: _selectedSupplierId,
            locationId: _selectedLocationId,
            eventId: _selectedEventId,
            isMaterial: _isMaterial,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            totalAmount: total,
            date: _date,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            newItems: _isMaterial ? _materialItems : [],
          );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        setState(() => _error = error);
      } else {
        Navigator.pop(context);
      }
    }
  }

  // Cancelar no borra; si algún material ya se usó, el error se muestra aquí.
  Future<void> _cancelPurchase() async {
    final confirmed = await confirmCancellation(
      context,
      title: '¿Cancelar compra?',
      message: widget.purchase!.isMaterial
          ? 'Se restará del stock de los materiales lo comprado. La compra '
                'seguirá en la lista, marcada como cancelada, y ya no se '
                'podrá editar.'
          : 'La compra seguirá en la lista, marcada como cancelada, y ya no '
                'se podrá editar.',
      confirmLabel: 'Cancelar compra',
    );
    if (!confirmed || !mounted) return;
    final error = await ref
        .read(purchaseProvider.notifier)
        .cancelPurchase(widget.purchase!.id);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.purchase != null;
    final allSuppliers = ref.watch(supplierProvider).suppliers;
    final suppliers = allSuppliers
        .where(
          (s) => !s.isDefault && (s.isActive || s.id == _selectedSupplierId),
        )
        .toList();
    final supplierValue = suppliers.any((s) => s.id == _selectedSupplierId)
        ? _selectedSupplierId
        : null;

    final allMaterials = ref.watch(materialProvider).materials;
    final allUnits = ref.watch(unitProvider).units;
    UnitModel? unitOf(Object? materialId) {
      final material = allMaterials
          .where((m) => m.id == materialId)
          .firstOrNull;
      if (material == null) return null;
      return allUnits.where((u) => u.id == material.unitId).firstOrNull;
    }

    return AppSheetScaffold(
      title: isEditing ? 'Editar compra' : 'Nueva compra',
      leadingLabel: 'Cancelar',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: AppSegmented<bool>(
                segments: const [
                  AppSegment(true, 'Materiales'),
                  AppSegment(false, 'Gasto general'),
                ],
                selected: _isMaterial,
                onChanged: (value) {
                  if (value == null || value == _isMaterial) return;
                  setState(() {
                    _error = null;
                    _itemsError = null;
                    _isMaterial = value;
                    _totalOverridden = false;
                    _materialItems.clear();
                    _totalController.clear();
                    _descriptionController.clear();
                  });
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s8,
                  AppSpacing.s16,
                  AppSpacing.s32 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SearchablePickerField<int>(
                      label: 'Proveedor',
                      searchHint: 'Buscar proveedor',
                      value: supplierValue,
                      options: [
                        const PickerOption<int>(null, DefaultRecords.supplier),
                        for (final s in suppliers)
                          PickerOption<int>(s.id, s.name),
                      ],
                      onChanged: (val) => setState(() {
                        _selectedSupplierId = val;
                        _error = null;
                      }),
                      trailing: AppFieldAction(
                        icon: Icons.add_business_rounded,
                        tooltip: 'Nuevo proveedor',
                        onPressed: _showAddSupplierSheet,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    SearchablePickerField<int>(
                      label: 'Ubicación',
                      searchHint: 'Buscar ubicación',
                      value: _selectedLocationId,
                      options: [
                        const PickerOption<int>(null, 'Sin ubicación'),
                        for (final l in ref.watch(locationProvider).locations)
                          if (l.isActive || l.id == _selectedLocationId)
                            PickerOption<int>(
                              l.id,
                              locationLabel(l),
                              subtitle: locationZone(l),
                              selectedLabel: locationLabelWithZone(l),
                            ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedLocationId = val),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    SearchablePickerField<int>(
                      label: 'Evento',
                      searchHint: 'Buscar evento',
                      value: _selectedEventId,
                      options: [
                        const PickerOption<int>(null, 'Sin evento'),
                        for (final e in ref.watch(eventProvider).events)
                          if (e.isActive || e.id == _selectedEventId)
                            PickerOption<int>(e.id, e.name),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedEventId = val),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    AppDateField(
                      label: 'Fecha',
                      valueText: formatDate(_date),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    if (_isMaterial) ...[
                      Row(
                        children: [
                          const Expanded(child: FormSectionLabel('Materiales')),
                          TextButton.icon(
                            onPressed: _showAddMaterialItem,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Agregar'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.cyanDark,
                              minimumSize: const Size(
                                AppMetrics.minTap,
                                AppMetrics.minTap,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppMetrics.groupRadius,
                          ),
                        ),
                        child: _materialItems.isEmpty
                            ? ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: AppMetrics.rowMinHeight,
                                ),
                                child: Center(
                                  child: Text(
                                    'Sin materiales agregados',
                                    style: AppText.rowSubtitle(context),
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < _materialItems.length; i++)
                                    _materialRow(context, i, unitOf),
                                ],
                              ),
                      ),
                      if (_itemsError != null) FormErrorText(_itemsError!),
                      const SizedBox(height: AppSpacing.s16),
                      LabeledField(
                        label: 'Total (Bs.)',
                        builder: (_) => TextFormField(
                          key: const ValueKey('purchase-total-materials'),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: _totalController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_amountFormatter()],
                          validator: _validateTotal,
                          decoration: InputDecoration(
                            helperText: _totalOverridden
                                ? 'Total escrito a mano'
                                : 'Calculado de los materiales; puedes editarlo',
                            suffixIcon: _totalOverridden
                                ? IconButton(
                                    tooltip: 'Usar el total calculado',
                                    icon: const Icon(
                                      Icons.restart_alt_rounded,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () => setState(() {
                                      _totalOverridden = false;
                                      _recalcTotal();
                                    }),
                                  )
                                : null,
                          ),
                          onChanged: (_) {
                            if (!_totalOverridden) {
                              setState(() => _totalOverridden = true);
                            }
                          },
                        ),
                      ),
                    ] else ...[
                      LabeledField(
                        label: 'Descripción del gasto',
                        builder: (_) => TextFormField(
                          key: const ValueKey('purchase-description'),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Ej: transporte, entradas a eventos, etc.',
                          ),
                          validator: (v) =>
                              validateRequired(v) ?? validateOptionalText(v),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      LabeledField(
                        label: 'Total (Bs.)',
                        builder: (_) => TextFormField(
                          key: const ValueKey('purchase-total-expense'),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: _totalController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_amountFormatter()],
                          decoration: const InputDecoration(hintText: '0'),
                          validator: _validateTotal,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s16),
                    LabeledField(
                      label: 'Notas',
                      builder: (_) => TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: _notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Observaciones opcionales',
                        ),
                        validator: validateOptionalText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    if (_error != null) ...[
                      FormErrorText(_error!),
                      const SizedBox(height: AppSpacing.s16),
                    ],
                    ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              height: AppSpacing.s20,
                              width: AppSpacing.s20,
                              child: CircularProgressIndicator(
                                color: AppColors.onDark,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditing ? 'Guardar' : 'Registrar compra',
                              maxLines: 1,
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onDark,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                    ),
                    if (isEditing && !widget.purchase!.isCanceled) ...[
                      const SizedBox(height: AppButtons.stackGap),
                      AppActionButton(
                        label: 'Cancelar compra',
                        kind: AppButtonKind.destructive,
                        onPressed: _isLoading ? null : _cancelPurchase,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _materialRow(
    BuildContext context,
    int index,
    UnitModel? Function(Object?) unitOf,
  ) {
    final item = _materialItems[index];
    final quantity = item['quantity'] as double;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quitar material',
            icon: const Icon(
              Icons.remove_circle_rounded,
              size: 24,
              color: AppColors.error,
            ),
            onPressed: () => setState(() {
              _error = null;
              _materialItems.removeAt(index);
              _recalcTotal();
            }),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['materialName'] as String,
                    style: AppText.rowTitle(context),
                  ),
                  Text(
                    '${_quantityWithUnit(quantity, unitOf(item['materialId']))}  ·  Bs. ${fixed2(quantity * (item['unitPrice'] as double))}',
                    style: AppText.rowSubtitle(context),
                  ),
                ],
              ),
            ),
          ),
          AppStepper(
            onMinus: quantity <= 1
                ? null
                : () => setState(() {
                    _error = null;
                    _materialItems[index]['quantity'] = quantity - 1;
                    _recalcTotal();
                  }),
            onPlus: () => setState(() {
              _error = null;
              _materialItems[index]['quantity'] = quantity + 1;
              _recalcTotal();
            }),
          ),
        ],
      ),
    );
  }
}

class _AddMaterialItemSheet extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>) onAdded;
  final Set<int> existingMaterialIds;

  const _AddMaterialItemSheet({
    required this.onAdded,
    required this.existingMaterialIds,
  });

  @override
  ConsumerState<_AddMaterialItemSheet> createState() =>
      _AddMaterialItemSheetState();
}

class _AddMaterialItemSheetState extends ConsumerState<_AddMaterialItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  int? _selectedMaterialId;
  String? _selectedMaterialName;
  String? _materialError;
  double _fractionQuantity = 0;
  String? _quantityError;
  late final LinkedPriceController _container = LinkedPriceController(
    price: _priceController,
  );

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(() {
      if (!_isContainer(_selectedMaterialId)) {
        setState(() => _container.setQuantity(_currentQuantity));
      }
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _container.dispose();
    super.dispose();
  }

  UnitModel? _unitOf(int? materialId) {
    final material = ref
        .read(materialProvider)
        .materials
        .where((m) => m.id == materialId)
        .firstOrNull;
    if (material == null) return null;
    return ref
        .read(unitProvider)
        .units
        .where((u) => u.id == material.unitId)
        .firstOrNull;
  }

  bool _isContainer(int? materialId) {
    final unit = _unitOf(materialId);
    return unit != null && isFractionFriendlyUnitType(unit.type);
  }

  bool _isMedida(int? materialId) => _unitOf(materialId)?.type == unitTypeMedida;

  double get _currentQuantity => _isContainer(_selectedMaterialId)
      ? _fractionQuantity
      : (double.tryParse(_quantityController.text.trim()) ?? 0);

  void _resetFor(double? pricePerUnit) {
    _fractionQuantity = 0;
    _quantityError = null;
    _quantityController.clear();
    _container.setQuantity(0);
    _container.setPrice(pricePerUnit);
  }

  // Elegir un material que ya está en la compra se avisa al instante.
  String? _duplicateError(int? materialId) =>
      materialId != null && widget.existingMaterialIds.contains(materialId)
      ? 'Ese material ya está en la compra. Quítalo de la lista o cambia su cantidad con + y −.'
      : null;

  void _showCreateMaterialSheet() {
    dismissKeyboard();
    showAppSheet<void>(
      context,
      builder: (_) => MaterialDialog(
        onSaved: (materialId, materialName, pricePerUnit, _) {
          if (mounted) {
            setState(() {
              _selectedMaterialId = materialId;
              _selectedMaterialName = materialName;
              _materialError = _duplicateError(materialId);
              _resetFor(pricePerUnit);
              // El stock inicial del material ya quedó como su propia compra.
              _quantityController.clear();
            });
          }
        },
      ),
    );
  }

  void _add() {
    final valid = _formKey.currentState!.validate();
    if (_selectedMaterialId == null) {
      setState(() => _materialError = 'Selecciona un material');
      return;
    }
    final duplicate = _duplicateError(_selectedMaterialId);
    if (duplicate != null) {
      setState(() => _materialError = duplicate);
      return;
    }
    final container = _isContainer(_selectedMaterialId);
    if (container && _fractionQuantity <= 0) {
      setState(() => _quantityError = 'Selecciona una cantidad');
      return;
    }
    if (!valid) return;
    final quantity = roundQuantity(
      _currentQuantity,
      unitType: _unitOf(_selectedMaterialId)?.type ?? 'medida',
    );
    final unitPrice = _container.resolvedPrice ?? 0;
    widget.onAdded({
      'materialId': _selectedMaterialId,
      'materialName': _selectedMaterialName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final materials = ref
        .watch(materialProvider)
        .materials
        .where((m) => m.isActive)
        .toList();
    final units = ref.watch(unitProvider).units;
    final selectedMaterial = materials
        .where((m) => m.id == _selectedMaterialId)
        .firstOrNull;
    final selectedUnit = selectedMaterial != null
        ? units.where((u) => u.id == selectedMaterial.unitId).firstOrNull
        : null;
    final discrete =
        selectedUnit != null &&
        isDiscreteUnit(selectedUnit.type, selectedUnit.name);
    final label = selectedUnit != null
        ? 'Cantidad (${selectedUnit.name})'
        : 'Cantidad';

    return AppSheetScaffold(
      title: 'Agregar material',
      leadingLabel: 'Cancelar',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s8,
            AppSpacing.s16,
            AppSpacing.s32 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchablePickerField<int>(
                label: 'Material',
                searchHint: 'Buscar material',
                value: _selectedMaterialId,
                options: [
                  for (final m in materials) PickerOption<int>(m.id, m.name),
                ],
                onChanged: (val) {
                  final mat = materials.where((m) => m.id == val).firstOrNull;
                  setState(() {
                    _selectedMaterialId = val;
                    _selectedMaterialName = mat?.name;
                    _materialError = _duplicateError(val);
                    _resetFor(mat?.pricePerUnit);
                  });
                },
                trailing: AppFieldAction(
                  icon: Icons.add_rounded,
                  tooltip: 'Crear nuevo material',
                  onPressed: _showCreateMaterialSheet,
                ),
              ),
              if (_materialError != null) FormErrorText(_materialError!),
              const SizedBox(height: AppSpacing.s16),
              if (selectedUnit != null &&
                  isFractionFriendlyUnitType(selectedUnit.type))
                FractionQuantityPicker(
                  unit: selectedUnit.name,
                  value: _fractionQuantity,
                  onChanged: (v) => setState(() {
                    _fractionQuantity = v;
                    _quantityError = null;
                    _container.setQuantity(v);
                  }),
                )
              else if (discrete)
                WholeNumberQuantityField(
                  controller: _quantityController,
                  labelText: label,
                  extraValidator: (qty) =>
                      qty > maxQuantity ? 'El valor es demasiado grande' : null,
                )
              else
                LabeledField(
                  label: label,
                  builder: (_) => TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: '0'),
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        if (newValue.text == '0') return newValue;
                        if (newValue.text.startsWith('0') &&
                            !newValue.text.startsWith('0.')) {
                          return oldValue;
                        }
                        if (double.tryParse(newValue.text) == null &&
                            newValue.text != '.') {
                          return oldValue;
                        }
                        return newValue;
                      }),
                    ],
                    validator: (v) =>
                        validateDecimal(v, maxDecimals: 2, max: maxQuantity),
                  ),
                ),
              if (_quantityError != null) FormErrorText(_quantityError!),
              const SizedBox(height: AppSpacing.s16),
              LinkedPriceFields(
                controller: _container,
                onChanged: () => setState(() {}),
                priceLabel: 'Precio por unidad (Bs.)',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s8,
                  AppSpacing.s4,
                  AppSpacing.s24,
                ),
                child: Text(
                  _isMedida(_selectedMaterialId)
                      ? '$priceInfoMessage $measureUnitInfoMessage'
                      : priceInfoMessage,
                  style: AppText.footnote(context),
                ),
              ),
              ElevatedButton(
                onPressed: _add,
                child: Text(
                  'Agregar',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
