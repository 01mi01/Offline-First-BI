import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../application/category_provider.dart';
import '../../models/category_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/category_dialog.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  bool _isGrid = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, ref, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
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
                : state.categories.isEmpty
                ? Center(
                    child: Text(
                      'No hay categorías registradas',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : _isGrid
                ? _GridView(categories: state.categories)
                : _ListViewWidget(
                    categories: state.categories,
                    onEdit: (cat) => _showDialog(context, ref, cat),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDialog(
    BuildContext context,
    WidgetRef ref,
    CategoryModel? category,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CategoryDialog(category: category),
    );
  }
}

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
          color: active ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ListViewWidget extends StatelessWidget {
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onEdit;

  const _ListViewWidget({required this.categories, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return _CategoryCard(category: cat, onEdit: () => onEdit(cat));
      },
    );
  }
}

class _GridView extends StatelessWidget {
  final List<CategoryModel> categories;

  const _GridView({required this.categories});

  @override
  Widget build(BuildContext context) {
    // Solo muestra categorías activas en la vista catálogo
    final active = categories.where((c) => c.isActive).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final cat = active[index];
        return _GridCard(category: cat, onTap: () => _showDetail(context, cat));
      },
    );
  }

  void _showDetail(BuildContext context, CategoryModel cat) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => _CategoryDetail(category: cat),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onEdit;

  const _CategoryCard({required this.category, required this.onEdit});

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
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: category.image != null
                ? Image.file(
                    File(category.image!),
                    width: 56,
                    height: 56,
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
                Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (category.description != null &&
                    category.description!.isNotEmpty)
                  Text(
                    category.description!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: category.isActive
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category.isActive ? 'Activa' : 'Inactiva',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: category.isActive
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
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.category_outlined,
        color: AppColors.primary,
        size: 28,
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _GridCard({required this.category, required this.onTap});

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
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: category.image != null
                    ? Image.file(
                        File(category.image!),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _gridPlaceholder(),
                      )
                    : _gridPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                category.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
          Icons.category_outlined,
          color: AppColors.primary,
          size: 40,
        ),
      ),
    );
  }
}

class _CategoryDetail extends StatelessWidget {
  final CategoryModel category;

  const _CategoryDetail({required this.category});

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
              // Imagen o placeholder
              Stack(
                children: [
                  if (category.image != null)
                    Image.file(
                      File(category.image!),
                      width: double.infinity,
                      height: 260,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  else
                    _placeholder(),

                  // Botón cerrar en la esquina superior derecha
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
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Nombre y descripción
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (category.description != null &&
                        category.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        category.description!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.5,
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
      child: const Icon(Icons.category_outlined,
          color: AppColors.primary, size: 60),
    );
  }
}
