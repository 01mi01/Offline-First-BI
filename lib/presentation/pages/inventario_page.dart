import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';
import 'categories_page.dart';
import 'products_page.dart';

class InventarioPage extends ConsumerWidget {
  const InventarioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: 'Inventario',
          showBack: true,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Productos'),
              Tab(text: 'Categorías'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            const ProductsPage(),
            CategoriesPage(),
          ],
        ),
      ),
    );
  }
}