import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_first_bi/models/product_model.dart';
import 'dart:io';
import '../../application/product_provider.dart';
import '../../application/product_catalog_filter.dart';
import '../../application/status_filter.dart';
import '../../application/category_provider.dart';
import '../../application/material_provider.dart';
import '../../theme/app_theme.dart';
import '../dialogs/product_dialog.dart';
import '../widgets/flat_controls.dart';
import '../widgets/flat_list.dart';
import '../widgets/flat_style.dart';
import '../../config/rounding.dart';
import '../widgets/app_controls.dart';
import '../widgets/filter_panel.dart';

// Productos con el estilo plano de Inventario (ver flat_style.dart): filas sin
// tarjeta separadas por una línea fina, catálogo de baldosas sin sombra y
// formularios con campos neutros.
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

    return FlatStyle(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: FlatFab(
          // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
          // conviven montadas a la vez bajo el shell de navegación inferior.
          heroTag: 'products_page_fab',
          onPressed: () => _showDialog(context, null),
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
                    for (final c in categories)
                      FilterOption<int?>(c.id, c.name),
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
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.products.isEmpty
                  ? FlatEmptyState(
                      icon: Icons.inventory_2_rounded,
                      message: 'No se registraron productos',
                      actionLabel: 'Nuevo producto',
                      onAction: () => _showDialog(context, null),
                    )
                  : visible.isEmpty
                  ? const FlatEmptyState(
                      icon: Icons.search_off_rounded,
                      message: 'Sin resultados',
                    )
                  : _isGrid
                  ? _GridView(
                      products: visible,
                      priceDisplay: priceDisplay,
                      showInactive: filter.status == StatusFilter.inactive,
                    )
                  : _ListViewWidget(
                      products: visible,
                      priceDisplay: priceDisplay,
                      onEdit: (p) => _showDialog(context, p),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, ProductModel? product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FlatStyle(child: ProductDialog(product: product)),
    );
  }
}

// Vista de lista — muestra todos los campos incluyendo materiales
class _ListViewWidget extends ConsumerWidget {
  final List<ProductModel> products;
  final ValueChanged<ProductModel> onEdit;
  // Qué precios muestra cada fila (mismo filtro que el catálogo).
  final PriceDisplay priceDisplay;

  const _ListViewWidget({
    required this.products,
    required this.onEdit,
    required this.priceDisplay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider).categories;

    return ListView.builder(
      padding: AppFlat.listWithFab,
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final categoryName =
            categories
                .where((c) => c.id == p.categoryId)
                .map((c) => c.name)
                .firstOrNull ??
            'Sin categoría';
        return _ProductRow(
          product: p,
          categoryName: categoryName,
          priceDisplay: priceDisplay,
          onEdit: () => onEdit(p),
        );
      },
    );
  }
}

// Vista de catálogo — solo activos, imagen, nombre, precio
class _GridView extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
          onTap: () => _showDetail(context, p),
        );
      },
    );
  }

  void _showDetail(BuildContext context, ProductModel p) {
    showDialog(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.5),
      builder: (_) => _ProductGridDetail(
        product: p,
        priceLines: _catalogPriceLines(p, priceDisplay, detailed: true),
      ),
    );
  }
}

// Líneas de precio del catálogo según el filtro de precio. Con un solo precio
// elegido la línea es solo "Precio: Bs. X", sin A/B; con "Ambos" hace falta
// distinguirlos, así que llevan etiqueta ("A:"/"B:" en la baldosa, "Precio
// A:"/"Precio B:" en el detalle). Con "Sin precio" no hay líneas.
List<String> _catalogPriceLines(
  ProductModel p,
  PriceDisplay display, {
  bool detailed = false,
}) {
  String bs(double v) => 'Bs. ${fixed2(v)}';
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

// Fila de la vista de lista, con los materiales vinculados debajo.
class _ProductRow extends ConsumerStatefulWidget {
  final ProductModel product;
  final String categoryName;
  final PriceDisplay priceDisplay;
  final VoidCallback onEdit;

  const _ProductRow({
    required this.product,
    required this.categoryName,
    required this.priceDisplay,
    required this.onEdit,
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

    return FlatListRow(
      onTap: widget.onEdit,
      leading: FlatThumb(imagePath: p.image, icon: Icons.inventory_2_rounded),
      title: p.name,
      details: [
        FlatMutedText(widget.categoryName),
        if (p.description != null && p.description!.isNotEmpty)
          FlatMutedText(p.description!, maxLines: 2),
        Wrap(
          spacing: AppSpacing.s12,
          children: [
            if (p.productionCost != null)
              FlatMutedText(
                'Costo: Bs. ${fixed2(p.productionCost!)}',
              ),
            FlatMutedText('Stock: ${p.stock}'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FlatStatusPill.forState(
              isActive: p.isActive,
              activeLabel: 'Activo',
              inactiveLabel: 'Inactivo',
            ),
          ),
        ),
      ],
      trailing: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [for (final price in prices) FlatValueText(price)],
              ),
            ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(
              Icons.edit_rounded,
              color: AppColors.cyanDark,
              size: 20,
            ),
            onPressed: widget.onEdit,
          ),
        ],
      ),
      below: _loadingMaterials
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _materials.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FlatSectionHeader('Materiales'),
                const SizedBox(height: AppSpacing.s8),
                // Lista de materiales con nombre y precio
                for (final m in _materials)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // El nombre cede espacio (y se recorta) antes de que el
                        // precio con su unidad se desborde.
                        Expanded(
                          child: Text(
                            m['name'] as String,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          'Bs. ${fixed2((m['price'] as double))} / ${m['unit']}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// Detalle simple para la vista de catálogo, sin materiales
class _ProductGridDetail extends StatelessWidget {
  final ProductModel product;
  final List<String> priceLines;

  const _ProductGridDetail({required this.product, required this.priceLines});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: AppColors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  if (product.image != null)
                    Image.file(
                      File(product.image!),
                      width: double.infinity,
                      height: 260,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  else
                    _placeholder(),
                  Positioned(
                    top: AppSpacing.s12,
                    right: AppSpacing.s12,
                    child: Material(
                      color: AppColors.surface,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.s8),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        product.description!,
                        style: textTheme.displayMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (priceLines.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s12),
                      for (final line in priceLines)
                        Text(
                          line,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 260,
      color: AppColors.surface,
      child: const Icon(
        Icons.inventory_2_rounded,
        color: AppColors.cyanDark,
        size: 60,
      ),
    );
  }
}
