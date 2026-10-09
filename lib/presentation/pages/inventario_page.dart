import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/flat_controls.dart';
import '../widgets/flat_style.dart';
import 'categories_page.dart';
import 'products_page.dart';

class InventarioPage extends ConsumerWidget {
  const InventarioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FlatStyle(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: const CustomAppBar(
            title: 'Inventario',
            showBack: true,
            bottom: FlatTabBar(labels: ['Productos', 'Categorías']),
          ),
          body: const TabBarView(children: [ProductsPage(), CategoriesPage()]),
        ),
      ),
    );
  }
}
