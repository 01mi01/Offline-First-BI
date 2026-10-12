import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_first_bi/models/product_model.dart';
import '../../application/product_provider.dart';
import '../../application/product_catalog_filter.dart';
import '../../application/status_filter.dart';
import '../../application/category_provider.dart';
import '../../application/material_provider.dart';
import '../../models/category_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/product_dialog.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_style.dart';
import '../widgets/flat_controls.dart';
import '../widgets/flat_list.dart';
import '../widgets/record_detail.dart';
import '../widgets/record_list.dart';
import '../widgets/status_badge.dart';
import '../../config/rounding.dart';
import '../widgets/app_controls.dart';
import '../widgets/filter_panel.dart';

// Productos: lista y catálogo de baldosas. Tocar un producto abre su detalle.
class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  bool _isGrid = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);
    final categories = ref.watch(categoryProvider).categories;
    final filter = ref.watch(productCatalogFilterProvider);
    final setFilter = ref.read(productCatalogFilterProvider.notifier);
    final visible = filter.apply(state.products);
    final priceDisplay = filter.priceDisplay;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FlatFab(
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
        heroTag: 'products_page_fab',
        onPressed: () => _showForm(context, null),
      ),
      body: Column(
        children: [
          ViewModeSwitcher(
            isGrid: _isGrid,
            onChanged: (value) => setState(() => _isGrid = value),
          ),
          FilterArea(
            search: AppSearchBar(
              initialText: filter.query,
              hintText: 'Buscar producto',
              onChanged: (value) =>
                  setFilter.update((f) => f.copyWith(query: value)),
            ),
            fields: [
              FilterDropdown<PriceDisplay>(
                label: 'Precio',
                options: const [
                  FilterOption(PriceDisplay.both, 'Ambos'),
                  FilterOption(PriceDisplay.a, 'Precio A'),
                  FilterOption(PriceDisplay.b, 'Precio B'),
                  FilterOption(PriceDisplay.none, 'Sin precio'),
                ],
                current: filter.priceDisplay,
                defaultValue: PriceDisplay.both,
                onApply: (value) =>
                    setFilter.update((f) => f.copyWith(priceDisplay: value)),
              ),
              FilterDropdown<StatusFilter>(
                label: 'Estado',
                options: statusFilterOptions(),
                current: filter.status,
                defaultValue: StatusFilter.all,
                onApply: (value) =>
                    setFilter.update((f) => f.copyWith(status: value)),
              ),
              FilterDropdown<int?>(
                label: 'Categoría',
                wide: true,
                options: [
                  const FilterOption<int?>(null, 'Todas las categorías'),
                  for (final c in categories) FilterOption<int?>(c.id, c.name),
                ],
                current: filter.categoryId,
                defaultValue: null,
                onApply: (id) => setFilter.update(
                  (f) => id == null
                      ? f.copyWith(clearCategory: true)
                      : f.copyWith(categoryId: id),
                ),
              ),
            ],
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.products.isEmpty
                ? Center(
                    child: AppEmptyState(
                      icon: Icons.inventory_2_rounded,
                      title: 'No se registraron productos',
                      actionLabel: 'Nuevo producto',
                      onAction: () => _showForm(context, null),
                    ),
                  )
                : visible.isEmpty
                ? const SingleChildScrollView(
                    child: AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Sin resultados',
                    ),
                  )
                : _isGrid
                ? _GridView(
                    products: visible,
                    priceDisplay: priceDisplay,
                    showInactive: filter.status == StatusFilter.inactive,
                  )
                : _ListViewWidget(products: visible, priceDisplay: priceDisplay),
          ),
        ],
      ),
    );
  }
}

void _showForm(BuildContext context, ProductModel? product) {
  showAppSheet<void>(context, builder: (_) => ProductDialog(product: product));
}

void _showDetail(
  BuildContext context,
  ProductModel product,
  String categoryName,
  PriceDisplay priceDisplay,
) {
  showAppSheet<void>(
    context,
    builder: (_) => _ProductDetailSheet(
      product: product,
      categoryName: categoryName,
      priceDisplay: priceDisplay,
      onEdit: () => _showForm(context, product),
    ),
  );
}

