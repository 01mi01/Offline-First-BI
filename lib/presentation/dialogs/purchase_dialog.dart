import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/purchase_provider.dart';
import '../../application/supplier_provider.dart';
import '../../application/material_pricing.dart';
import '../../application/material_provider.dart';
import '../../application/unit_provider.dart';
import '../../models/material_model.dart';
import '../../models/purchase_model.dart';
import '../../models/unit_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/supplier_dialog.dart';
import '../dialogs/material_dialog.dart';
import '../widgets/unit_quantity_input.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../widgets/focus_utils.dart';
import '../widgets/searchable_picker.dart';
import '../../models/default_records.dart';

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
  // El total de una compra de materiales se calcula de sus ítems, pero se puede
  // escribir a mano: desde entonces manda lo escrito y deja de recalcularse. Es
  // solo el monto de la compra; el stock y el precio de cada material siguen
  // saliendo de los ítems.
  bool _totalOverridden = false;

  @override
  void initState() {
    super.initState();
    // Un aviso de "El total debe ser mayor a 0" desaparece al corregir el total.
    _totalController.addListener(_clearError);
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
        // Si el total guardado difiere de la suma de los ítems, fue editado a
        // mano: se respeta en vez de recalcularlo al abrir.
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

  // Recalcula el total a partir de los ítems de material
  void _recalcTotal() {
    if (!_isMaterial || _totalOverridden) return;
    final total = ref
        .read(purchaseRepositoryProvider)
        .calculateMaterialsTotal(_materialItems);
    _totalController.text = formatNumber(total);
  }

  // Formato del campo de total: solo dígitos y un punto decimal, sin ceros a la
  // izquierda ("05") ni signo negativo.
  static TextInputFormatter _amountFormatter() =>
      TextInputFormatter.withFunction((oldValue, newValue) {
        final text = newValue.text;
        if (text.isEmpty || text == '0') return newValue;
        if (!RegExp(r'^[0-9.]*$').hasMatch(text)) return oldValue;
        if (text.startsWith('0') && !text.startsWith('0.')) return oldValue;
        if (double.tryParse(text) == null && text != '.') return oldValue;
        return newValue;
      });

  // "2 metros", "1 paquete": cantidad con el nombre de su unidad concordado
  // (igual que en las tarjetas de producto y el registro de uso).
  String _quantityWithUnit(double quantity, String? unitName) {
    final number = formatNumber(quantity);
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
    // Sin proveedor elegido no se bloquea el formulario: el repositorio
    // asigna el proveedor por defecto "Sin proveedor".
    if (_isMaterial && _materialItems.isEmpty) {
      setState(() => _error = 'Agrega al menos un material');
      return;
    }

    var total = double.tryParse(_totalController.text.trim()) ?? 0;
    // Un total manual que se dejó vacío vuelve al calculado de los ítems.
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
    final allSuppliers = ref.watch(supplierProvider).suppliers;
    // El proveedor predeterminado se ofrece como la opción "Sin proveedor"
    // (valor nulo), no como un proveedor más; un proveedor inactivo solo
    // aparece si es el que ya tenía la compra que se edita.
    final suppliers = allSuppliers
        .where(
          (s) => !s.isDefault && (s.isActive || s.id == _selectedSupplierId),
        )
        .toList();
    // El valor del selector solo puede ser una opción que exista en la lista:
    // el proveedor predeterminado es la opción nula.
    final supplierValue = suppliers.any((s) => s.id == _selectedSupplierId)
        ? _selectedSupplierId
        : null;

    // Material por unidad: nombre de la unidad de cada material de la lista.
    final allMaterials = ref.watch(materialProvider).materials;
    final allUnits = ref.watch(unitProvider).units;
    String? unitNameOf(Object? materialId) {
      final material = allMaterials
          .where((m) => m.id == materialId)
          .firstOrNull;
      if (material == null) return null;
      return allUnits.where((u) => u.id == material.unitId).firstOrNull?.name;
    }

    // Con el teclado abierto cada píxel cuenta: los márgenes se reducen para
    // que el formulario que se desplaza tenga más alto. El título, el selector
    // y los botones siguen fijos.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final gapAfterTitle = keyboardOpen ? AppSpacing.s12 : AppSpacing.s24;
    final gapAfterSelector = keyboardOpen ? AppSpacing.s8 : AppSpacing.s16;

    // Altura fija (94 % de la pantalla): al cambiar entre "Materiales" y "Gasto
    // general" el contenido cambia de alto, pero la hoja no, así que el título y
    // el selector no se mueven. El formulario se desplaza dentro; los botones
    // quedan siempre a la vista.
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.94,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.s24,
          right: AppSpacing.s24,
          top: keyboardOpen ? AppSpacing.s16 : AppSpacing.s24,
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              (keyboardOpen ? AppSpacing.s12 : AppSpacing.s32),
        ),
        child: Form(
          key: _formKey,
          child: Column(
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
              SizedBox(height: gapAfterTitle),

              // Tipo de compra: dos opciones, cada una con su propio nombre
              // (no una etiqueta fija con un subtítulo que cambia).
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<bool>(value: true, label: Text('Materiales')),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Gasto general'),
                    ),
                  ],
                  selected: {_isMaterial},
                  onSelectionChanged: (selection) {
                    if (selection.first == _isMaterial) return;
                    setState(() {
                      _error = null;
                      _isMaterial = selection.first;
                      _totalOverridden = false;
                      // Cada modo empieza limpio: nada del otro modo queda
                      // oculto. Los campos de cada modo tienen su propia llave,
                      // así que nacen sin haber sido tocados (sin errores).
                      _materialItems.clear();
                      _totalController.clear();
                      _descriptionController.clear();
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.surface,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    side: WidgetStateProperty.resolveWith(
                      (states) => BorderSide(
                        color: states.contains(WidgetState.selected)
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: gapAfterSelector),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: AppSpacing.s4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de proveedor
                      Row(
                        children: [
                          Expanded(
                            // Búsqueda por nombre: escala a listas largas.
                            child: SearchablePickerField<int>(
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
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        value: _selectedLocationId,
                        decoration: const InputDecoration(
                          labelText: 'Ubicación',
                        ),
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
                        onChanged: (val) =>
                            setState(() => _selectedLocationId = val),
                      ),
                      const SizedBox(height: 20),

                      // Selector de evento
                      DropdownButtonFormField<int>(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        // Solo una opción existente puede ser el valor: mientras los eventos
                        // cargan (o si el evento ya no está disponible) el campo queda
                        // en "Sin evento" sin romper el selector.
                        value:
                            ref
                                .watch(eventProvider)
                                .events
                                .any(
                                  (e) =>
                                      e.id == _selectedEventId &&
                                      (e.isActive || e.id == _selectedEventId),
                                )
                            ? _selectedEventId
                            : null,
                        decoration: const InputDecoration(labelText: 'Evento'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Sin evento'),
                          ),
                          ...ref
                              .watch(eventProvider)
                              .events
                              .where(
                                (e) => e.isActive || e.id == _selectedEventId,
                              )
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.name),
                                ),
                              )
                              .toList(),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedEventId = val),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
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
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          )
                        else
                          ..._materialItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.s8,
                              ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['materialName'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.s4),
                                        // Edición inline de cantidad. Wrap: con nombres de
                                        // unidad largos la línea baja en vez de desbordar.
                                        Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                final current =
                                                    item['quantity'] as double;
                                                if (current <= 1) return;
                                                setState(() {
                                                  _error = null;
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
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: AppColors.border,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.remove,
                                                  size: 14,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.s10,
                                                  ),
                                              child: Text(
                                                _quantityWithUnit(
                                                  item['quantity'] as double,
                                                  unitNameOf(
                                                    item['materialId'],
                                                  ),
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                final current =
                                                    item['quantity'] as double;
                                                setState(() {
                                                  _error = null;
                                                  _materialItems[index]['quantity'] =
                                                      current + 1;
                                                  _recalcTotal();
                                                });
                                              },
                                              child: Container(
                                                width: 26,
                                                height: 26,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
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
                                            const SizedBox(
                                              width: AppSpacing.s8,
                                            ),
                                            Text(
                                              'Bs. ${((item['quantity'] as double) * (item['unitPrice'] as double)).toStringAsFixed(2)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
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
                                        _error = null;
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

                        // Total: se calcula de los materiales, pero se puede
                        // escribir a mano; lo escrito reemplaza al calculado.
                        TextFormField(
                          key: const ValueKey('purchase-total-materials'),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: _totalController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_amountFormatter()],
                          decoration: InputDecoration(
                            labelText: 'Total (Bs.)',
                            helperText: _totalOverridden
                                ? 'Total escrito a mano'
                                : 'Calculado de los materiales; puedes editarlo',
                            suffixIcon: _totalOverridden
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
                          ),
                          onChanged: (_) {
                            if (!_totalOverridden) {
                              setState(() => _totalOverridden = true);
                            }
                          },
                        ),
                      ] else ...[
                        // Gasto general
                        TextFormField(
                          key: const ValueKey('purchase-description'),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Descripción del gasto',
                            hintText:
                                'Ej: transporte, entradas a eventos, etc.',
                          ),
                          maxLines: 2,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        TextFormField(
                          key: const ValueKey('purchase-total-expense'),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: _totalController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_amountFormatter()],
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
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notas',
                          hintText: 'Observaciones opcionales',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

              // Error (fijo, junto a los botones: siempre visible)
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
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.s16),

              // Botones cancelar y registrar (fijos)
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
                        // Menos relleno lateral: "Registrar compra" cabe en una
                        // sola línea dentro de medio ancho.
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8,
                        ),
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
                          : FittedBox(
                              // Si aun así no cupiera (fuente grande), se
                              // reduce en vez de partirse en dos líneas.
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isEditing ? 'Guardar' : 'Registrar compra',
                                maxLines: 1,
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
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
  String? _materialError;
  // Materiales tipo contenedor: la cantidad se elige con fracciones (media
  // botella) y el campo de precio es el TOTAL pagado por esa cantidad.
  double _fractionQuantity = 0;
  String? _quantityError;
  // Si la persona ya escribió el total, no se le vuelve a sugerir uno.
  bool _totalEdited = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
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

  // Sugiere el total (precio actual por unidad entera x cantidad) mientras la
  // persona no haya escrito el suyo; ella puede cambiarlo por lo que pagó.
  void _suggestTotal(MaterialModel? material) {
    if (_totalEdited || material == null) return;
    _priceController.text = _fractionQuantity > 0
        ? formatNumber(
            totalForQuantity(
              pricePerUnit: material.pricePerUnit,
              quantity: _fractionQuantity,
            ),
          )
        : '';
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
              _fractionQuantity = 0;
              _quantityError = null;
              _totalEdited = false;
              // Tipo contenedor: el campo es el total pagado, no el precio
              // por unidad entera.
              _priceController.text = _isContainer(materialId)
                  ? ''
                  : formatNumber(pricePerUnit);
              // La cantidad NO se rellena con el stock del material: ese stock
              // inicial ya quedó registrado como su propia compra al crearlo.
              // Aquí se escribe lo que se compra en esta ocasión, que se suma
              // al stock existente.
              _quantityController.clear();
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
            // Búsqueda por nombre: escala a listas largas.
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
                  _materialError = null;
                  _fractionQuantity = 0;
                  _quantityError = null;
                  _totalEdited = false;
                  if (mat != null) {
                    // Tipo contenedor: se pide el total pagado (se sugiere al
                    // elegir la cantidad); si no, el precio por unidad.
                    _priceController.text = _isContainer(val)
                        ? ''
                        : formatNumber(mat.pricePerUnit);
                  }
                });
              },
            ),
            if (_materialError != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.s16,
                  top: AppSpacing.s4,
                ),
                child: Text(
                  _materialError!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
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

            // Cantidad: unidades "por pieza" (contenedor, paquete, unidad...) solo
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
                // Contenedores: se puede comprar media botella, un cuarto...
                if (selectedUnit != null &&
                    isFractionFriendlyUnitType(selectedUnit.type)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionQuantityPicker(
                        unit: selectedUnit.name,
                        value: _fractionQuantity,
                        onChanged: (v) => setState(() {
                          _fractionQuantity = v;
                          _quantityError = null;
                          _suggestTotal(selectedMaterial);
                        }),
                      ),
                      if (_quantityError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s4),
                          child: Text(
                            _quantityError!,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.error),
                          ),
                        ),
                    ],
                  );
                }
                if (discrete) {
                  return WholeNumberQuantityField(
                    controller: _quantityController,
                    labelText: label,
                  );
                }
                return TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
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
                  decoration: InputDecoration(labelText: label, hintText: '0'),
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

            // Contenedores: total pagado por la cantidad (de ahí sale el precio
            // por unidad entera). Resto de unidades: precio por unidad.
            Builder(
              builder: (context) {
                final selectedMaterial = materials
                    .where((m) => m.id == _selectedMaterialId)
                    .firstOrNull;
                final unit = selectedMaterial == null
                    ? null
                    : units
                          .where((u) => u.id == selectedMaterial.unitId)
                          .firstOrNull;
                final paysTotal =
                    unit != null && isFractionFriendlyUnitType(unit.type);
                final entered =
                    double.tryParse(_priceController.text.trim()) ?? 0;
                final computed = paysTotal
                    ? pricePerWholeUnit(
                        totalPaid: entered,
                        quantity: _fractionQuantity,
                      )
                    : null;
                return TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _priceController,
                  keyboardType: TextInputType.number,
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
                  onChanged: (_) => setState(() => _totalEdited = true),
                  decoration: InputDecoration(
                    labelText: paysTotal
                        ? 'Total pagado (Bs.)'
                        : 'Precio por unidad (Bs.)',
                    hintText: '0',
                    helperText: paysTotal
                        ? (computed != null
                              ? 'Precio de 1 ${unit.name}: Bs. ${computed.toStringAsFixed(2)}'
                              : 'Se calcula el precio de 1 ${unit.name}')
                        : null,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo requerido';
                    final price = double.tryParse(v);
                    if (price == null || price <= 0) return 'Precio inválido';
                    return null;
                  },
                );
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
                      final valid = _formKey.currentState!.validate();
                      // El selector con búsqueda no es un campo de formulario:
                      // se valida aparte.
                      if (_selectedMaterialId == null) {
                        setState(
                          () => _materialError = 'Selecciona un material',
                        );
                        return;
                      }
                      final container = _isContainer(_selectedMaterialId);
                      if (container && _fractionQuantity <= 0) {
                        setState(
                          () => _quantityError = 'Selecciona una cantidad',
                        );
                        return;
                      }
                      if (!valid) return;
                      final entered = double.parse(_priceController.text.trim());
                      final quantity = container
                          ? _fractionQuantity
                          : double.parse(_quantityController.text.trim());
                      // Contenedores: lo escrito es el total pagado; el precio
                      // por unidad entera se calcula dividiendo por la cantidad.
                      final unitPrice = container
                          ? (pricePerWholeUnit(
                                  totalPaid: entered,
                                  quantity: quantity,
                                ) ??
                                entered)
                          : entered;
                      widget.onAdded({
                        'materialId': _selectedMaterialId,
                        'materialName': _selectedMaterialName,
                        'quantity': quantity,
                        'unitPrice': unitPrice,
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
