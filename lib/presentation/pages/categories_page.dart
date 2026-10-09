import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../application/category_provider.dart';
import '../../application/category_catalog_filter.dart';
import '../../models/category_model.dart';
import '../widgets/catalog_filter_bar.dart';
import '../../models/default_records.dart';
import '../widgets/flat_controls.dart';
import '../widgets/flat_list.dart';
import '../widgets/flat_style.dart';
import '../widgets/protected_record_icon.dart';
import '../../theme/app_theme.dart';
import '../dialogs/category_dialog.dart';

// Categorías con el estilo plano de Inventario (ver flat_style.dart).
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
    final filter = ref.watch(categoryCatalogFilterProvider);
    final setFilter = ref.read(categoryCatalogFilterProvider.notifier);
    final visible = filter.apply(state.categories);

    return FlatStyle(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: FlatFab(
          // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
          // conviven montadas a la vez bajo el shell de navegación inferior.
          heroTag: 'categories_page_fab',
          onPressed: () => _showDialog(context, ref, null),
        ),
        body: Column(
          children: [
            // Igual que Productos: el filtro de estado arriba, alineado a la
            // derecha; debajo, el buscador a todo el ancho junto al toggle
            // lista/catálogo. Igual en ambas vistas.
            CatalogListHeader(
              chips: [
                FilterMenuChip<CategoryStatusFilter>(
                  label: switch (filter.status) {
                    CategoryStatusFilter.all => 'Todas',
                    CategoryStatusFilter.active => 'Activas',
                    CategoryStatusFilter.inactive => 'Inactivas',
                  },
                  active: filter.status != CategoryStatusFilter.all,
                  selected: filter.status,
                  options: const [
                    FilterOption(CategoryStatusFilter.all, 'Todas'),
                    FilterOption(CategoryStatusFilter.active, 'Activas'),
                    FilterOption(CategoryStatusFilter.inactive, 'Inactivas'),
                  ],
                  onSelected: (value) =>
                      setFilter.update((f) => f.copyWith(status: value)),
                ),
              ],
              search: CatalogSearchField(
                initialText: filter.query,
                hintText: 'Buscar categoría',
                onChanged: (value) =>
                    setFilter.update((f) => f.copyWith(query: value)),
              ),
              trailing: FlatViewToggle(
                isGrid: _isGrid,
                onToggle: (val) => setState(() => _isGrid = val),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.categories.isEmpty
                  ? FlatEmptyState(
                      icon: Icons.category_outlined,
                      message: 'No se registraron categorías',
                      actionLabel: 'Nueva categoría',
                      onAction: () => _showDialog(context, ref, null),
                    )
                  : visible.isEmpty
                  ? const FlatEmptyState(
                      icon: Icons.search_off_outlined,
                      message: 'Sin resultados',
                    )
                  : _isGrid
                  ? _GridView(
                      categories: visible,
                      showInactive:
                          filter.status == CategoryStatusFilter.inactive,
                    )
                  : _ListViewWidget(
                      categories: visible,
                      onEdit: (cat) => _showDialog(context, ref, cat),
                    ),
            ),
          ],
        ),
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
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FlatStyle(child: CategoryDialog(category: category)),
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
      padding: AppFlat.listWithFab,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return _CategoryRow(category: cat, onEdit: () => onEdit(cat));
      },
    );
  }
}

class _GridView extends StatelessWidget {
  final List<CategoryModel> categories;
  // El catálogo muestra solo categorías activas, salvo que el filtro de estado
  // de la lista pida las inactivas: entonces las refleja.
  final bool showInactive;

  const _GridView({required this.categories, this.showInactive = false});

  @override
  Widget build(BuildContext context) {
    final active = showInactive
        ? categories
        : categories.where((c) => c.isActive).toList();

    return GridView.builder(
      padding: AppFlat.gridWithFab,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.s16,
        mainAxisSpacing: AppSpacing.s16,
        childAspectRatio: 0.9,
      ),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final cat = active[index];
        return FlatTile(
          imagePath: cat.image,
          icon: Icons.category_outlined,
          title: cat.name,
          onTap: () => _showDetail(context, cat),
        );
      },
    );
  }

  void _showDetail(BuildContext context, CategoryModel cat) {
    showDialog(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.5),
      builder: (_) => _CategoryDetail(category: cat),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onEdit;

  const _CategoryRow({required this.category, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return FlatListRow(
      // La categoría predeterminada no se edita: sin acción al tocar.
      onTap: category.isDefault ? null : onEdit,
      leading: FlatThumb(
        imagePath: category.image,
        icon: Icons.category_outlined,
      ),
      title: category.name,
      details: [
        if (category.description != null && category.description!.isNotEmpty)
          FlatMutedText(category.description!, maxLines: 2),
        Align(
          alignment: Alignment.centerLeft,
          child: FlatStatusPill.forState(
            isActive: category.isActive,
            activeLabel: 'Activa',
            inactiveLabel: 'Inactiva',
          ),
        ),
      ],
      trailing: category.isDefault
          ? const ProtectedRecordIcon(
              message: DefaultRecords.protectedCategoryMessage,
            )
          : IconButton(
              tooltip: 'Editar',
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primaryDark,
                size: 20,
              ),
              onPressed: onEdit,
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
                            Icons.close,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
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
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (category.description != null &&
                        category.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        category.description!,
                        style: textTheme.displayMedium?.copyWith(
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
        color: AppColors.primaryDark,
        size: 60,
      ),
    );
  }
}
