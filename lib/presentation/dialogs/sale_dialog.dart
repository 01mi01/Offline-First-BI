import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sale_provider.dart';
import '../../application/location_options.dart';
import '../../application/search_filter.dart';
import '../widgets/catalog_filter_bar.dart' show RevealOnFocus;
import '../widgets/searchable_picker.dart' show PickerOption;
import '../../application/client_provider.dart';
import '../../application/product_provider.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../theme/app_theme.dart';
import 'client_dialog.dart';
import '../widgets/focus_utils.dart';
import '../widgets/ios_controls.dart';
import '../widgets/ios_group.dart';
import '../widgets/ios_sheet.dart';
import '../widgets/ios_style.dart';
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
  String _productQuery = '';

  int? _selectedClientId;
  final Map<int, int> _cartItems = {};
  final Map<int, String> _cartPriceTypes = {};
  // Al editar: unidades que esta venta ya tiene apartadas; vuelven al stock al guardar.
  final Map<int, int> _reservedByThisSale = {};
  bool _isLoading = false;
  int? _selectedLocationId;
  int? _selectedEventId;
  String? _error;
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

  // Cancelar no borra: devuelve el stock y deja la venta marcada como cancelada.
  Future<void> _cancelSale() async {
    final confirmed = await showIosConfirm(
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
    final clients = allClients
        .where((c) => !c.isDefault && (c.isActive || c.id == _selectedClientId))
        .toList();
    final clientValue = clients.any((c) => c.id == _selectedClientId)
        ? _selectedClientId
        : null;
    final products = ref
        .watch(productProvider)
        .products
        .where((p) => p.isActive)
        .toList();
    final searchingProducts = _productQuery.trim().isNotEmpty;
    final visibleProducts = searchingProducts
        ? filterByQuery<ProductModel>(products, _productQuery, (p) => p.name)
        : const <ProductModel>[];

    return IosSheetScaffold(
      title: isEditing ? 'Editar venta' : 'Nueva venta',
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
                    action: IconButton(
                      tooltip: 'Nuevo cliente',
                      icon: const Icon(
                        Icons.person_add_outlined,
                        size: 22,
                        color: AppColors.primaryDark,
                      ),
                      onPressed: _showAddClientSheet,
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
                    onChanged: (val) => setState(() => _selectedEventId = val),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s32,
                  0,
                  AppSpacing.s16,
                  AppSpacing.s6,
                ),
                child: Text('Productos', style: IosText.header(context)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  0,
                  AppSpacing.s16,
                  AppSpacing.s24,
                ),
                child: RevealOnFocus(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IosSearchBar(
                        initialText: _productQuery,
                        hintText: 'Buscar producto',
                        onChanged: (value) =>
                            setState(() => _productQuery = value),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      // Alto fijo: al escribir, el buscador de arriba no se mueve.
                      Container(
                        height: 200,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppIos.groupRadius,
                          ),
                        ),
                        child: visibleProducts.isEmpty
                            ? Center(
                                child: Text(
                                  searchingProducts
                                      ? 'Sin resultados'
                                      : 'Escribe para buscar un producto',
                                  style: IosText.rowSubtitle(context),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: visibleProducts.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: AppIos.dividerIndent,
                                  color: AppColors.iosSeparator,
                                ),
                                itemBuilder: (context, index) {
                                  final p = visibleProducts[index];
                                  final inCart = _cartItems.containsKey(p.id);
                                  return IosRow(
                                    title: p.name,
                                    subtitle: Text(
                                      'A: Bs. ${fixed2(p.priceA)}  •  B: Bs. ${fixed2(p.priceB)}  •  Stock: ${_availableStock(p)}',
                                      style: IosText.rowSubtitle(context),
                                    ),
                                    trailing: Icon(
                                      inCart
                                          ? Icons.check_circle
                                          : Icons.add_circle_outline,
                                      color: inCart
                                          ? AppColors.primaryDark
                                          : AppColors.iosChevron,
                                    ),
                                    onTap: () => setState(() {
                                      _error = null;
                                      if (inCart) {
                                        _cartItems.remove(p.id);
                                        _cartPriceTypes.remove(p.id);
                                      } else {
                                        _cartItems[p.id] = 1;
                                        _cartPriceTypes[p.id] = 'A';
                                      }
                                    }),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_cartItems.isNotEmpty)
                IosSection(
                  header: 'Carrito',
                  children: [
                    for (final entry in _cartItems.entries)
                      _cartRow(context, entry, products),
                  ],
                ),
              IosSection(
                children: [
                  IosTextFieldRow(
                    label: 'Descuento (Bs.)',
                    controller: _discountController,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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
                    validator: (v) => ref
                        .read(saleRepositoryProvider)
                        .validateDiscount(
                          double.tryParse((v ?? '').trim()) ?? 0,
                          double.infinity,
                        ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  IosTextAreaRow(
                    label: 'Notas',
                    controller: _notesController,
                    hint: 'Observaciones opcionales',
                  ),
                ],
              ),
              IosSection(
                children: [
                  IosValueRow(
                    label: 'Subtotal',
                    value: 'Bs. ${fixed2(_subtotal)}',
                  ),
                  IosValueRow(
                    label: 'Descuento',
                    value: _discount > 0
                        ? '- Bs. ${fixed2(_discount)}'
                        : 'Bs. 0.00',
                    valueColor: _discount > 0 ? AppColors.error : null,
                  ),
                  IosValueRow(
                    label: 'Total',
                    value: 'Bs. ${fixed2(_total)}',
                    bold: true,
                    valueColor: AppColors.textPrimary,
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
                          isEditing ? 'Guardar' : 'Registrar venta',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textButtons,
                              ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
              if (isEditing && !widget.sale!.isCanceled)
                IosDestructiveGroup(
                  label: 'Cancelar venta',
                  onTap: _isLoading ? null : _cancelSale,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartRow(
    BuildContext context,
    MapEntry<int, int> entry,
    List<ProductModel> products,
  ) {
    final product = products.where((p) => p.id == entry.key).firstOrNull;
    if (product == null) return const SizedBox();
    final priceType = _cartPriceTypes[entry.key] ?? 'A';
    final linePrice = (priceType == 'B' ? product.priceB : product.priceA);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s4,
        AppSpacing.s8,
        AppSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: IosText.rowTitle(context)),
                    Text(
                      'Bs. ${fixed2(linePrice * entry.value)}',
                      style: IosText.rowSubtitle(
                        context,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${entry.value}',
                style: IosText.rowTitle(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              IosStepper(
                onMinus: () => setState(() {
                  _error = null;
                  if (entry.value <= 1) {
                    _cartItems.remove(entry.key);
                  } else {
                    _cartItems[entry.key] = entry.value - 1;
                  }
                }),
                onPlus: entry.value >= _availableStock(product)
                    ? null
                    : () => setState(() {
                        _error = null;
                        _cartItems[entry.key] = entry.value + 1;
                      }),
              ),
            ],
          ),
          SizedBox(
            width: 220,
            child: IosSegmented<String>(
              segments: const [
                IosSegment('A', 'Precio A'),
                IosSegment('B', 'Precio B'),
              ],
              selected: priceType,
              onChanged: (type) {
                if (type == null) return;
                setState(() {
                  _error = null;
                  _cartPriceTypes[entry.key] = type;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
