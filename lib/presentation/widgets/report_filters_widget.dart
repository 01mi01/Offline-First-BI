import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/category_provider.dart';
import '../../application/client_provider.dart';
import '../../application/date_range_filter.dart';
import '../../application/event_provider.dart';
import '../../application/location_options.dart';
import '../../application/location_provider.dart';
import '../../application/product_provider.dart';
import '../../application/supplier_provider.dart';
import '../../models/purchase_kind.dart';
import '../../models/report_filters.dart';
import 'filter_panel.dart';
import 'picker_options.dart';

class ReportFiltersWidget extends ConsumerWidget {
  final ReportFilters filters;
  final ValueChanged<ReportFilters> onChanged;
  final int activeTab;
  final bool combined;
  final bool alwaysOpen;

  const ReportFiltersWidget({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.activeTab,
    this.combined = false,
    this.alwaysOpen = false,
  });

  bool get _showSales => combined || activeTab == 0;
  bool get _showPurchases => combined || activeTab == 1;

  DateRangeFilter get _dates => DateRangeFilter(
    from: filters.startDate,
    to: filters.endDate,
    preset: filters.datePreset,
  );

  ReportFilters _withDates(DateRangeFilter dates) => filters.copyWith(
    startDate: dates.from,
    endDate: dates.to,
    datePreset: dates.preset,
    clearStartDate: dates.from == null,
    clearEndDate: dates.to == null,
    clearDatePreset: dates.preset == null,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider).categories;
    final products = ref.watch(productProvider).products;
    final events = ref.watch(eventProvider).events;
    final locations = ref.watch(locationProvider).locations;
    final clients = ref.watch(clientProvider).clients;
    final suppliers = ref.watch(supplierProvider).suppliers;

    final fields = <FilterField>[
      if (_showSales) ...[
        FilterDropdown<int?>(
          label: 'Categoría',
          options: [
            const FilterOption<int?>(null, 'Todas las categorías'),
            for (final c in categories) FilterOption<int?>(c.id, c.name),
          ],
          current: filters.categoryId,
          defaultValue: null,
          onApply: (id) => onChanged(
            id == null
                ? filters.copyWith(clearCategory: true)
                : filters.copyWith(categoryId: id),
          ),
        ),
        FilterDropdown<String?>(
          label: 'Tipo de precio',
          options: const [
            FilterOption<String?>(null, 'Todos'),
            FilterOption<String?>('A', 'Precio A'),
            FilterOption<String?>('B', 'Precio B'),
          ],
          current: filters.priceType,
          defaultValue: null,
          onApply: (value) => onChanged(
            value == null
                ? filters.copyWith(clearPriceType: true)
                : filters.copyWith(priceType: value),
          ),
        ),
      ],
      FilterDropdown<String?>(
        label: 'País',
        options: [
          const FilterOption<String?>(null, 'Todos los países'),
          for (final c in countryOptions(locations)) FilterOption<String?>(c, c),
        ],
        current: filters.country,
        defaultValue: null,
        onApply: (value) => onChanged(
          value == null
              ? filters.copyWith(clearCountry: true)
              : filters.copyWith(
                  country: value,
                  clearCity:
                      filters.city != null &&
                      !cityOptions(
                        locations,
                        country: value,
                      ).contains(filters.city),
                ),
        ),
      ),
      FilterDropdown<String?>(
        label: 'Ciudad',
        options: [
          const FilterOption<String?>(null, 'Todas las ciudades'),
          for (final c in cityOptions(locations, country: filters.country))
            FilterOption<String?>(c, c),
        ],
        current: filters.city,
        defaultValue: null,
        onApply: (value) => onChanged(
          value == null
              ? filters.copyWith(clearCity: true)
              : filters.copyWith(city: value),
        ),
      ),
      if (_showPurchases)
        FilterDropdown<PurchaseKind>(
          label: combined ? 'Tipo de operación' : 'Tipo',
          options: [
            for (final k in PurchaseKind.values)
              FilterOption(k, k == PurchaseKind.all ? 'Ambos tipos' : k.label),
          ],
          current: filters.purchaseKind,
          defaultValue: PurchaseKind.all,
          onApply: (value) =>
              onChanged(filters.copyWith(purchaseKind: value)),
        ),
      if (!combined && activeTab == 0)
        FilterPicker(
          label: 'Cliente',
          searchHint: 'Buscar cliente',
          allLabel: 'Todos los clientes',
          options: clientPickerOptions(clients),
          current: filters.clientId,
          onApply: (id) => onChanged(
            id == null
                ? filters.copyWith(clearClient: true)
                : filters.copyWith(clientId: id),
          ),
        ),
      if (_showSales)
        FilterPicker(
          label: 'Producto',
          searchHint: 'Buscar producto',
          allLabel: 'Todos los productos',
          options: productPickerOptions(
            products.where(
              (p) =>
                  filters.categoryId == null ||
                  p.categoryId == filters.categoryId,
            ),
            categories,
          ),
          current: filters.productId,
          onApply: (id) => onChanged(
            id == null
                ? filters.copyWith(clearProduct: true)
                : filters.copyWith(productId: id),
          ),
        ),
      if (!combined && activeTab == 1)
        FilterPicker(
          label: 'Proveedor',
          searchHint: 'Buscar proveedor',
          allLabel: 'Todos los proveedores',
          options: supplierPickerOptions(suppliers),
          current: filters.supplierId,
          onApply: (id) => onChanged(
            id == null
                ? filters.copyWith(clearSupplier: true)
                : filters.copyWith(supplierId: id),
          ),
        ),
      FilterPicker(
        label: 'Evento',
        searchHint: 'Buscar evento',
        allLabel: 'Todos los eventos',
        options: eventPickerOptions(
          events,
          locations,
          onlyActive: false,
        ),
        current: filters.eventId,
        onApply: (id) => onChanged(
          id == null
              ? filters.copyWith(clearEvent: true)
              : filters.copyWith(eventId: id),
        ),
      ),
      FilterPicker(
        label: 'Ubicación',
        searchHint: 'Buscar ubicación',
        allLabel: 'Todas las ubicaciones',
        options: locationPickerOptions(locations),
        current: filters.locationId,
        onApply: (id) => onChanged(
          id == null
              ? filters.copyWith(clearLocation: true)
              : filters.copyWith(locationId: id),
        ),
      ),
      FilterDates(
        current: _dates,
        onApply: (dates) => onChanged(_withDates(dates)),
      ),
    ];

    return FilterArea(
      fields: fields,
      alwaysOpen: alwaysOpen,
      onClear: () => onChanged(const ReportFilters()),
    );
  }
}
