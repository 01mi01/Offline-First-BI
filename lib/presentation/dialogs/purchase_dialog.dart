import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/purchase_provider.dart';
import '../../application/supplier_provider.dart';
import '../../application/material_provider.dart';
import '../../models/purchase_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/supplier_dialog.dart';
import '../dialogs/material_dialog.dart';
import '../../application/location_provider.dart';

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
      _descriptionController.text = widget.purchase!.description ?? '';
      _totalController.text = widget.purchase!.totalAmount > 0
          ? formatNumber(widget.purchase!.totalAmount)
          : '';
      _notesController.text = widget.purchase!.notes ?? '';
      _loadExistingItems();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sinProveedor = ref
            .read(supplierProvider)
            .suppliers
            .where((s) => s.name == 'Sin proveedor')
            .firstOrNull;
        if (sinProveedor != null && mounted) {
          setState(() => _selectedSupplierId = sinProveedor.id);
        }
      });
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
    double total = 0;
    for (final item in _materialItems) {
      total += (item['quantity'] as double) * (item['unitPrice'] as double);
    }
    _totalController.text = formatNumber(total);
  }

  void _showAddSupplierSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SupplierDialog(
        onSaved: (supplierId) {
          setState(() => _selectedSupplierId = supplierId);
        },
      ),
    );
  }

  void _showAddMaterialItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
    if (_selectedSupplierId == null) {
      setState(() => _error = 'Selecciona un proveedor');
      return;
    }
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
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Toggle material / gasto general
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
              const SizedBox(height: 20),

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
                      onChanged: (val) =>
                          setState(() => _selectedSupplierId = val),
                      validator: (v) =>
                          v == null ? 'Selecciona un proveedor' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showAddSupplierSheet,
                    child: Container(
                      padding: const EdgeInsets.all(12),
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
              const SizedBox(height: 20),
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
              // Sección de materiales
              if (_isMaterial) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Materiales',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showAddMaterialItem,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
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
                            const SizedBox(width: 4),
                            Text(
                              'Agregar',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_materialItems.isEmpty)
                  Text(
                    'Sin materiales agregados',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  )
                else
                  ..._materialItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
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
                                const SizedBox(height: 4),
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
                                        horizontal: 10,
                                      ),
                                      child: Text(
                                        formatNumber(
                                          item['quantity'] as double,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
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
                                    const SizedBox(width: 8),
                                    Text(
                                      'Bs. ${((item['quantity'] as double) * (item['unitPrice'] as double)).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
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
                const SizedBox(height: 16),

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
                const SizedBox(height: 16),
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
              const SizedBox(height: 16),

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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        alignment: Alignment.center,
                      ),
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.surface,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditing ? 'Guardar' : 'Registrar compra',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agregar material',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

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
            const SizedBox(height: 8),

            // Botón crear nuevo material
            GestureDetector(
              onTap: _showCreateMaterialSheet,
              child: Row(
                children: [
                  const Icon(Icons.add, color: AppColors.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Crear nuevo material',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cantidad
            TextFormField(
              controller: _quantityController,
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
                labelText: 'Cantidad',
                hintText: '0',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                final qty = double.tryParse(v);
                if (qty == null || qty <= 0) return 'Cantidad inválida';
                return null;
              },
            ),
            const SizedBox(height: 16),

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
                    child: const Text(
                      'Agregar',
                      style: TextStyle(
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
    );
  }
}
