import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/categories_page.dart';
import '../pages/materials_page.dart';
import '../pages/products_page.dart';
import '../widgets/screen_header.dart';
import '../widgets/flat_list.dart';
import '../widgets/flat_style.dart';
import 'nav_resolver.dart';
import '../widgets/profile_button.dart';
import '../widgets/app_list_row.dart';

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
          child: ScreenScaffold(
            title: 'Inventario',
            actions: const [ProfileButton()],
            body: cards.isEmpty
                ? const FlatEmptyState(
                    icon: Icons.inventory_2_rounded,
                    message: 'No tienes acceso a ningún módulo de inventario',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppHeader.sidePadding, 0, AppHeader.sidePadding, AppSpacing.s16),
                    children: [
                      AppListCard(
                        children: [
                          for (var i = 0; i < cards.length; i++)
                            AppListRow(
                              icon: _iconFor(cards[i]),
                              iconColor: AppColors.cyanDark,
                              title: _labelFor(cards[i]),
                              chevron: true,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _pageFor(cards[i]),
                                ),
                              ),
                            ),
                        ],
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
      return Icons.inventory_2_rounded;
    case InventarioCard.categorias:
      return Icons.category_rounded;
    case InventarioCard.materiales:
      return Icons.palette_rounded;
  }
}

Widget _pageFor(InventarioCard card) {
  switch (card) {
    case InventarioCard.productos:
      return const ProductsScreen();
    case InventarioCard.categorias:
      return const CategoriesScreen();
    case InventarioCard.materiales:
      return const MaterialsPage();
  }
}

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) => const FlatStyle(
    child: ScreenScaffold(
      title: 'Productos',
      actions: [ProfileButton()],
      body: ProductsPage(),
    ),
  );
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) => const FlatStyle(
    child: ScreenScaffold(
      title: 'Categorías',
      actions: [ProfileButton()],
      body: CategoriesPage(),
    ),
  );
}
