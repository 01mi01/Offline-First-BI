import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sale_provider.dart';
import '../../application/client_provider.dart';
import '../../application/product_provider.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../../models/sale_model.dart';
import '../../theme/app_theme.dart';
import 'client_dialog.dart';

class SaleDialog extends ConsumerStatefulWidget {
  final SaleModel? sale;

  const SaleDialog({super.key, this.sale});

  @override
  ConsumerState<SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends ConsumerState<SaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _discountController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedClientId;
  // Mapa de productId -> cantidad
  final Map<int, int> _cartItems = {};
  bool _isLoading = false;
  int? _selectedLocationId;
  int? _selectedEventId;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.sale != null) {
      _selectedClientId = widget.sale!.clientId;
      _discountController.text = widget.sale!.discount > 0
          ? formatNumber(widget.sale!.discount)
          : '';
      _notesController.text = widget.sale!.notes ?? '';
      _loadExistingItems();
      _selectedLocationId = widget.sale?.locationId;
      _selectedEventId = widget.sale?.eventId;
    }
    if (widget.sale == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sinNombre = ref
            .read(clientProvider)
            .clients
            .where((c) => c.name == 'Sin nombre')
            .firstOrNull;
        if (sinNombre != null && mounted) {
          setState(() => _selectedClientId = sinNombre.id);
        }
      });
    }
  }

  // Carga los ítems de una venta existente al editar
  Future<void> _loadExistingItems() async {
    final items = await ref
        .read(saleProvider.notifier)
        .getItemsForSale(widget.sale!.id);
    if (mounted) {
      setState(() {
        for (final item in items) {
          _cartItems[item.productId] = item.quantity;
        }
      });
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal {
    final products = ref.read(productProvider).products;
    double total = 0;
    for (final entry in _cartItems.entries) {
      final product = products.where((p) => p.id == entry.key).firstOrNull;
      if (product != null) total += product.salePrice * entry.value;
    }
    return total;
  }

  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0;

  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  void _showAddClientSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ClientDialog(
        onSaved: (clientId) {
          setState(() => _selectedClientId = clientId);
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClientId == null) {
      setState(() => _error = 'Selecciona un cliente');
      return;
    }
    if (_cartItems.isEmpty) {
      setState(() => _error = 'Agrega al menos un producto');
      return;
    }

    final discount = _discount;
    if (discount > _subtotal) {
      setState(() => _error = 'El descuento no puede ser mayor al subtotal');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final products = ref.read(productProvider).products;
    final items = <Map<String, dynamic>>[];

    for (final entry in _cartItems.entries) {
      final product = products.where((p) => p.id == entry.key).firstOrNull;
      if (product != null) {
        // Valida stock disponible
        final availableStock = widget.sale != null
            ? product.stock + (await _getOriginalQuantity(entry.key))
            : product.stock;

        if (entry.value > availableStock) {
          setState(() {
            _isLoading = false;
            _error =
                'Stock insuficiente para ${product.name}. Disponible: $availableStock';
          });
          return;
        }

        items.add({
          'productId': product.id,
          'quantity': entry.value,
          'unitPrice': product.salePrice,
        });
      }
    }

    String? error;
    if (widget.sale == null) {
      error = await ref
          .read(saleProvider.notifier)
          .createSale(
            clientId: _selectedClientId,
            locationId: _selectedLocationId,
            eventId: _selectedEventId,
            totalAmount: _subtotal,
            discount: discount,
            finalAmount: _total,
            date: DateTime.now(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            items: items,
          );
    } else {
      error = await ref
          .read(saleProvider.notifier)
          .editSale(
            saleId: widget.sale!.id,
            clientId: _selectedClientId,
            locationId: _selectedLocationId,
            eventId: _selectedEventId,
            totalAmount: _subtotal,
            discount: discount,
            finalAmount: _total,
            date: widget.sale!.date,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            newItems: items,
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

  // Obtiene la cantidad original de un producto en la venta que se está editando
  Future<int> _getOriginalQuantity(int productId) async {
    if (widget.sale == null) return 0;
    final items = await ref
        .read(saleProvider.notifier)
        .getItemsForSale(widget.sale!.id);
    return items
            .where((i) => i.productId == productId)
            .map((i) => i.quantity)
            .firstOrNull ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.sale != null;
    final clients = ref
        .watch(clientProvider)
        .clients
        .where((c) => c.isActive)
        .toList();
    final products = ref
        .watch(productProvider)
        .products
        .where((p) => p.isActive)
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
                isEditing ? 'Editar venta' : 'Nueva venta',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Selector de cliente con opción de crear nuevo
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedClientId,
                      decoration: const InputDecoration(labelText: 'Cliente'),
                      items: clients
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedClientId = val),
                      validator: (v) =>
                          v == null ? 'Selecciona un cliente' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón para agregar nuevo cliente
                  GestureDetector(
                    onTap: _showAddClientSheet,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add_outlined,
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
              const SizedBox(height: 16),

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
              const SizedBox(height: 20),

              // Lista de productos activos para agregar
              const Text(
                'Productos',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  physics: const AlwaysScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final inCart = _cartItems.containsKey(p.id);
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Bs. ${p.salePrice.toStringAsFixed(2)}  •  Stock: ${p.stock}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (inCart) {
                              _cartItems.remove(p.id);
                            } else {
                              _cartItems[p.id] = 1;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: inCart
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: inCart
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Icon(
                            inCart ? Icons.check : Icons.add,
                            size: 18,
                            color: inCart
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Carrito con cantidades
              if (_cartItems.isNotEmpty) ...[
                const Text(
                  'Carrito',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ..._cartItems.entries.map((entry) {
                  final product = products
                      .where((p) => p.id == entry.key)
                      .firstOrNull;
                  if (product == null) return const SizedBox();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
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
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Bs. ${(product.salePrice * entry.value).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Control de cantidad
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (entry.value <= 1) {
                                    _cartItems.remove(entry.key);
                                  } else {
                                    _cartItems[entry.key] = entry.value - 1;
                                  }
                                });
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
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
                                '${entry.value}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                final product = products
                                    .where((p) => p.id == entry.key)
                                    .firstOrNull;
                                if (product == null) return;
                                if (entry.value >= product.stock) return;
                                setState(() {
                                  _cartItems[entry.key] = entry.value + 1;
                                });
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],

              // Descuento
              TextFormField(
                controller: _discountController,
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
                  labelText: 'Descuento (Bs.)',
                  hintText: '0',
                ),
                onChanged: (_) => setState(() {}),
              ),
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
              const SizedBox(height: 16),

              // Resumen de totales
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _TotalRow(
                      label: 'Subtotal',
                      value: 'Bs. ${_subtotal.toStringAsFixed(2)}',
                    ),
                    if (_discount > 0) ...[
                      const SizedBox(height: 6),
                      _TotalRow(
                        label: 'Descuento',
                        value: '- Bs. ${_discount.toStringAsFixed(2)}',
                        valueColor: AppColors.error,
                      ),
                    ],
                    const Divider(color: AppColors.border, height: 20),
                    _TotalRow(
                      label: 'Total',
                      value: 'Bs. ${_total.toStringAsFixed(2)}',
                      bold: true,
                      valueColor: AppColors.primary,
                    ),
                  ],
                ),
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
                              isEditing ? 'Guardar' : 'Registrar venta',
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

// Fila de total reutilizable
class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
