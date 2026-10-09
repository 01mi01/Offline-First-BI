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
    show LinkedPriceController, measureUnitInfoMessage, priceInfoMessage;
import '../widgets/unit_quantity_input.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../widgets/focus_utils.dart';
import '../widgets/ios_controls.dart';
import '../widgets/ios_group.dart';
import '../widgets/ios_quantity.dart';
import '../widgets/ios_sheet.dart';
import '../widgets/ios_style.dart';
import '../widgets/searchable_picker.dart' show PickerOption;
import '../../models/default_records.dart';
import '../../config/app_clock.dart';
import '../../config/rounding.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
    showIosSheet<void>(
      context,
      heightFactor: 0.94,
      builder: (_) => _AddMaterialItemSheet(
        onAdded: (item) {
          setState(() {
            _error = null;
            final index = _materialItems.indexWhere(
              (i) => i['materialId'] == item['materialId'],
            );
            if (index >= 0) {
              _materialItems[index] = item;
            } else {
              _materialItems.add(item);
            }
            _recalcTotal();
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isMaterial && _materialItems.isEmpty) {
      setState(() => _error = 'Agrega al menos un material');
      return;
    }

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
    final confirmed = await showIosConfirm(
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

    return IosSheetScaffold(
      title: isEditing ? 'Editar compra' : 'Nueva compra',
      leadingLabel: 'Cancelar',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: IosSegmented<bool>(
                segments: const [
                  IosSegment(true, 'Materiales'),
                  IosSegment(false, 'Gasto general'),
                ],
                selected: _isMaterial,
                onChanged: (value) {
                  if (value == null || value == _isMaterial) return;
                  setState(() {
                    _error = null;
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
                padding: const EdgeInsets.only(
                  top: AppSpacing.s8,
                  bottom: AppSpacing.s32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IosSection(
                      children: [
                        IosPickerRow<int>(
                          label: 'Proveedor',
                          searchHint: 'Buscar proveedor',
                          value: supplierValue,
                          options: [
                            const PickerOption<int>(
                              null,
                              DefaultRecords.supplier,
                            ),
                            for (final s in suppliers)
                              PickerOption<int>(s.id, s.name),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedSupplierId = val;
                            _error = null;
                          }),
                          action: IconButton(
                            tooltip: 'Nuevo proveedor',
                            icon: const Icon(
                              Icons.add_business_outlined,
                              size: 22,
                              color: AppColors.primaryDark,
                            ),
                            onPressed: _showAddSupplierSheet,
                          ),
                        ),
                      ],
                    ),
                    IosSection(
                      children: [
                        IosPickerRow<int>(
                          label: 'Ubicación',
                          searchHint: 'Buscar ubicación',
                          value: _selectedLocationId,
                          options: [
                            const PickerOption<int>(null, 'Sin ubicación'),
                            for (final l
                                in ref.watch(locationProvider).locations)
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
                        IosPickerRow<int>(
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
                        IosDateRow(
                          date: _date,
                          onChanged: (value) => setState(() {
                            _date = value;
                            _dateChanged = true;
                          }),
                        ),
                      ],
                    ),
                    if (_isMaterial) ...[
                      IosSection(
                        header: 'Materiales',
                        headerTrailing: TextButton.icon(
                          onPressed: _showAddMaterialItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Agregar'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            minimumSize: const Size(AppIos.minTap, AppIos.minTap),
                          ),
                        ),
                        children: [
                          if (_materialItems.isEmpty)
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: AppIos.rowMinHeight,
                              ),
                              child: Center(
                                child: Text(
                                  'Sin materiales agregados',
                                  style: IosText.rowSubtitle(context),
                                ),
                              ),
                            )
                          else
                            for (var i = 0; i < _materialItems.length; i++)
                              _materialRow(context, i, unitOf),
                        ],
                      ),
                      IosSection(
                        children: [
                          IosTextFieldRow(
                            fieldKey: const ValueKey('purchase-total-materials'),
                            label: 'Total (Bs.)',
                            controller: _totalController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_amountFormatter()],
                            helper: _totalOverridden
                                ? 'Total escrito a mano'
                                : 'Calculado de los materiales; puedes editarlo',
                            suffix: _totalOverridden
                                ? IconButton(
                                    tooltip: 'Usar el total calculado',
                                    icon: const Icon(
                                      Icons.restart_alt,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () => setState(() {
                                      _totalOverridden = false;
                                      _recalcTotal();
                                    }),
                                  )
                                : null,
                            onChanged: (_) {
                              if (!_totalOverridden) {
                                setState(() => _totalOverridden = true);
                              }
                            },
                          ),
                        ],
                      ),
                    ] else
                      IosSection(
                        children: [
                          IosTextAreaRow(
                            fieldKey: const ValueKey('purchase-description'),
                            label: 'Descripción del gasto',
                            controller: _descriptionController,
                            hint: 'Ej: transporte, entradas a eventos, etc.',
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Campo requerido' : null,
                          ),
                          IosTextFieldRow(
                            fieldKey: const ValueKey('purchase-total-expense'),
                            label: 'Total (Bs.)',
                            controller: _totalController,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            inputFormatters: [_amountFormatter()],
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Campo requerido' : null,
                          ),
                        ],
                      ),
                    IosSection(
                      children: [
                        IosTextAreaRow(
                          label: 'Notas',
                          controller: _notesController,
                          hint: 'Observaciones opcionales',
                        ),
                      ],
                    ),
                    if (_error != null) IosErrorNote(message: _error!),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s16,
                        0,
                        AppSpacing.s16,
                        AppSpacing.s24,
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        child: _isLoading
                            ? const SizedBox(
                                height: AppSpacing.s20,
                                width: AppSpacing.s20,
                                child: CircularProgressIndicator(
                                  color: AppColors.textButtons,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isEditing ? 'Guardar' : 'Registrar compra',
                                maxLines: 1,
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textButtons,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                    if (isEditing && !widget.purchase!.isCanceled)
                      IosDestructiveGroup(
                        label: 'Cancelar compra',
                        onTap: _isLoading ? null : _cancelPurchase,
                      ),
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
              Icons.remove_circle,
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
                    style: IosText.rowTitle(context),
                  ),
                  Text(
                    '${_quantityWithUnit(quantity, unitOf(item['materialId']))}  ·  Bs. ${fixed2(quantity * (item['unitPrice'] as double))}',
                    style: IosText.rowSubtitle(context),
                  ),
                ],
              ),
            ),
          ),
          IosStepper(
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

  const _AddMaterialItemSheet({required this.onAdded});

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

  void _showCreateMaterialSheet() {
    dismissKeyboard();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MaterialDialog(
        onSaved: (materialId, materialName, pricePerUnit, _) {
          if (mounted) {
            setState(() {
              _selectedMaterialId = materialId;
              _selectedMaterialName = materialName;
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

    return IosSheetScaffold(
      title: 'Agregar material',
      leadingLabel: 'Cancelar',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            top: AppSpacing.s8,
            bottom: AppSpacing.s32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IosSection(
                children: [
                  IosPickerRow<int>(
                    label: 'Material',
                    searchHint: 'Buscar material',
                    value: _selectedMaterialId,
                    options: [
                      for (final m in materials)
                        PickerOption<int>(m.id, m.name),
                    ],
                    onChanged: (val) {
                      final mat = materials
                          .where((m) => m.id == val)
                          .firstOrNull;
                      setState(() {
                        _selectedMaterialId = val;
                        _selectedMaterialName = mat?.name;
                        _materialError = null;
                        _resetFor(mat?.pricePerUnit);
                      });
                    },
                  ),
                  IosRow(
                    title: 'Crear nuevo material',
                    titleColor: AppColors.primaryDark,
                    leading: const Icon(
                      Icons.add_circle_outline,
                      size: 22,
                      color: AppColors.primaryDark,
                    ),
                    onTap: _showCreateMaterialSheet,
                  ),
                ],
              ),
              if (_materialError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s32,
                    0,
                    AppSpacing.s16,
                    AppSpacing.s16,
                  ),
                  child: Text(_materialError!, style: IosText.error(context)),
                ),
              if (selectedUnit != null &&
                  isFractionFriendlyUnitType(selectedUnit.type))
                IosFractionPicker(
                  unit: selectedUnit.name,
                  value: _fractionQuantity,
                  onChanged: (v) => setState(() {
                    _fractionQuantity = v;
                    _quantityError = null;
                    _container.setQuantity(v);
                  }),
                )
              else
                IosSection(
                  children: [
                    if (discrete)
                      IosWholeNumberRow(
                        controller: _quantityController,
                        label: label,
                      )
                    else
                      IosTextFieldRow(
                        label: label,
                        controller: _quantityController,
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Campo requerido';
                          final qty = double.tryParse(v);
                          if (qty == null || qty <= 0) return 'Cantidad inválida';
                          return null;
                        },
                      ),
                  ],
                ),
              if (_quantityError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s32,
                    0,
                    AppSpacing.s16,
                    AppSpacing.s16,
                  ),
                  child: Text(_quantityError!, style: IosText.error(context)),
                ),
              IosSection(
                footer: _isMedida(_selectedMaterialId)
                    ? '$priceInfoMessage $measureUnitInfoMessage'
                    : priceInfoMessage,
                children: [
                  IosLinkedPriceRows(
                    controller: _container,
                    onChanged: () => setState(() {}),
                    priceLabel: 'Precio por unidad (Bs.)',
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                ),
                child: ElevatedButton(
                  onPressed: _add,
                  child: Text(
                    'Agregar',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textButtons,
                    ),
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