// Nombre de la categoría de un producto ("Sin categoría" si no se encuentra).
String _categoryNameOf(List<CategoryModel> categories, ProductModel p) =>
    categories
        .where((c) => c.id == p.categoryId)
        .map((c) => c.name)
        .firstOrNull ??
    'Sin categoría';

// Vista de lista
class _ListViewWidget extends ConsumerWidget {
  final List<ProductModel> products;
  // Qué precios muestra cada fila (mismo filtro que el catálogo).
  final PriceDisplay priceDisplay;

  const _ListViewWidget({required this.products, required this.priceDisplay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider).categories;
    return AppGroupListView(
      dividerIndent: AppMetrics.dividerIndentWithThumb,
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final categoryName = _categoryNameOf(categories, p);
        return _ProductRow(
          product: p,
          categoryName: categoryName,
          priceDisplay: priceDisplay,
          onTap: () => _showDetail(context, p, categoryName, priceDisplay),
        );
      },
    );
  }
}

// Vista de catálogo — solo activos, imagen, nombre, precio
class _GridView extends ConsumerWidget {
  final List<ProductModel> products;
  // Qué precio muestran las baldosas (y el detalle) de todo el catálogo.
  final PriceDisplay priceDisplay;
  // El catálogo muestra solo productos activos, salvo que el filtro de estado
  // pida los inactivos: entonces los refleja.
  final bool showInactive;

  const _GridView({
    required this.products,
    required this.priceDisplay,
    this.showInactive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider).categories;
    final active = showInactive
        ? products
        : products.where((p) => p.isActive).toList();

    return GridView.builder(
      padding: AppFlat.gridWithFab,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.s16,
        mainAxisSpacing: AppSpacing.s16,
        childAspectRatio: 0.78,
      ),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final p = active[index];
        return FlatTile(
          imagePath: p.image,
          icon: Icons.inventory_2_rounded,
          title: p.name,
          lines: _catalogPriceLines(p, priceDisplay),
          onTap: () =>
              _showDetail(context, p, _categoryNameOf(categories, p), priceDisplay),
        );
      },
    );
  }
}

// Líneas de precio del catálogo según el filtro de precio. Con un solo precio
// elegido la línea es solo "Precio: Bs. X", sin A/B; con "Ambos" hace falta
// distinguirlos, así que llevan etiqueta ("A:"/"B:"). Con "Sin precio" no hay
// líneas.
List<String> _catalogPriceLines(ProductModel p, PriceDisplay display) {
  String bs(double v) => 'Bs. ${fixed2(v)}';
  switch (display) {
    case PriceDisplay.a:
      return ['Precio: ${bs(p.priceA)}'];
    case PriceDisplay.b:
      return ['Precio: ${bs(p.priceB)}'];
    case PriceDisplay.both:
      return ['A: ${bs(p.priceA)}', 'B: ${bs(p.priceB)}'];
    case PriceDisplay.none:
      return const [];
  }
}

// Fila de la vista de lista, con los materiales vinculados debajo.
class _ProductRow extends ConsumerStatefulWidget {
  final ProductModel product;
  final String categoryName;
  final PriceDisplay priceDisplay;
  final VoidCallback onTap;

  const _ProductRow({
    required this.product,
    required this.categoryName,
    required this.priceDisplay,
    required this.onTap,
  });

