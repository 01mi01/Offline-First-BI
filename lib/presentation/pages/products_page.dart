import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_first_bi/models/product_model.dart';
import 'dart:io';
import '../../application/product_provider.dart';
import '../../application/category_provider.dart';
import '../../application/material_provider.dart';
import '../../theme/app_theme.dart';
import '../dialogs/product_dialog.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, null),
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      body: Column(
        children: [
          // Barra de toggle lista/catálogo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ViewToggle(
                  isGrid: _isGrid,
                  onToggle: (val) => setState(() => _isGrid = val),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.products.isEmpty
                ? Center(
                    child: Text(
                      'No hay productos registrados',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : _isGrid
                ? _GridView(products: state.products)
                : _ListViewWidget(
                    products: state.products,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  const _ListViewWidget({required this.products, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider).categories;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
          onEdit: () => onEdit(p),
        );
      },
    );
  }
}

// Vista de catálogo — solo activos, imagen, nombre, precio
class _GridView extends StatelessWidget {
  final List<ProductModel> products;

  const _GridView({required this.products});

  @override
  Widget build(BuildContext context) {
    final active = products.where((p) => p.isActive).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.80,
      ),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final p = active[index];
        return _GridCard(product: p, onTap: () => _showDetail(context, p));
      },
    );
  }

  void _showDetail(BuildContext context, ProductModel p) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => _ProductGridDetail(product: p),
    );
  }
}

// Tarjeta para la vista de lista con materiales vinculados
class _ProductCard extends ConsumerStatefulWidget {
  final ProductModel product;
  final String categoryName;
  final VoidCallback onEdit;

  const _ProductCard({
    required this.product,
    required this.categoryName,
    required this.onEdit,
  });

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  List<String> _materialNames = [];
  bool _loadingMaterials = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  // Carga nombres únicos de materiales usados en este producto
  Future<void> _loadMaterials() async {
    final names = await ref
        .read(materialProvider.notifier)
        .getUniqueMaterialNamesForProduct(widget.product.id);
    if (mounted) {
      setState(() {
        _materialNames = names;
        _loadingMaterials = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              const SizedBox(width: 16),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.categoryName,
                            style: TextStyle(
                              fontSize: 11,
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
                      const SizedBox(height: 4),
                      Text(
                        widget.product.description!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Precio de venta: Bs. ${widget.product.salePrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (widget.product.productionCost != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Costo: Bs. ${widget.product.productionCost!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Stock: ${widget.product.stock}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.product.isActive
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.product.isActive ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.product.isActive
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
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

          // Materiales usados — solo nombres, sin cantidad
          if (_loadingMaterials) ...[
            const SizedBox(height: 8),
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else if (_materialNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            const Text(
              'Materiales',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _materialNames
                  .map(
                    (name) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
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
  final VoidCallback onTap;

  const _GridCard({required this.product, required this.onTap});

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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bs. ${product.salePrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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

  const _ProductGridDetail({required this.product});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
                        padding: const EdgeInsets.all(6),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.description!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Bs. ${product.salePrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
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
