import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/category_provider.dart';
import '../../application/category_catalog_filter.dart';
import '../../application/record_search.dart';
import '../../models/category_model.dart';
import '../../models/default_records.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/flat_controls.dart';
import '../widgets/flat_list.dart';
import '../widgets/protected_record_icon.dart';
import '../widgets/record_detail.dart';
import '../widgets/record_list.dart';
import '../widgets/status_badge.dart';
import '../../theme/app_theme.dart';
import '../dialogs/category_dialog.dart';
import '../widgets/app_controls.dart';
import '../widgets/filter_panel.dart';
import '../widgets/empty_state.dart';

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
    final visible = filter.apply(
      state.categories,
      index: ref.watch(categorySearchIndexProvider),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FlatFab(
        heroTag: 'categories_page_fab',
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
              hintText: 'Buscar categoría',
              onChanged: (value) =>
                  setFilter.update((f) => f.copyWith(query: value)),
            ),
            fields: [
              FilterDropdown<CategoryStatusFilter>(
                label: 'Estado',
                options: const [
                  FilterOption(CategoryStatusFilter.all, 'Todas'),
                  FilterOption(CategoryStatusFilter.active, 'Activas'),
                  FilterOption(CategoryStatusFilter.inactive, 'Inactivas'),
                ],
                current: filter.status,
                defaultValue: CategoryStatusFilter.all,
                onApply: (value) =>
                    setFilter.update((f) => f.copyWith(status: value)),
              ),
            ],
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.categories.isEmpty
                ? Center(
                    child: AppEmptyState.list(
                      plural: 'categorías',
                      icon: Icons.category_rounded,
                      actionLabel: 'Nueva categoría',
                      onAction: () => _showForm(context, null),
                    ),
                  )
                : visible.isEmpty
                ? const SingleChildScrollView(
                    child: AppEmptyState.noMatch(),
                  )
                : _isGrid
                ? _GridView(categories: visible)
                : _ListViewWidget(categories: visible),
          ),
        ],
      ),
    );
  }
}

void _showForm(BuildContext context, CategoryModel? category) {
  showFormSheet<void>(
    context,
    builder: (_) => CategoryDialog(category: category),
  );
}

void _showDetail(BuildContext context, CategoryModel category) {
  final description = category.description;
  showAppSheet<void>(
    context,
    builder: (_) => RecordDetailSheet(
      title: 'Detalle de la categoría',
      onEdit: category.isDefault ? null : () => _showForm(context, category),
      children: [
        RecordHeadline(
          title: category.name,
          thumb: RecordThumb(
            imagePath: category.image,
            icon: Icons.category_rounded,
            size: 120,
          ),
          pill: _pill(category),
          note: category.isDefault
              ? DefaultRecords.protectedCategoryMessage
              : null,
        ),
        AppSection(
          children: [
            AppValueRow(
              label: 'Descripción',
              value: description == null || description.isEmpty
                  ? 'Sin descripción'
                  : description,
            ),
          ],
        ),
      ],
    ),
  );
}

StatusBadge _pill(CategoryModel category) => StatusBadge.forState(
  isActive: category.isActive,
  activeLabel: 'Activa',
  inactiveLabel: 'Inactiva',
);

class _ListViewWidget extends StatelessWidget {
  final List<CategoryModel> categories;

  const _ListViewWidget({required this.categories});

  @override
  Widget build(BuildContext context) {
    return AppGroupListView(
      dividerIndent: AppMetrics.dividerIndentWithThumb,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return _CategoryRow(
          category: cat,
          onTap: () => _showDetail(context, cat),
        );
      },
    );
  }
}

class _GridView extends StatelessWidget {
  final List<CategoryModel> categories;

  const _GridView({required this.categories});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: AppFlat.gridWithFab,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.s16,
        mainAxisSpacing: AppSpacing.s16,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return FlatTile(
          imagePath: cat.image,
          icon: Icons.category_rounded,
          title: cat.name,
          pill: cat.isActive ? null : _pill(cat),
          onTap: () => showCatalogPopup(
            context,
            title: cat.name,
            icon: Icons.category_rounded,
            imagePath: cat.image,
            description: cat.description,
          ),
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _CategoryRow({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final description = category.description;
    return RecordRow(
      onTap: onTap,
      thumb: RecordThumb(
        imagePath: category.image,
        icon: Icons.category_rounded,
      ),
      title: category.name,
      details: [
        if (description != null && description.isNotEmpty)
          RecordLine(description, maxLines: 2),
      ],
      pill: _pill(category),
      trailing: category.isDefault
          ? const ProtectedRecordIcon(
              message: DefaultRecords.protectedCategoryMessage,
            )
          : null,
    );
  }
}
