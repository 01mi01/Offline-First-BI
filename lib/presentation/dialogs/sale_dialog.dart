import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sale_provider.dart';
import '../../application/location_options.dart';
import '../../application/search_filter.dart';
import '../widgets/catalog_filter_bar.dart' show RevealOnFocus;
import '../../application/client_provider.dart';
import '../../application/product_provider.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../theme/app_theme.dart';
import 'client_dialog.dart';
import '../widgets/focus_utils.dart';
import '../widgets/app_controls.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/transaction_date_field.dart';
import '../../application/form_validation.dart';
import '../../config/date_formatters.dart';
import '../widgets/app_style.dart';
import '../../models/default_records.dart';
import '../../config/app_clock.dart';
import '../../config/rounding.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/app_buttons.dart';
import '../widgets/empty_state.dart';

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
  // Error de los productos (carrito vacío, sin stock) y error general al
  // registrar.
  String? _cartError;
  String? _error;
  final _discountKey = GlobalKey<FormFieldState<String>>();
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
    showAppSheet<void>(
      context,
      builder: (_) => ClientDialog(
        onSaved: (clientId) {
          setState(() => _selectedClientId = clientId);
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

  // El carrito cambió: se limpian sus avisos y se revisa de nuevo el descuento
  // (puede haber quedado por encima del subtotal).
  void _cartChanged() {
    _cartError = null;
    _error = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _discountController.text.trim().isNotEmpty) {
        _discountKey.currentState?.validate();
      }
    });
  }

  // El descuento es opcional: no negativo, con hasta dos decimales y sin pasar
  // del subtotal.
  String? _validateDiscount(String? value) {
    final error = validateDecimal(value, required: false, allowZero: true);
    if (error != null) return error;
    return ref
        .read(saleRepositoryProvider)
        .validateDiscount(round2(parseNumber(value) ?? 0), _subtotal);
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    if (_cartItems.isEmpty) {
      setState(() => _cartError = 'Agrega al menos un producto');
      return;
    }
    if (!valid) return;

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
            _cartError =
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
    final confirmed = await confirmCancellation(
      context,
      title: '¿Cancelar venta?',
      message:
          'Se devolverá al inventario lo vendido. La venta seguirá en la '
          'lista, marcada como cancelada y ya no se podrá editar.',
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

    return AppSheetScaffold(
      title: isEditing ? 'Editar venta' : 'Nueva venta',
      child: Form(
        key: _formKey,
        child: FormScroll(
            children: [
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
                labelAction: FormAddButton(onPressed: _showAddClientSheet),
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
                onChanged: (val) => setState(() => _selectedLocationId = val),
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
                onChanged: (val) => setState(() => _selectedEventId = val),
              ),
              const SizedBox(height: AppSpacing.s16),
              AppDateField(
                label: 'Fecha',
                valueText: formatDate(_date),
                onTap: _pickDate,
              ),
              const SizedBox(height: AppSpacing.s24),
              LabeledField(
                label: 'Productos',
                builder: (_) => RevealOnFocus(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSearchBar(
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
                            AppMetrics.groupRadius,
                          ),
                        ),
                        child: visibleProducts.isEmpty
                            ? searchingProducts
                                  ? const AppEmptyState.noMatch(compact: true)
                                  : const AppEmptyState.hint(
                                      icon: Icons.search_rounded,
                                      text: 'Escribe para buscar un producto.',
                                      compact: true,
                                    )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: visibleProducts.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: AppMetrics.dividerIndent,
                                  color: AppColors.separator,
                                ),
                                itemBuilder: (context, index) {
                                  final p = visibleProducts[index];
                                  final inCart = _cartItems.containsKey(p.id);
                                  return AppRow(
                                    title: p.name,
                                    subtitle: Text(
                                      'A: Bs. ${fixed2(p.priceA)}  •  B: Bs. ${fixed2(p.priceB)}  •  Stock: ${_availableStock(p)}',
                                      style: AppText.rowSubtitle(context),
                                    ),
                                    trailing: Icon(
                                      inCart
                                          ? Icons.check_circle_rounded
                                          : Icons.add_circle_rounded,
                                      color: inCart
                                          ? AppColors.cyanDark
                                          : AppColors.chevron,
                                    ),
                                    onTap: () => setState(() {
                                      _cartChanged();
                                      if (inCart) {
                                        _cartItems.remove(p.id);
                                        _cartPriceTypes.remove(p.id);
                                      } else if (_availableStock(p) < 1) {
                                        _cartError =
                                            'No hay stock disponible de ${p.name}';
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
              if (_cartError != null) FormErrorText(_cartError!),
              const SizedBox(height: AppSpacing.s16),
              if (_cartItems.isNotEmpty) ...[
                const FormSectionLabel('Carrito'),
                const SizedBox(height: AppSpacing.s6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
                  ),
                  child: Column(
                    children: [
                      for (final entry in _cartItems.entries)
                        _cartRow(context, entry, products),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],
              LabeledField(
                label: 'Descuento (Bs.)',
                builder: (_) => TextFormField(
                  key: _discountKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(hintText: '0'),
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
                  validator: _validateDiscount,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              LabeledField(
                label: 'Notas',
                builder: (_) => TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _notesController,
                  decoration: const InputDecoration(
                    hintText: 'Observaciones opcionales',
                  ),
                  minLines: 2,
                  maxLines: 4,
                  validator: validateOptionalText,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              AppSection(
                padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                children: [
                  AppValueRow(
                    label: 'Subtotal',
                    value: 'Bs. ${fixed2(_subtotal)}',
                  ),
                  AppValueRow(
                    label: 'Descuento',
                    value: _discount > 0
                        ? '- Bs. ${fixed2(_discount)}'
                        : 'Bs. 0.00',
                    valueColor: _discount > 0 ? AppColors.error : null,
                  ),
                  AppValueRow(
                    label: 'Total',
                    value: 'Bs. ${fixed2(_total)}',
                    bold: true,
                    valueColor: AppColors.textPrimary,
                  ),
                ],
              ),
              if (_error != null) ...[
                FormErrorText(_error!),
                const SizedBox(height: AppSpacing.s16),
              ],
              const SizedBox(height: AppSpacing.s24),
              FormActions(
                onSecondary: () => Navigator.pop(context),
                primaryLabel: isEditing ? 'Guardar' : 'Registrar venta',
                onPrimary: _save,
                loading: _isLoading,
                destructive: isEditing && !widget.sale!.isCanceled
                    ? AppActionButton(
                        label: 'Cancelar venta',
                        kind: AppButtonKind.destructive,
                        onPressed: _isLoading ? null : _cancelSale,
                      )
                    : null,
              ),
            ],
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
    final available = _availableStock(product);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
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
                    Text(product.name, style: AppText.rowTitle(context)),
                    Text(
                      'Bs. ${fixed2(linePrice * entry.value)}',
                      style: AppText.rowSubtitle(
                        context,
                        color: AppColors.cyanDark,
                      ),
                    ),
                    if (entry.value >= available)
                      Text(
                        'Máximo disponible: $available',
                        style: AppText.rowSubtitle(context),
                      ),
                  ],
                ),
              ),
              Text(
                '${entry.value}',
                style: AppText.rowTitle(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              AppStepper(
                onMinus: () => setState(() {
                  _cartChanged();
                  if (entry.value <= 1) {
                    _cartItems.remove(entry.key);
                  } else {
                    _cartItems[entry.key] = entry.value - 1;
                  }
                }),
                onPlus: entry.value >= available
                    ? null
                    : () => setState(() {
                        _cartChanged();
                        _cartItems[entry.key] = entry.value + 1;
                      }),
              ),
            ],
          ),
          SizedBox(
            width: 220,
            child: AppSegmented<String>(
              segments: const [
                AppSegment('A', 'Precio A'),
                AppSegment('B', 'Precio B'),
              ],
              selected: priceType,
              onChanged: (type) {
                if (type == null) return;
                setState(() {
                  _cartChanged();
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
