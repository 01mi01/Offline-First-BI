import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/category_provider.dart';
import '../../application/product_provider.dart';
import '../../application/event_provider.dart';
import '../../application/location_provider.dart';
import '../../application/client_provider.dart';
import '../../application/supplier_provider.dart';
import '../../models/purchase_kind.dart';
import '../../models/report_filters.dart';
import '../../theme/app_theme.dart';
import '../../application/date_range_filter.dart';
import '../../config/date_formatters.dart';
import 'date_range_filter_bar.dart';
import 'focus_utils.dart';

class ReportFiltersWidget extends ConsumerWidget {
  final ReportFilters filters;
  final ValueChanged<ReportFilters> onChanged;
  final int activeTab;

  const ReportFiltersWidget({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.activeTab,
  });

  String _formatDate(DateTime date) => formatDate(date);

  // Hoy es la última fecha elegible, y Hasta no puede ser anterior a Desde
  // (el mismo día en ambas es válido): si no, se rechaza con un aviso.
  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final picked = await pickFilterDate(
      context,
      initial: isStart ? filters.startDate : filters.endDate,
    );
    if (picked == null || !context.mounted) return;
    final next = isStart
        ? filters.copyWith(startDate: picked)
        : filters.copyWith(endDate: picked);
    final error = validateDateRange(from: next.startDate, to: next.endDate);
    if (error != null) {
      showDateRangeError(context, error);
      return;
    }
    onChanged(next);
  }

  void _showDropdownSheet<T>(
    BuildContext context,
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onSelect,
    VoidCallback onClear,
  ) {
    dismissKeyboard();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtrar por $label',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (value != null)
                  GestureDetector(
                    onTap: () {
                      onClear();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Limpiar',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: item.child,
                trailing: item.value == value
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  onSelect(item.value);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider).categories;
    final products = ref.watch(productProvider).products;
    final events = ref.watch(eventProvider).events;
    final locations = ref.watch(locationProvider).locations;
    final clients = ref.watch(clientProvider).clients;
    final suppliers = ref.watch(supplierProvider).suppliers;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtros',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (filters.hasActive)
                GestureDetector(
                  onTap: () => onChanged(const ReportFilters()),
                  child: Text(
                    'Limpiar todo',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),

          // Fechas
          Row(
            children: [
              Expanded(
                child: DateFilterChip(
                  label: filters.startDate != null
                      ? 'Desde: ${_formatDate(filters.startDate!)}'
                      : 'Fecha de inicio',
                  active: filters.startDate != null,
                  onTap: () => _pickDate(context, true),
                  onClear: filters.startDate != null
                      ? () => onChanged(filters.copyWith(clearStartDate: true))
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DateFilterChip(
                  label: filters.endDate != null
                      ? 'Hasta: ${_formatDate(filters.endDate!)}'
                      : 'Fecha de fin',
                  active: filters.endDate != null,
                  onTap: () => _pickDate(context, false),
                  onClear: filters.endDate != null
                      ? () => onChanged(filters.copyWith(clearEndDate: true))
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Chips de filtro: se acomodan en varias líneas (Wrap) en vez de un
          // scroll horizontal, para que ninguno quede cortado en el borde.
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              // Solo en ventas
              if (activeTab == 0) ...[
                _DropChip(
                  label: 'Cliente',
                  value: filters.clientId,
                  items: clients
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onTap: () => _showDropdownSheet(
                    context,
                    'Cliente',
                    filters.clientId,
                    clients
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    (val) => onChanged(filters.copyWith(clientId: val)),
                    () => onChanged(filters.copyWith(clearClient: true)),
                  ),
                  onClear: () => onChanged(filters.copyWith(clearClient: true)),
                ),
              ],
              // Categoría y producto - solo en ventas
              if (activeTab == 0) ...[
                _DropChip(
                  label: 'Categoría',
                  value: filters.categoryId,
                  items: categories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onTap: () => _showDropdownSheet(
                    context,
                    'Categoría',
                    filters.categoryId,
                    categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    (val) => onChanged(filters.copyWith(categoryId: val)),
                    () => onChanged(filters.copyWith(clearCategory: true)),
                  ),
                  onClear: () =>
                      onChanged(filters.copyWith(clearCategory: true)),
                ),
                _DropChip(
                  label: 'Producto',
                  value: filters.productId,
                  items: products
                      .where(
                        (p) =>
                            filters.categoryId == null ||
                            p.categoryId == filters.categoryId,
                      )
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onTap: () => _showDropdownSheet(
                    context,
                    'Producto',
                    filters.productId,
                    products
                        .where(
                          (p) =>
                              filters.categoryId == null ||
                              p.categoryId == filters.categoryId,
                        )
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    (val) => onChanged(filters.copyWith(productId: val)),
                    () => onChanged(filters.copyWith(clearProduct: true)),
                  ),
                  onClear: () =>
                      onChanged(filters.copyWith(clearProduct: true)),
                ),
                _DropChip<String>(
                  label: 'Tipo de precio',
                  value: filters.priceType,
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('Precio A')),
                    DropdownMenuItem(value: 'B', child: Text('Precio B')),
                  ],
                  onTap: () => _showDropdownSheet<String>(
                    context,
                    'Tipo de precio',
                    filters.priceType,
                    const [
                      DropdownMenuItem(value: 'A', child: Text('Precio A')),
                      DropdownMenuItem(value: 'B', child: Text('Precio B')),
                    ],
                    (val) => onChanged(filters.copyWith(priceType: val)),
                    () => onChanged(filters.copyWith(clearPriceType: true)),
                  ),
                  onClear: () =>
                      onChanged(filters.copyWith(clearPriceType: true)),
                ),
              ],

              // Solo en compras
              if (activeTab == 1) ...[
                // Tipo: solo materiales o solo gastos ("Limpiar" = ambos).
                _DropChip<PurchaseKind>(
                  label: 'Tipo',
                  value: filters.purchaseKind == PurchaseKind.all
                      ? null
                      : filters.purchaseKind,
                  items: [
                    DropdownMenuItem(
                      value: PurchaseKind.material,
                      child: Text(PurchaseKind.material.label),
                    ),
                    DropdownMenuItem(
                      value: PurchaseKind.expense,
                      child: Text(PurchaseKind.expense.label),
                    ),
                  ],
                  onTap: () => _showDropdownSheet<PurchaseKind>(
                    context,
                    'Tipo',
                    filters.purchaseKind == PurchaseKind.all
                        ? null
                        : filters.purchaseKind,
                    [
                      DropdownMenuItem(
                        value: PurchaseKind.material,
                        child: Text(PurchaseKind.material.label),
                      ),
                      DropdownMenuItem(
                        value: PurchaseKind.expense,
                        child: Text(PurchaseKind.expense.label),
                      ),
                    ],
                    (val) => onChanged(filters.copyWith(purchaseKind: val)),
                    () => onChanged(
                      filters.copyWith(purchaseKind: PurchaseKind.all),
                    ),
                  ),
                  onClear: () => onChanged(
                    filters.copyWith(purchaseKind: PurchaseKind.all),
                  ),
                ),
                _DropChip(
                  label: 'Proveedor',
                  value: filters.supplierId,
                  items: suppliers
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onTap: () => _showDropdownSheet(
                    context,
                    'Proveedor',
                    filters.supplierId,
                    suppliers
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    (val) => onChanged(filters.copyWith(supplierId: val)),
                    () => onChanged(filters.copyWith(clearSupplier: true)),
                  ),
                  onClear: () =>
                      onChanged(filters.copyWith(clearSupplier: true)),
                ),
              ],

              // Evento - ambos tabs
              _DropChip(
                label: 'Evento',
                value: filters.eventId,
                items: events
                    .map(
                      (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
                    )
                    .toList(),
                onTap: () => _showDropdownSheet(
                  context,
                  'Evento',
                  filters.eventId,
                  events
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)),
                      )
                      .toList(),
                  (val) => onChanged(filters.copyWith(eventId: val)),
                  () => onChanged(filters.copyWith(clearEvent: true)),
                ),
                onClear: () => onChanged(filters.copyWith(clearEvent: true)),
              ),

              // Ubicación - ambos tabs
              _DropChip(
                label: 'Ubicación',
                value: filters.locationId,
                items: locations
                    .where((l) => l.isActive)
                    .map(
                      (l) => DropdownMenuItem(
                        value: l.id,
                        child: Text('${l.city}, ${l.country}'),
                      ),
                    )
                    .toList(),
                onTap: () => _showDropdownSheet(
                  context,
                  'Ubicación',
                  filters.locationId,
                  locations
                      .where((l) => l.isActive)
                      .map(
                        (l) => DropdownMenuItem(
                          value: l.id,
                          child: Text('${l.city}, ${l.country}'),
                        ),
                      )
                      .toList(),
                  (val) => onChanged(filters.copyWith(locationId: val)),
                  () => onChanged(filters.copyWith(clearLocation: true)),
                ),
                onClear: () => onChanged(filters.copyWith(clearLocation: true)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Chip de fecha

// Chip de dropdown
class _DropChip<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DropChip({
    required this.label,
    required this.value,
    required this.items,
    required this.onTap,
    required this.onClear,
  });

  String _getLabel() {
    if (value == null) return label;
    final item = items.where((i) => i.value == value).firstOrNull;
    if (item?.child is Text) return (item!.child as Text).data ?? label;
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getLabel(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: active ? AppColors.primary : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            if (active) ...[
              const SizedBox(width: AppSpacing.s2),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
