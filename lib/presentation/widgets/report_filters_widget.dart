import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../application/category_provider.dart';
import '../../application/product_provider.dart';
import '../../application/event_provider.dart';
import '../../application/location_provider.dart';
import '../../application/client_provider.dart';
import '../../application/supplier_provider.dart';
import '../../theme/app_theme.dart';

// Modelo de estado de filtros
class ReportFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? categoryId;
  final int? productId;
  final int? eventId;
  final int? locationId;
  final int? clientId;
  final int? supplierId;

  const ReportFilters({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.productId,
    this.eventId,
    this.locationId,
    this.clientId,
    this.supplierId,
  });

  bool get hasActive =>
      startDate != null ||
      endDate != null ||
      categoryId != null ||
      productId != null ||
      eventId != null ||
      locationId != null ||
      clientId != null ||
      supplierId != null;

  ReportFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? productId,
    int? eventId,
    int? locationId,
    int? clientId,
    int? supplierId,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearCategory = false,
    bool clearProduct = false,
    bool clearEvent = false,
    bool clearLocation = false,
    bool clearClient = false,
    bool clearSupplier = false,
  }) {
    return ReportFilters(
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      productId: clearProduct ? null : productId ?? this.productId,
      eventId: clearEvent ? null : eventId ?? this.eventId,
      locationId: clearLocation ? null : locationId ?? this.locationId,
      clientId: clearClient ? null : clientId ?? this.clientId,
      supplierId: clearSupplier ? null : supplierId ?? this.supplierId,
    );
  }
}

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

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          (isStart ? filters.startDate : filters.endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      onChanged(
        isStart
            ? filters.copyWith(startDate: picked)
            : filters.copyWith(endDate: picked),
      );
    }
  }

  void _showDropdownSheet(
    BuildContext context,
    String label,
    int? value,
    List<DropdownMenuItem<int>> items,
    ValueChanged<int?> onSelect,
    VoidCallback onClear,
  ) {
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
            const SizedBox(height: 16),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtros',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              if (filters.hasActive)
                GestureDetector(
                  onTap: () => onChanged(const ReportFilters()),
                  child: Text(
                    'Limpiar todo',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Fechas
          Row(
            children: [
              Expanded(
                child: _DateChip(
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
                child: _DateChip(
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

          // Filtros dropdown en scroll horizontal
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Solo en ventas
                if (activeTab == 0) ...[
                  _DropChip(
                    label: 'Cliente',
                    value: filters.clientId,
                    items: clients
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
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
                    onClear: () =>
                        onChanged(filters.copyWith(clearClient: true)),
                  ),
                  const SizedBox(width: 8),
                ],
                // Categoría y producto - solo en ventas
                if (activeTab == 0) ...[
                  _DropChip(
                    label: 'Categoría',
                    value: filters.categoryId,
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
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
                  const SizedBox(width: 8),
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
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
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
                  const SizedBox(width: 8),
                ],

                // Solo en compras
                if (activeTab == 1) ...[
                  _DropChip(
                    label: 'Proveedor',
                    value: filters.supplierId,
                    items: suppliers
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
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
                  const SizedBox(width: 8),
                ],

                // Evento - ambos tabs
                _DropChip(
                  label: 'Evento',
                  value: filters.eventId,
                  items: events
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)),
                      )
                      .toList(),
                  onTap: () => _showDropdownSheet(
                    context,
                    'Evento',
                    filters.eventId,
                    events
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    (val) => onChanged(filters.copyWith(eventId: val)),
                    () => onChanged(filters.copyWith(clearEvent: true)),
                  ),
                  onClear: () => onChanged(filters.copyWith(clearEvent: true)),
                ),
                const SizedBox(width: 8),

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
                  onClear: () =>
                      onChanged(filters.copyWith(clearLocation: true)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Chip de fecha
class _DateChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Chip de dropdown
class _DropChip extends StatelessWidget {
  final String label;
  final int? value;
  final List<DropdownMenuItem<int>> items;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              style: TextStyle(
                fontSize: 12,
                color: active ? AppColors.primary : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            if (active) ...[
              const SizedBox(width: 2),
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
