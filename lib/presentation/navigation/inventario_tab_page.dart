import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/categories_page.dart';
import '../pages/materials_page.dart';
import '../pages/products_page.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/flat_list.dart';
import '../widgets/flat_style.dart';
import 'nav_resolver.dart';
import '../widgets/profile_button.dart';

// Tab "Inventario" de la navegación inferior: pantalla de aterrizaje con
// tarjetas (Productos, Categorías, Materiales), mostrando solo las que el
// usuario puede leer según su propio módulo (inventario / materiales de
// forma independiente). "Uso" vive dentro de la propia página de
// Materiales, como siempre.
class InventarioTabPage extends ConsumerWidget {
  const InventarioTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readableModules = ref.watch(readableModulesProvider);

    return readableModules.when(
      data: (modules) {
        final cards = resolveInventarioCards(modules);

        return FlatStyle(
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: const CustomAppBar(
              title: 'Inventario',
              actions: [ProfileButton()],
            ),
            body: cards.isEmpty
                ? const FlatEmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: 'No tienes acceso a ningún módulo de inventario',
                  )
                : ListView(
                    padding: const EdgeInsets.only(top: AppSpacing.s8),
                    children: [
                      for (final card in cards)
                        FlatListRow(
                          leading: FlatThumb(icon: _iconFor(card)),
                          title: _labelFor(card),
                          trailing: const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.s14),
                            child: Icon(
                              Icons.chevron_right,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => _pageFor(card)),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('No se pudo cargar Inventario')),
      ),
    );
  }
}

String _labelFor(InventarioCard card) {
  switch (card) {
    case InventarioCard.productos:
      return 'Productos';
    case InventarioCard.categorias:
      return 'Categorías';
    case InventarioCard.materiales:
      return 'Materiales';
  }
}

IconData _iconFor(InventarioCard card) {
  switch (card) {
    case InventarioCard.productos:
      return Icons.inventory_2_outlined;
    case InventarioCard.categorias:
      return Icons.category_outlined;
    case InventarioCard.materiales:
      return Icons.palette_outlined;
  }
}

// Productos y Categorías son cuerpos "desnudos" (sin AppBar propia) porque
// también se usan embebidos en InventarioPage; aquí se les da su propia
// AppBar con back, igual que a Materiales.
Widget _pageFor(InventarioCard card) {
  switch (card) {
    case InventarioCard.productos:
      return const FlatStyle(
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: CustomAppBar(title: 'Productos', showBack: true),
          body: ProductsPage(),
        ),
      );
    case InventarioCard.categorias:
      return const FlatStyle(
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: CustomAppBar(title: 'Categorías', showBack: true),
          body: CategoriesPage(),
        ),
      );
    case InventarioCard.materiales:
      return const MaterialsPage();
  }
}
