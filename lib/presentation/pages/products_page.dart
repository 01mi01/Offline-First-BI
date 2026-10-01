import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_first_bi/models/product_model.dart';
import 'dart:io';
import '../../application/product_provider.dart';
import '../../application/product_catalog_filter.dart';
import '../../application/category_provider.dart';
import '../../application/material_provider.dart';
import '../../theme/app_theme.dart';
import '../dialogs/product_dialog.dart';
import '../widgets/catalog_filter_bar.dart';
import '../widgets/status_badge.dart';

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
    final selectedCategory = categories
        .where((c) => c.id == filter.categoryId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
        heroTag: 'products_page_fab',
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, null),
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      body: Column(
        children: [
          // Fila superior, alineada a la derecha: el filtro de precio (solo en la
          // vista de lista; el catálogo refleja lo elegido sin repetir el
          // control) y, a su derecha, el toggle lista/catálogo.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isGrid) ...[
                  FilterMenuChip<PriceDisplay>(
                    icon: Icons.sell_outlined,
                    label: switch (priceDisplay) {
                      PriceDisplay.both => 'Ambos',
                      PriceDisplay.a => 'Precio A',
                      PriceDisplay.b => 'Precio B',
                      PriceDisplay.none => 'Sin precio',
                    },
                    // Resaltado cuando se eligió algo distinto del valor por
                    // defecto ("Ambos").
                    active: filter.priceDisplay != PriceDisplay.both,
                    selected: priceDisplay,
                    options: const [
                      FilterOption(PriceDisplay.both, 'Ambos'),
                      FilterOption(PriceDisplay.a, 'Precio A'),
                      FilterOption(PriceDisplay.b, 'Precio B'),
                      FilterOption(PriceDisplay.none, 'Sin precio'),
                    ],
                    onSelected: (value) => setFilter.update(
                      (f) => f.copyWith(priceDisplay: value),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                ],
                _ViewToggle(
                  isGrid: _isGrid,
                  onToggle: (val) => setState(() => _isGrid = val),
                ),
              ],
            ),
          ),
          // Fila de abajo: el buscador (nombre o descripción) comparte el ancho
          // con el filtro de categoría.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Row(
              children: [
                Expanded(
                  child: CatalogSearchField(
                    initialText: filter.query,
                    hintText: 'Buscar producto',
                    onChanged: (value) => setFilter.update(
                      (f) => f.copyWith(query: value),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                FilterMenuChip<int?>(
                  icon: Icons.category_outlined,
                  maxLabelWidth: 110,
                  label: selectedCategory?.name ?? 'Categoría',
                  active: filter.categoryId != null,
                  selected: filter.categoryId,
                  options: [
                    const FilterOption<int?>(null, 'Todas las categorías'),
                    for (final c in categories)
                      FilterOption<int?>(c.id, c.name),
                  ],
                  onSelected: (id) => setFilter.update(
                    (f) => id == null
                        ? f.copyWith(clearCategory: true)
                        : f.copyWith(categoryId: id),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.products.isEmpty
                ? Center(
                    child: Text(
                      'No se registraron productos',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : visible.isEmpty
                ? Center(
                    child: Text(
                      'Sin resultados',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : _isGrid
                ? _GridView(products: visible, priceDisplay: priceDisplay)
                : _ListViewWidget(
                    products: visible,
                    priceDisplay: priceDisplay,
                    onEdit: (p) => _showDialog(context, p),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, ProductModel? product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProductDialog(product: product),
    );
  }
}

// Toggle lista/catálogo
class _ViewToggle extends StatelessWidget {
  final bool isGrid;
  final ValueChanged<bool> onToggle;

  const _ViewToggle({required this.isGrid, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ToggleBtn(
            icon: Icons.list,
            active: !isGrid,
            onTap: () => onToggle(false),
          ),
          _ToggleBtn(
            icon: Icons.grid_view_rounded,
            active: isGrid,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Tamaño del botón del toggle
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s10,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? AppColors.surface : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// Vista de lista — muestra todos los campos incluyendo materiales
class _ListViewWidget extends ConsumerWidget {
  final List<ProductModel> products;
  final ValueChanged<ProductModel> onEdit;
  // Qué precios muestra cada tarjeta (mismo filtro que el catálogo).
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
      padding: AppSpacing.listWithFab,
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final categoryName =
            categories
                .where((c) => c.id == p.categoryId)
                .map((c) => c.name)
                .firstOrNull ??
            'Sin categoría';
        return _ProductCard(
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
  // Qué precio muestran las tarjetas (y el detalle) de todo el catálogo.
  final PriceDisplay priceDisplay;

  const _GridView({required this.products, required this.priceDisplay});

  @override
  Widget build(BuildContext context) {
    final active = products.where((p) => p.isActive).toList();

    return GridView.builder(
      padding: AppSpacing.listWithFab,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.80,
      ),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final p = active[index];
        return _GridCard(
          product: p,
          priceLines: _catalogPriceLines(p, priceDisplay),
          onTap: () => _showDetail(context, p),
        );
      },
    );
  }

  void _showDetail(BuildContext context, ProductModel p) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => _ProductGridDetail(
        product: p,
        priceLines: _catalogPriceLines(p, priceDisplay, detailed: true),
      ),
    );
  }
}

// Líneas de precio del catálogo según el filtro de precio. Con un solo precio
// elegido la línea es solo "Precio: Bs. X", sin A/B; con "Ambos" hace falta
// distinguirlos, así que llevan etiqueta ("A:"/"B:" en la tarjeta, "Precio
// A:"/"Precio B:" en el detalle). Con "Sin precio" no hay líneas.
List<String> _catalogPriceLines(
  ProductModel p,
  PriceDisplay display, {
  bool detailed = false,
}) {
  String bs(double v) => 'Bs. ${v.toStringAsFixed(2)}';
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

// Tarjeta para la vista de lista con materiales vinculados
class _ProductCard extends ConsumerStatefulWidget {
  final ProductModel product;
  final String categoryName;
  final PriceDisplay priceDisplay;
  final VoidCallback onEdit;

  const _ProductCard({
    required this.product,
    required this.categoryName,
    required this.priceDisplay,
    required this.onEdit,
  });

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
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
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del producto
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.product.image != null
                    ? Image.file(
                        File(widget.product.image!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre y categoría
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.product.name,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.categoryName,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (widget.product.description != null &&
                        widget.product.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        widget.product.description!,
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s6),
                    // Precio A y Precio B, lado a lado como dos píldoras (mismas
                    // etiquetas cortas "A:" / "B:" que la vista de catálogo). Cada
                    // una es indivisible: si no caben juntas, la segunda pasa a
                    // la fila de abajo, nunca se parte por dentro.
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s4,
                      children: [
                        // Solo los precios que pide el filtro de precio (con
                        // "Sin precio" no hay ninguna píldora).
                        for (final price in [
                          if (widget.priceDisplay == PriceDisplay.a ||
                              widget.priceDisplay == PriceDisplay.both)
                            'A: Bs. ${widget.product.priceA.toStringAsFixed(2)}',
                          if (widget.priceDisplay == PriceDisplay.b ||
                              widget.priceDisplay == PriceDisplay.both)
                            'B: Bs. ${widget.product.priceB.toStringAsFixed(2)}',
                        ])
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              price,
                              softWrap: false,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    if (widget.product.productionCost != null) ...[
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Costo: Bs. ${widget.product.productionCost!.toStringAsFixed(2)}',
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      'Stock: ${widget.product.stock}',
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    StatusBadge.forState(
isActive: widget.product.isActive,
activeLabel: 'Activo',
inactiveLabel: 'Inactivo',
),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: widget.onEdit,
              ),
            ],
          ),

          // Materiales usados con nombre y precio
          if (_loadingMaterials) ...[
            const SizedBox(height: AppSpacing.s8),
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else if (_materials.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Materiales',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            // Lista de materiales con nombre y precio
            ..._materials.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // El nombre cede espacio (y se recorta) antes de que el
                    // precio con su unidad se desborde.
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Flexible(
                            child: Text(
                              m['name'] as String,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      'Bs. ${(m['price'] as double).toStringAsFixed(2)} / ${m['unit']}',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.primary,
        size: 28,
      ),
    );
  }
}

// Tarjeta para la vista de catálogo
class _GridCard extends StatelessWidget {
  final ProductModel product;
  final List<String> priceLines;
  final VoidCallback onTap;

  const _GridCard({
    required this.product,
    required this.priceLines,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: product.image != null
                    ? Image.file(
                        File(product.image!),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _gridPlaceholder(),
                      )
                    : _gridPlaceholder(),
              ),
            ),
            // Nombre y precio
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (priceLines.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s2),
                    for (final line in priceLines)
                      Text(
                        line,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridPlaceholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.07),
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: AppColors.primary,
          size: 40,
        ),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.s6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: AppColors.surface,
                          size: 18,
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        product.description!,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                      ),
                    ],
                    if (priceLines.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s4),
                      for (final line in priceLines)
                        Text(
                          line,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
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
        Icons.inventory_2_outlined,
        color: AppColors.primary,
        size: 60,
      ),
    );
  }
}