  @override
  ConsumerState<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends ConsumerState<_ProductRow> {
  List<Map<String, dynamic>> _materials = [];
  bool _loadingMaterials = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  // Carga materiales con precio para este producto
  Future<void> _loadMaterials() async {
    final materials = await ref
        .read(materialProvider.notifier)
        .getMaterialsWithPriceForProduct(widget.product.id);
    if (mounted) {
      setState(() {
        _materials = materials;
        _loadingMaterials = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    // Solo los precios que pide el filtro de precio (con "Sin precio" no hay
    // ninguno). Mismas etiquetas cortas "A:" / "B:" que el catálogo.
    final prices = [
      if (widget.priceDisplay == PriceDisplay.a ||
          widget.priceDisplay == PriceDisplay.both)
        'A: Bs. ${fixed2(p.priceA)}',
      if (widget.priceDisplay == PriceDisplay.b ||
          widget.priceDisplay == PriceDisplay.both)
        'B: Bs. ${fixed2(p.priceB)}',
    ];

    return RecordRow(
      onTap: widget.onTap,
      thumb: RecordThumb(imagePath: p.image, icon: Icons.inventory_2_rounded),
      title: p.name,
      details: [
        RecordLine(widget.categoryName),
        if (p.description != null && p.description!.isNotEmpty)
          RecordLine(p.description!, maxLines: 2),
        RecordLine(
          [
            if (p.productionCost != null)
              'Costo: Bs. ${fixed2(p.productionCost!)}',
            'Stock: ${p.stock}',
          ].join('   '),
        ),
      ],
      pill: StatusBadge.forState(isActive: p.isActive),
      trailing: prices.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [for (final price in prices) RecordValue(price)],
            ),
      below: _loadingMaterials
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _materials.isEmpty
          ? null
          : _MaterialsList(materials: _materials),
    );
  }
}

// Materiales de un producto con su precio por unidad (en la fila y el detalle).
class _MaterialsList extends StatelessWidget {
  final List<Map<String, dynamic>> materials;

  const _MaterialsList({required this.materials});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Materiales', style: AppText.header(context)),
        const SizedBox(height: AppSpacing.s6),
        for (final m in materials)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s4),
            child: Row(
              children: [
                // El nombre cede espacio (y se recorta) antes de que el precio
                // con su unidad se desborde.
                Expanded(
                  child: Text(
                    m['name'] as String,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowSubtitle(
                      context,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  'Bs. ${fixed2((m['price'] as double))} / ${m['unit']}',
                  style: AppText.rowSubtitle(context),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Detalle de un producto: imagen, datos y materiales vinculados.
class _ProductDetailSheet extends ConsumerStatefulWidget {
  final ProductModel product;
  final String categoryName;
  final PriceDisplay priceDisplay;
  final VoidCallback onEdit;

  const _ProductDetailSheet({
    required this.product,
    required this.categoryName,
    required this.priceDisplay,
    required this.onEdit,
  });

  @override
  ConsumerState<_ProductDetailSheet> createState() =>
      _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<_ProductDetailSheet> {
  List<Map<String, dynamic>> _materials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final materials = await ref
        .read(materialProvider.notifier)
        .getMaterialsWithPriceForProduct(widget.product.id);
    if (mounted) {
      setState(() {
        _materials = materials;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final display = widget.priceDisplay;
    String bs(double v) => 'Bs. ${fixed2(v)}';
    return RecordDetailSheet(
      title: 'Detalle del producto',
      onEdit: widget.onEdit,
      children: [
        RecordHeadline(
          title: p.name,
          thumb: RecordThumb(
            imagePath: p.image,
            icon: Icons.inventory_2_rounded,
            size: 120,
          ),
          pill: StatusBadge.forState(isActive: p.isActive),
        ),
        AppSection(
          children: [
            AppValueRow(label: 'Categoría', value: widget.categoryName),
            if (p.description != null && p.description!.isNotEmpty)
              AppValueRow(label: 'Descripción', value: p.description!),
            if (display == PriceDisplay.a || display == PriceDisplay.both)
              AppValueRow(label: 'Precio A', value: bs(p.priceA)),
            if (display == PriceDisplay.b || display == PriceDisplay.both)
              AppValueRow(label: 'Precio B', value: bs(p.priceB)),
            if (p.productionCost != null)
              AppValueRow(
                label: 'Costo de producción',
                value: bs(p.productionCost!),
              ),
            AppValueRow(label: 'Stock', value: '${p.stock}'),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.s16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_materials.isNotEmpty)
          AppSection(
            header: 'Materiales',
            children: [
              for (final m in _materials)
                AppRow(
                  title: m['name'] as String,
                  trailing: Text(
                    '${bs(m['price'] as double)} / ${m['unit']}',
                    style: AppText.rowSubtitle(context),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
