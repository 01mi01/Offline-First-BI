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
import '../../application/location_options.dart';
import 'focus_utils.dart';
import 'searchable_picker.dart';

class ReportFiltersWidget extends ConsumerStatefulWidget {
  final ReportFilters filters;
  final ValueChanged<ReportFilters> onChanged;
  final int activeTab;

  // Modo Business Intelligence: un solo panel para ventas y compras a la vez.
  // Muestra los filtros de ambos lados (menos cliente y proveedor) y llama
  // "Tipo de operación" al tipo de compra. Los atajos de fecha se muestran
  // siempre.
  final bool combined;

  const ReportFiltersWidget({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.activeTab,
    this.combined = false,
  });

  @override
  ConsumerState<ReportFiltersWidget> createState() =>
      _ReportFiltersWidgetState();
}

// Datos del filtro con búsqueda que está abierto: el buscador aparece en línea,
// justo debajo de los chips.
class _SearchSpec {
  final String title;
  final String searchHint;
  final String allLabel;
  final int? selected;
  final List<({int id, String name})> entries;
  // Línea secundaria opcional de cada opción (la zona de una ubicación).
  final Map<int, String> subtitles;
  // Texto del campo ya elegida la opción (por defecto, el nombre).
  final Map<int, String> selectedNames;
  final ReportFilters Function(int id) apply;
  final ReportFilters Function() clear;

  const _SearchSpec({
    required this.title,
    required this.searchHint,
    required this.allLabel,
    required this.selected,
    required this.entries,
    this.subtitles = const {},
    this.selectedNames = const {},
    required this.apply,
    required this.clear,
  });
}

class _ReportFiltersWidgetState extends ConsumerState<ReportFiltersWidget> {
  _SearchSpec? _search;

  ReportFilters get filters => widget.filters;
  ValueChanged<ReportFilters> get onChanged => widget.onChanged;
  int get activeTab => widget.activeTab;
  bool get combined => widget.combined;

  bool get _showSales => combined || activeTab == 0;
  bool get _showPurchases => combined || activeTab == 1;

  // Atajo activo: el que genera exactamente el rango Desde/Hasta elegido.
  DatePreset? get _selectedPreset {
    for (final preset in DatePreset.values) {
      final range = DateRangeFilter.forPreset(preset);
      if (filters.startDate != null &&
          filters.endDate != null &&
          dateOnly(filters.startDate!) == range.from &&
          dateOnly(filters.endDate!) == range.to) {
        return preset;
      }
    }
    return null;
  }

  // Un atajo reemplaza ambas fechas; volver a tocarlo las quita.
  void _selectPreset(DatePreset? preset) {
    if (preset == null) {
      onChanged(filters.copyWith(clearStartDate: true, clearEndDate: true));
      return;
    }
    final range = DateRangeFilter.forPreset(preset);
    onChanged(filters.copyWith(startDate: range.from, endDate: range.to));
  }

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

  // Categoría, Producto, Cliente y Evento se eligen con el buscador en línea (el
  // mismo que en los formularios): son listas que pueden ser largas y una lista
  // fija no cabe en pantalla. [allLabel] es la opción que quita el filtro.
  void _pickWithSearch({
    required BuildContext context,
    required String title,
    required String searchHint,
    required String allLabel,
    required int? selected,
    required List<({int id, String name})> entries,
    Map<int, String> subtitles = const {},
    Map<int, String> selectedNames = const {},
    required ReportFilters Function(int id) apply,
    required ReportFilters Function() clear,
  }) {
    dismissKeyboard();
    setState(() {
      _search = _SearchSpec(
        title: title,
        searchHint: searchHint,
        allLabel: allLabel,
        selected: selected,
        entries: entries,
        subtitles: subtitles,
        selectedNames: selectedNames,
        apply: apply,
        clear: clear,
      );
    });
  }

