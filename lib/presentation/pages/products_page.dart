import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_first_bi/models/product_model.dart';
import '../../application/product_provider.dart';
import '../../application/product_catalog_filter.dart';
import '../../application/record_search.dart';
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
import '../widgets/empty_state.dart';

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
    final visible = filter.apply(
      state.products,
      index: ref.watch(productSearchIndexProvider),
    );
    final priceDisplay = filter.priceDisplay;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FlatFab(
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
                    child: AppEmptyState.list(
                      plural: 'productos',
                      icon: Icons.inventory_2_rounded,
                      actionLabel: 'Nuevo producto',
                      onAction: () => _showForm(context, null),
                    ),
                  )
                : visible.isEmpty
                ? const SingleChildScrollView(
                    child: AppEmptyState.noMatch(),
                  )
                : _isGrid
                ? _GridView(products: visible, priceDisplay: priceDisplay)
                : _ListViewWidget(products: visible, priceDisplay: priceDisplay),
          ),
        ],
      ),
    );
  }
}

void _showForm(BuildContext context, ProductModel? product) {
  showFormSheet<void>(context, builder: (_) => ProductDialog(product: product));
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

String _categoryNameOf(List<CategoryModel> categories, ProductModel p) =>
    categories
        .where((c) => c.id == p.categoryId)
        .map((c) => c.name)
        .firstOrNull ??
    'Sin categoría';

class _ListViewWidget extends ConsumerWidget {
  final List<ProductModel> products;
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

class _GridView extends StatelessWidget {
  final List<ProductModel> products;
  final PriceDisplay priceDisplay;

  const _GridView({required this.products, required this.priceDisplay});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: AppFlat.gridWithFab,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.s16,
        mainAxisSpacing: AppSpacing.s16,
        childAspectRatio: 0.78,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return FlatTile(
          imagePath: p.image,
          icon: Icons.inventory_2_rounded,
          title: p.name,
          pill: p.isActive ? null : StatusBadge.forState(isActive: false),
          lines: _catalogPriceLines(p, priceDisplay),
          onTap: () => showCatalogPopup(
            context,
            title: p.name,
            icon: Icons.inventory_2_rounded,
            imagePath: p.image,
            description: p.description,
            lines: _catalogPriceLines(p, priceDisplay, detailed: true),
          ),
        );
      },
    );
  }
}

List<String> _catalogPriceLines(
  ProductModel p,
  PriceDisplay display, {
  bool detailed = false,
}) {
  String bs(double v) => 'Bs. ${fixed2(v)}';
  switch (display) {
    case PriceDisplay.a:
      return ['Precio: ${bs(p.priceA)}'];
    case PriceDisplay.b:
      return ['Precio: ${bs(p.priceB)}'];
    case PriceDisplay.both:
      final a = detailed ? 'Precio A' : 'A';
      final b = detailed ? 'Precio B' : 'B';
      return ['$a: ${bs(p.priceA)}', '$b: ${bs(p.priceB)}'];
    case PriceDisplay.none:
      return const [];
  }
}

class _ProductRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final p = product;
    final prices = [
      if (priceDisplay == PriceDisplay.a || priceDisplay == PriceDisplay.both)
        'A: Bs. ${fixed2(p.priceA)}',
      if (priceDisplay == PriceDisplay.b || priceDisplay == PriceDisplay.both)
        'B: Bs. ${fixed2(p.priceB)}',
    ];

    return RecordRow(
      onTap: onTap,
      thumb: RecordThumb(imagePath: p.image, icon: Icons.inventory_2_rounded),
      title: p.name,
      details: [RecordLine(categoryName), RecordLine('Stock: ${p.stock}')],
      pill: StatusBadge.forState(isActive: p.isActive),
      below: prices.isEmpty
          ? null
          : Wrap(
              spacing: AppSpacing.s16,
              children: [for (final price in prices) RecordPrice(price)],
            ),
    );
  }
}

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
    String bs(double v) => 'Bs. ${fixed2(v)}';
    return RecordDetailSheet(
      title: 'Detalle del producto',
      onEdit: widget.onEdit,
      children: [
        RecordHeadline(
          title: p.name,
          thumb: RecordThumb(
            imagePath: p.image,
            icon: Icons.inventory_2_rounded,
            size: AppIconSize.s120,
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
