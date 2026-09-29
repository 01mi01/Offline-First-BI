import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/purchase_provider.dart';
import '../../application/supplier_provider.dart';
import '../../application/material_provider.dart';
import '../../application/unit_provider.dart';
import '../../models/purchase_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/supplier_dialog.dart';
import '../dialogs/material_dialog.dart';
import '../widgets/unit_quantity_input.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.purchase != null) {
      _selectedSupplierId = widget.purchase!.supplierId;
      _isMaterial = widget.purchase!.isMaterial;
      _selectedLocationId = widget.purchase?.locationId;
      _selectedEventId = widget.purchase?.eventId;
      _descriptionController.text = widget.purchase!.description ?? '';
      _totalController.text = widget.purchase!.totalAmount > 0
          ? formatNumber(widget.purchase!.totalAmount)
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
        _recalcTotal();
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _totalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Recalcula el total a partir de los ítems de material
  void _recalcTotal() {
    if (!_isMaterial) return;
    final total = ref
        .read(purchaseRepositoryProvider)
        .calculateMaterialsTotal(_materialItems);
    _totalController.text = formatNumber(total);
  }

  void _showAddSupplierSheet() {
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddMaterialItemSheet(
        onAdded: (item) {
          setState(() {
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
    // Sin proveedor elegido no se bloquea el formulario: el repositorio
    // asigna el proveedor por defecto "Sin proveedor".
    if (_isMaterial && _materialItems.isEmpty) {
      setState(() => _error = 'Agrega al menos un material');
      return;
    }

    final total = double.tryParse(_totalController.text.trim()) ?? 0;
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
            date: DateTime.now(),
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
            date: widget.purchase!.date,
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.purchase != null;
    final suppliers = ref
        .watch(supplierProvider)
        .suppliers
        .where((s) => s.isActive)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        top: AppSpacing.s24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s32,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Text(
                isEditing ? 'Editar compra' : 'Nueva compra',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Toggle material / gasto general
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Compra de materiales',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _isMaterial
                                ? 'Actualiza stock de materiales'
                                : 'Gasto general del negocio',
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isMaterial,
                      onChanged: (val) {
                        setState(() {
                          _isMaterial = val;
                          _materialItems.clear();
                          _totalController.clear();
                        });
                      },
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
              const SizedBox(height: AppSpacing.s20),

              // Selector de proveedor
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedSupplierId,
                      decoration: const InputDecoration(labelText: 'Proveedor'),
                      items: suppliers
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() {
                        _selectedSupplierId = val;
                        _error = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  GestureDetector(
                    onTap: _showAddSupplierSheet,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_business_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),

              // Selector de ubicación
              DropdownButtonFormField<int>(
                value: _selectedLocationId,
                decoration: const InputDecoration(labelText: 'Ubicación'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Sin ubicación'),
                  ),
                  ...ref
                      .watch(locationProvider)
                      .locations
                      .where((l) => l.isActive)
                      .map(
                        (l) => DropdownMenuItem(
                          value: l.id,
                          child: Text('${l.city}, ${l.country}'),
                        ),
                      )
                      .toList(),
                ],
                onChanged: (val) => setState(() => _selectedLocationId = val),
              ),
              const SizedBox(height: 20),

              // Selector de evento
              DropdownButtonFormField<int>(
                value: _selectedEventId,
                decoration: const InputDecoration(labelText: 'Evento'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Sin evento'),
                  ),
                  ...ref
                      .watch(eventProvider)
                      .events
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)),
                      )
                      .toList(),
                ],
                onChanged: (val) => setState(() => _selectedEventId = val),
              ),
              const SizedBox(height: AppSpacing.s20),

              // Sección de materiales
              if (_isMaterial) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Materiales',
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    GestureDetector(
                      onTap: _showAddMaterialItem,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                          vertical: AppSpacing.s6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.s4),
                            Text(
                              'Agregar',
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                if (_materialItems.isEmpty)
                  Text(
                    'Sin materiales agregados',
                    style: Theme.of(
                      context,
                    ).textTheme.displaySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  ..._materialItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['materialName'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s4),
                                // Edición inline de cantidad
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        final current =
                                            item['quantity'] as double;
                                        if (current <= 1) return;
                                        setState(() {
                                          _materialItems[index]['quantity'] =
                                              current - 1;
                                          _recalcTotal();
                                        });
                                      },
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.remove,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.s10,
                                      ),
                                      child: Text(
                                        formatNumber(
                                          item['quantity'] as double,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        final current =
                                            item['quantity'] as double;
                                        setState(() {
                                          _materialItems[index]['quantity'] =
                                              current + 1;
                                          _recalcTotal();
                                        });
                                      },
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    Text(
                                      'Bs. ${((item['quantity'] as double) * (item['unitPrice'] as double)).toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme
                                          .labelMedium?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _materialItems.removeAt(index);
                                _recalcTotal();
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              color: AppColors.error,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: AppSpacing.s16),

                // Total calculado automáticamente
                TextFormField(
                  controller: _totalController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Total (Bs.)'),
                ),
              ] else ...[
                // Gasto general
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del gasto',
                    hintText: 'Ej: transporte, entradas a eventos, etc.',
                  ),
                  maxLines: 2,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: AppSpacing.s16),
                TextFormField(
                  controller: _totalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue;
                      if (newValue.text == '0') return newValue;
                      if (newValue.text.startsWith('0') &&
                          !newValue.text.startsWith('0.'))
                        return oldValue;
                      if (double.tryParse(newValue.text) == null &&
                          newValue.text != '.')
                        return oldValue;
                      return newValue;
                    }),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Total (Bs.)',
                    hintText: '0',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
              ],
              const SizedBox(height: AppSpacing.s16),

              // Notas
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Observaciones opcionales',
                ),
                maxLines: 2,
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s12),
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
                          _error!,
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
              ],

              const SizedBox(height: AppSpacing.s24),

              // Botones cancelar y registrar
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
                      style: ElevatedButton.styleFrom(
                        alignment: Alignment.center,
                      ),
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              height: AppSpacing.s20,
                              width: AppSpacing.s20,
                              child: CircularProgressIndicator(
                                color: AppColors.surface,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditing ? 'Guardar' : 'Registrar compra',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
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

// Hoja para agregar un material a la compra
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

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _showCreateMaterialSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MaterialDialog(
        onSaved: (materialId, materialName, pricePerUnit, stock) {
          if (mounted) {
            setState(() {
              _selectedMaterialId = materialId;
              _selectedMaterialName = materialName;
              _priceController.text = formatNumber(pricePerUnit);
              // Llena la cantidad con el stock inicial registrado
              _quantityController.text = formatNumber(stock);
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final materials = ref
        .watch(materialProvider)
        .materials
        .where((m) => m.isActive)
        .toList();
    final units = ref.watch(unitProvider).units;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        top: AppSpacing.s24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agregar material',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Selector de material existente
            DropdownButtonFormField<int>(
              value: _selectedMaterialId,
              decoration: const InputDecoration(labelText: 'Material'),
              items: materials
                  .map(
                    (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                  )
                  .toList(),
              onChanged: (val) {
                final mat = materials.where((m) => m.id == val).firstOrNull;
                setState(() {
                  _selectedMaterialId = val;
                  _selectedMaterialName = mat?.name;
                  if (mat != null) {
                    _priceController.text = formatNumber(mat.pricePerUnit);
                  }
                });
              },
              validator: (v) => v == null ? 'Selecciona un material' : null,
            ),
            const SizedBox(height: AppSpacing.s8),

            // Botón crear nuevo material
            GestureDetector(
              onTap: _showCreateMaterialSheet,
              child: Row(
                children: [
                  const Icon(Icons.add, color: AppColors.primary, size: 14),
                  const SizedBox(width: AppSpacing.s4),
                  Text(
                    'Crear nuevo material',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Cantidad: unidades "por pieza" (botella, caja, unidad...) solo
            // aceptan enteros, porque a un proveedor se le compran piezas
            // completas, no fracciones.
            Builder(
              builder: (context) {
                final selectedMaterial = materials
                    .where((m) => m.id == _selectedMaterialId)
                    .firstOrNull;
                final selectedUnit = selectedMaterial != null
                    ? units
                          .where((u) => u.id == selectedMaterial.unitId)
                          .firstOrNull
                    : null;
                final discrete =
                    selectedUnit != null &&
                    isDiscreteUnit(selectedUnit.type, selectedUnit.name);
                final label = selectedUnit != null
                    ? 'Cantidad (${selectedUnit.name})'
                    : 'Cantidad';
                if (discrete) {
                  return WholeNumberQuantityField(
                    controller: _quantityController,
                    labelText: label,
                  );
                }
                return TextFormField(
                  controller: _quantityController,
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
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: '0',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo requerido';
                    final qty = double.tryParse(v);
                    if (qty == null || qty <= 0) return 'Cantidad inválida';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.s16),

            // Precio por unidad
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue;
                  if (newValue.text == '0') return newValue;
                  if (newValue.text.startsWith('0') &&
                      !newValue.text.startsWith('0.'))
                    return oldValue;
                  if (double.tryParse(newValue.text) == null &&
                      newValue.text != '.')
                    return oldValue;
                  return newValue;
                }),
              ],
              decoration: const InputDecoration(
                labelText: 'Precio por unidad (Bs.)',
                hintText: '0',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                final price = double.tryParse(v);
                if (price == null || price <= 0) return 'Precio inválido';
                return null;
              },
            ),
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
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      widget.onAdded({
                        'materialId': _selectedMaterialId,
                        'materialName': _selectedMaterialName,
                        'quantity': double.parse(
                          _quantityController.text.trim(),
                        ),
                        'unitPrice': double.parse(_priceController.text.trim()),
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Agregar',
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
    );
  }
}