  Widget _buildInlineSearch(_SearchSpec spec) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: SearchablePickerField<int>(
        key: ValueKey('filter-search-${spec.title}'),
        label: 'Filtrar por ${spec.title}',
        searchHint: spec.searchHint,
        value: spec.selected,
        autofocus: true,
        options: [
          PickerOption<int>(null, spec.allLabel),
          for (final e in spec.entries)
            PickerOption<int>(
              e.id,
              e.name,
              subtitle: spec.subtitles[e.id],
              selectedLabel: spec.selectedNames[e.id],
            ),
        ],
        onChanged: (id) {
          setState(() => _search = null);
          onChanged(id == null ? spec.clear() : spec.apply(id));
        },
        onDismissed: () {
          if (mounted && _search?.title == spec.title) {
            setState(() => _search = null);
          }
        },
      ),
    );
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
      useSafeArea: true,
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
                Expanded(
                  child: Text(
                    'Filtrar por $label',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
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
                        color: AppColors.cyanDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            // Con la lista larga se desplaza en vez de desbordar la hoja.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...items.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: item.child,
                      trailing: item.value == value
                          ? Icon(Icons.check_rounded, color: AppColors.cyanDark)
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider).categories;
    final products = ref.watch(productProvider).products;
    final events = ref.watch(eventProvider).events;
    final locations = ref.watch(locationProvider).locations;
    final clients = ref.watch(clientProvider).clients;
    final suppliers = ref.watch(supplierProvider).suppliers;
    final allLocations = locations;
    final categoryItems = [
      for (final c in categories)
        DropdownMenuItem(value: c.id, child: Text(c.name)),
    ];
    final countryItems = [
      for (final c in countryOptions(allLocations))
        DropdownMenuItem(value: c, child: Text(c)),
    ];
    final cityItems = [
      for (final c in cityOptions(allLocations, country: filters.country))
        DropdownMenuItem(value: c, child: Text(c)),
    ];

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
                      color: AppColors.cyanDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),

          // Atajos de fecha (Reportes y Business Intelligence)
          DatePresetChips(
            selected: _selectedPreset,
            onSelected: _selectPreset,
          ),
          const SizedBox(height: AppSpacing.s8),

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
              if (!combined && activeTab == 0) ...[
                _DropChip(
                  label: 'Cliente',
                  value: filters.clientId,
                  items: clients
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onTap: () => _pickWithSearch(
                    context: context,
                    title: 'Cliente',
                    searchHint: 'Buscar cliente',
                    allLabel: 'Todos los clientes',
                    selected: filters.clientId,
                    entries: [for (final c in clients) (id: c.id, name: c.name)],
                    apply: (id) => filters.copyWith(clientId: id),
                    clear: () => filters.copyWith(clearClient: true),
                  ),
                  onClear: () => onChanged(filters.copyWith(clearClient: true)),
                ),
              ],
              // Categoría y producto - solo en ventas
              if (_showSales) ...[
                // Lista corta y cerrada: un desplegable con todas las categorías.
                _DropChip(
                  label: 'Todas las categorías',
                  value: filters.categoryId,
                  items: categoryItems,
                  onTap: () => _showDropdownSheet(
                    context,
                    'Categoría',
                    filters.categoryId,
                    categoryItems,
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
                  onTap: () => _pickWithSearch(
                    context: context,
                    title: 'Producto',
                    searchHint: 'Buscar producto',
                    allLabel: 'Todos los productos',
                    selected: filters.productId,
                    // Con una categoría elegida, solo sus productos.
                    entries: [
                      for (final p in products)
                        if (filters.categoryId == null ||
                            p.categoryId == filters.categoryId)
                          (id: p.id, name: p.name),
                    ],
                    apply: (id) => filters.copyWith(productId: id),
                    clear: () => filters.copyWith(clearProduct: true),
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
              if (_showPurchases) ...[
                // Tipo: solo materiales o solo gastos ("Limpiar" = ambos).
                _DropChip<PurchaseKind>(
                  label: combined ? 'Tipo de operación' : 'Tipo',
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
                    combined ? 'Tipo de operación' : 'Tipo',
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
                if (!combined)
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
                    // Búsqueda en línea, como Cliente y Producto.
                    onTap: () => _pickWithSearch(
                      context: context,
                      title: 'Proveedor',
                      searchHint: 'Buscar proveedor',
                      allLabel: 'Todos los proveedores',
                      selected: filters.supplierId,
                      entries: [
                        for (final s in suppliers) (id: s.id, name: s.name),
                      ],
                      apply: (id) => filters.copyWith(supplierId: id),
                      clear: () => filters.copyWith(clearSupplier: true),
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
                onTap: () => _pickWithSearch(
                  context: context,
                  title: 'Evento',
                  searchHint: 'Buscar evento',
                  allLabel: 'Todos los eventos',
                  selected: filters.eventId,
                  entries: [for (final e in events) (id: e.id, name: e.name)],
                  apply: (id) => filters.copyWith(eventId: id),
                  clear: () => filters.copyWith(clearEvent: true),
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
                        child: Text(locationLabelWithZone(l)),
                      ),
                    )
                    .toList(),
                onTap: () => _pickWithSearch(
                  context: context,
                  title: 'Ubicación',
                  searchHint: 'Buscar ubicación',
                  allLabel: 'Todas las ubicaciones',
                  selected: filters.locationId,
                  entries: [
                    for (final l in locations)
                      if (l.isActive)
                        (id: l.id, name: locationLabel(l)),
                  ],
                  subtitles: {
                    for (final l in locations)
                      if (locationZone(l) != null) l.id: locationZone(l)!,
                  },
                  selectedNames: {
                    for (final l in locations) l.id: locationLabelWithZone(l),
                  },
                  apply: (id) => filters.copyWith(locationId: id),
                  clear: () => filters.copyWith(clearLocation: true),
                ),
                onClear: () => onChanged(filters.copyWith(clearLocation: true)),
              ),

              // País y ciudad de la ubicación vinculada (ambos tabs). Las
              // ciudades se acotan al país elegido.
              _DropChip<String>(
                label: 'Todos los países',
                value: filters.country,
                items: countryItems,
                onTap: () => _showDropdownSheet<String>(
                  context,
                  'País',
                  filters.country,
                  countryItems,
                  (val) => onChanged(
                    filters.copyWith(
                      country: val,
                      // La ciudad elegida deja de valer si no es de ese país.
                      clearCity:
                          filters.city != null &&
                          !cityOptions(
                            allLocations,
                            country: val,
                          ).contains(filters.city),
                    ),
                  ),
                  () => onChanged(filters.copyWith(clearCountry: true)),
                ),
                onClear: () => onChanged(filters.copyWith(clearCountry: true)),
              ),
              _DropChip<String>(
                label: 'Todas las ciudades',
                value: filters.city,
                items: cityItems,
                onTap: () => _showDropdownSheet<String>(
                  context,
                  'Ciudad',
                  filters.city,
                  cityItems,
                  (val) => onChanged(filters.copyWith(city: val)),
                  () => onChanged(filters.copyWith(clearCity: true)),
                ),
                onClear: () => onChanged(filters.copyWith(clearCity: true)),
              ),
            ],
          ),

          // Buscador en línea del filtro abierto (Cliente, Categoría, ...).
          if (_search != null) _buildInlineSearch(_search!),
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
              ? AppColors.cyanDark.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: active ? AppColors.cyanDark : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _getLabel(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: active ? AppColors.cyanDark : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: active ? AppColors.cyanDark : AppColors.textSecondary,
            ),
            if (active) ...[
              const SizedBox(width: AppSpacing.s2),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.cyanDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
