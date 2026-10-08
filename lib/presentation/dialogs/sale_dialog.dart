import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sale_provider.dart';
import '../../application/location_options.dart';
import '../../application/search_filter.dart';
import '../widgets/catalog_filter_bar.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/transaction_date_field.dart';
import '../../application/client_provider.dart';
import '../../application/product_provider.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../theme/app_theme.dart';
import 'client_dialog.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/focus_utils.dart';
import '../../models/default_records.dart';
import '../../config/app_clock.dart';
import '../../config/rounding.dart';

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
  // Texto del buscador de la lista de productos.
  String _productQuery = '';

  int? _selectedClientId;
  // Mapa de productId -> cantidad
  final Map<int, int> _cartItems = {};
  // Mapa de productId -> banda de precio elegida ('A' o 'B')
  final Map<int, String> _cartPriceTypes = {};
  // Al editar: unidades de cada producto que ESTA venta ya tiene apartadas
  // del inventario (productId -> cantidad). Vuelven al stock al guardar, así
  // que cuentan como disponibles.
  final Map<int, int> _reservedByThisSale = {};
  bool _isLoading = false;
  int? _selectedLocationId;
  int? _selectedEventId;
  String? _error;
  // Fecha de la venta: hoy por defecto, pero se puede registrar una pasada o
  // futura. Si no se toca, una venta nueva toma el momento de guardarla.
  late DateTime _date = widget.sale?.date ?? appNow();
  bool _dateChanged = false;

  @override
  void initState() {
    super.initState();
    if (widget.sale != null) {
      _selectedClientId = widget.sale!.clientId;
      _discountController.text = widget.sale!.discount > 0
          ? fixed2(widget.sale!.discount)
          : '';
      _notesController.text = widget.sale!.notes ?? '';
      _loadExistingItems();
      _selectedLocationId = widget.sale?.locationId;
      _selectedEventId = widget.sale?.eventId;
    }
  }

  // Carga los ítems de una venta existente al editar
  Future<void> _loadExistingItems() async {
    final items = await ref
        .read(saleProvider.notifier)
        .getItemsForSale(widget.sale!.id);
    final reserved = await ref
        .read(saleProvider.notifier)
        .getReservedQuantities(widget.sale!.id);
    if (mounted) {
      setState(() {
        _reservedByThisSale
          ..clear()
          ..addAll(reserved);
        for (final item in items) {
          _cartItems[item.productId] = item.quantity;
          _cartPriceTypes[item.productId] = item.priceType;
        }
      });
    }
  }

  // Stock que se puede ofrecer de un producto: el actual más lo que esta
  // venta (si se está editando) ya tiene apartado.
  int _availableStock(ProductModel product) {
    return ref
        .read(saleRepositoryProvider)
        .availableStock(
          currentStock: product.stock,
          reservedByThisSale: _reservedByThisSale[product.id] ?? 0,
        );
  }

  @override
  void dispose() {
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal {
    final products = ref.read(productProvider).products;
    return ref
        .read(saleRepositoryProvider)
        .calculateSubtotal(products, _cartItems, priceTypes: _cartPriceTypes);
  }

  // Lo que se escribe con más de dos decimales se redondea a centavos.
  double get _discount =>
      round2(double.tryParse(_discountController.text.trim()) ?? 0);

  double get _total =>
      ref.read(saleRepositoryProvider).calculateTotal(_subtotal, _discount);

  void _showAddClientSheet() {
    dismissKeyboard();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
    // Sin cliente elegido no se bloquea la venta: el repositorio la guarda a
    // nombre del cliente predeterminado ("Sin nombre").
    if (_cartItems.isEmpty) {
      setState(() => _error = 'Agrega al menos un producto');
      return;
    }

    final discount = _discount;
    final discountError = ref
        .read(saleRepositoryProvider)
        .validateDiscount(discount, _subtotal);
    if (discountError != null) {
      setState(() => _error = discountError);
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
        final availableStock = _availableStock(product);

        if (entry.value > availableStock) {
          setState(() {
            _isLoading = false;
            _error =
                'Stock insuficiente para ${product.name}. Disponible: $availableStock';
          });
          return;
        }

        final priceType = _cartPriceTypes[entry.key] ?? 'A';
        final unitPrice = priceType == 'B' ? product.priceB : product.priceA;
        items.add({
          'productId': product.id,
          'quantity': entry.value,
          'unitPrice': unitPrice,
          'priceType': priceType,
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
            date: _dateChanged ? _date : appNow(),
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
            date: _date,
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

  // Cancela la venta (no la borra): devuelve el stock y la deja en el historial
  // marcada como cancelada. Solo se ofrece dentro de este formulario de edición.
  Future<void> _cancelSale() async {
    final confirmed = await confirmCancellation(
      context,
      title: '¿Cancelar venta?',
      message:
          'Se devolverá al inventario lo vendido. La venta seguirá en la '
          'lista, marcada como cancelada, y ya no se podrá editar.',
      confirmLabel: 'Cancelar venta',
    );
    if (!confirmed || !mounted) return;
    final error = await ref
        .read(saleProvider.notifier)
        .cancelSale(widget.sale!.id);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.sale != null;
    final allClients = ref.watch(clientProvider).clients;
    // El cliente predeterminado se ofrece como la opción "Sin nombre" (valor
    // nulo), no como un cliente más; un cliente inactivo solo aparece si es el
    // que ya tenía la venta que se edita.
    final clients = allClients
        .where((c) => !c.isDefault && (c.isActive || c.id == _selectedClientId))
        .toList();
    // El valor del selector solo puede ser una opción que exista en la lista:
    // el cliente predeterminado es la opción nula, y mientras los clientes
    // cargan tampoco hay nada que mostrar todavía.
    final clientValue = clients.any((c) => c.id == _selectedClientId)
        ? _selectedClientId
        : null;
    final products = ref
        .watch(productProvider)
        .products
        .where((p) => p.isActive)
        .toList();
    // Lo que se ve en la lista de productos: filtrada por lo que se escribe en
    // el buscador (el carrito sigue usando la lista completa).
    // Sin texto no se muestra la lista (puede ser larguísima): hay que escribir.
    final searchingProducts = _productQuery.trim().isNotEmpty;
    final visibleProducts = searchingProducts
        ? filterByQuery<ProductModel>(products, _productQuery, (p) => p.name)
        : const <ProductModel>[];

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
            // Título (fijo)
            Text(
              isEditing ? 'Editar venta' : 'Nueva venta',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // El formulario se desplaza; los botones van al final del contenido.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: AppSpacing.s4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de cliente con opción de crear nuevo
                    // Búsqueda por nombre: escala a listas largas. El botón va en
                    // la fila del campo: los resultados se abren debajo.
                    SearchablePickerField<int>(
                      label: 'Cliente',
                      searchHint: 'Buscar cliente',
                      value: clientValue,
                      options: [
                        const PickerOption<int>(null, DefaultRecords.client),
                        for (final c in clients) PickerOption<int>(c.id, c.name),
                      ],
                      onChanged: (val) => setState(() {
                        _selectedClientId = val;
                        _error = null;
                      }),
                      // Botón para agregar nuevo cliente
                      trailing: GestureDetector(
                        onTap: _showAddClientSheet,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s12),
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
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // Selector de ubicación (búsqueda en línea, como el de producto)
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
                      onChanged: (val) => setState(() => _selectedLocationId = val),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Selector de evento (búsqueda en línea, como el de producto)
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
                      onChanged: (val) => setState(() => _selectedEventId = val),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Fecha de la venta (sin límite: pasada, hoy o futura)
                    TransactionDateField(
                      date: _date,
                      onChanged: (value) => setState(() {
                        _date = value;
                        _dateChanged = true;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // Lista de productos activos para agregar
                    Text(
                      'Productos',
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    // Buscador de productos por nombre.
                    // Buscador + resultados: al enfocar el buscador se lleva arriba
                    // del área que se desplaza, para ver lo escrito y los
                    // resultados por encima del teclado.
                    RevealOnFocus(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CatalogSearchField(
                            initialText: _productQuery,
                            hintText: 'Buscar producto',
                            onChanged: (value) =>
                                setState(() => _productQuery = value),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          // Alto fijo: al escribir, la lista no cambia de tamaño y
                          // el buscador de arriba no se mueve.
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: visibleProducts.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(AppSpacing.s16),
                                    child: Center(
                                      child: Text(
                                        searchingProducts
                                            ? 'Sin resultados'
                                            : 'Escribe para buscar un producto',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.s8),
                              physics: const AlwaysScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: visibleProducts.length,
                              itemBuilder: (context, index) {
                                final p = visibleProducts[index];
                                final inCart = _cartItems.containsKey(p.id);
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s12,
                                  ),
                                  title: Text(
                                    p.name,
                                    style: Theme.of(context).textTheme.labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                  subtitle: Text(
                                    'A: Bs. ${p.priceA.toStringAsFixed(2)}  •  B: Bs. ${p.priceB.toStringAsFixed(2)}  •  Stock: ${_availableStock(p)}',
                                    style: Theme.of(context).textTheme.labelMedium
                                        ?.copyWith(color: AppColors.textSecondary),
                                  ),
                                  trailing: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _error = null;
                                        if (inCart) {
                                          _cartItems.remove(p.id);
                                          _cartPriceTypes.remove(p.id);
                                        } else {
                                          _cartItems[p.id] = 1;
                                          _cartPriceTypes[p.id] = 'A';
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(AppSpacing.s4),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Carrito con cantidades
                    if (_cartItems.isNotEmpty) ...[
                      Text(
                        'Carrito',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      ..._cartItems.entries.map((entry) {
                        final product = products
                            .where((p) => p.id == entry.key)
                            .firstOrNull;
                        if (product == null) return const SizedBox();
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s16,
                            vertical: AppSpacing.s10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                        ),
                                        Text(
                                          'Bs. ${fixed2((_cartPriceTypes[entry.key] == 'B' ? product.priceB : product.priceA) * entry.value)}',
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
                                  ),
                                  // Control de cantidad
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _error = null;
                                            if (entry.value <= 1) {
                                              _cartItems.remove(entry.key);
                                            } else {
                                              _cartItems[entry.key] =
                                                  entry.value - 1;
                                            }
                                          });
                                        },
                                        child: Container(
                                          width: AppSpacing.s28,
                                          height: AppSpacing.s28,
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius: BorderRadius.circular(
                                              8,
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
                                          '${entry.value}',
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
                                          final product = products
                                              .where((p) => p.id == entry.key)
                                              .firstOrNull;
                                          if (product == null) return;
                                          if (entry.value >=
                                              _availableStock(product))
                                            return;
                                          setState(() {
                                            _error = null;
                                            _cartItems[entry.key] =
                                                entry.value + 1;
                                          });
                                        },
                                        child: Container(
                                          width: AppSpacing.s28,
                                          height: AppSpacing.s28,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
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
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.s8),
                              _PriceTypeToggle(
                                selected: _cartPriceTypes[entry.key] ?? 'A',
                                onChanged: (type) => setState(() {
                                  _error = null;
                                  _cartPriceTypes[entry.key] = type;
                                }),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.s16),
                    ],

                    // Descuento
                    TextFormField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        // Un descuento es cero o positivo: no admite signo
                        // negativo (ni al escribir ni al pegar) ni letras.
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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
                      validator: (v) => ref
                          .read(saleRepositoryProvider)
                          .validateDiscount(
                            double.tryParse((v ?? '').trim()) ?? 0,
                            double.infinity,
                          ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
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
                    const SizedBox(height: AppSpacing.s16),

                    // Resumen de totales
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s16),
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
                          // Siempre visible, para que el desglose sea claro:
                          // Subtotal - Descuento = Total.
                          const SizedBox(height: AppSpacing.s6),
                          _TotalRow(
                            label: 'Descuento',
                            value: _discount > 0
                                ? '- Bs. ${_discount.toStringAsFixed(2)}'
                                : 'Bs. 0.00',
                            valueColor: _discount > 0
                                ? AppColors.error
                                : null,
                          ),
                          const Divider(
                            color: AppColors.border,
                            height: AppSpacing.s20,
                          ),
                          _TotalRow(
                            label: 'Total',
                            value: 'Bs. ${_total.toStringAsFixed(2)}',
                            bold: true,
                            valueColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Error al guardar (junto a los botones, al final)
                    if (_error != null) ...[
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
                      const SizedBox(height: AppSpacing.s12),
                    ],

                    // Botones cancelar y registrar (al final del contenido)
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
                                    isEditing ? 'Guardar' : 'Registrar venta',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                        ),
                      ],
                    ),

                    // Cancelar la venta: solo al editar una existente, al final
                    // del formulario.
                    if (isEditing && !widget.sale!.isCanceled) ...[
                      const SizedBox(height: AppSpacing.s12),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _cancelSale,
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: AppColors.error,
                          size: 20,
                        ),
                        label: const Text(
                          'Cancelar venta',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
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
}

// Selector de banda de precio (A/B) para un ítem del carrito
class _PriceTypeToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PriceTypeToggle({required this.selected, required this.onChanged});

  Widget _segment(String value, String label) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segment('A', 'Precio A'),
        const SizedBox(width: AppSpacing.s6),
        _segment('B', 'Precio B'),
      ],
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
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: (bold ? textTheme.headlineLarge : textTheme.labelLarge)
              ?.copyWith(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: bold
              ? const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ).copyWith(color: valueColor ?? AppColors.textPrimary)
              : textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                ),
        ),
      ],
    );
  }
}
