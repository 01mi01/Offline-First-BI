import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../application/category_provider.dart';
import '../../models/category_model.dart';
import '../../models/default_records.dart';
import '../widgets/protected_record_icon.dart';
import '../../theme/app_theme.dart';
import '../dialogs/category_dialog.dart';
import '../widgets/status_badge.dart';

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
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
        heroTag: 'categories_page_fab',
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, ref, null),
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s16,
              AppSpacing.s4,
            ),
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
                      'No se registraron categorías',
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
      useSafeArea: true,
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

class _ListViewWidget extends StatelessWidget {
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onEdit;

  const _ListViewWidget({required this.categories, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: AppSpacing.listWithFab,
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
      padding: AppSpacing.listWithFab,
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
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
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
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (category.description != null &&
                    category.description!.isNotEmpty)
                  Text(
                    category.description!,
                    style: Theme.of(
                      context,
                    ).textTheme.displaySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.s4),
                StatusBadge.forState(
isActive: category.isActive,
activeLabel: 'Activa',
inactiveLabel: 'Inactiva',
),
              ],
            ),
          ),
          if (category.isDefault)
            const ProtectedRecordIcon(
              message: DefaultRecords.protectedCategoryMessage,
            )
          else
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
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Text(
                category.name,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
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

// Detalle de la categoría
class _CategoryDetail extends StatelessWidget {
  final CategoryModel category;

  const _CategoryDetail({required this.category});

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

              // Nombre y descripción
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (category.description != null &&
                        category.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        category.description!,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: AppColors.textSecondary,
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
      child: const Icon(
        Icons.category_outlined,
        color: AppColors.primary,
        size: 60,
      ),
    );
  }
}
