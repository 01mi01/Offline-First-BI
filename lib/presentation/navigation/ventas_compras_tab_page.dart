import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/purchases_page.dart';
import '../pages/sales_page.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/landing_card.dart';
import 'nav_resolver.dart';

// Tab "Ventas y Compras" de la navegación inferior: pantalla de aterrizaje
// con tarjetas (Ventas, Compras), mostrando solo las que el usuario puede
// leer, con el mismo patrón visual que Inventario/Contactos/Reportes.
class VentasComprasTabPage extends ConsumerWidget {
  const VentasComprasTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readableModules = ref.watch(readableModulesProvider);

    return readableModules.when(
      data: (modules) {
        final cards = resolveVentasComprasCards(modules);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const CustomAppBar(title: 'Ventas y Compras'),
          body: cards.isEmpty
              ? Center(
                  child: Text(
                    'No tienes acceso a ventas ni compras',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    children: cards
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s12,
                            ),
                            child: LandingCard(
                              label: _labelFor(card),
                              icon: _iconFor(card),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _pageFor(card),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('No se pudo cargar Ventas y Compras')),
      ),
    );
  }
}

String _labelFor(VentasComprasCard card) {
  switch (card) {
    case VentasComprasCard.ventas:
      return 'Ventas';
    case VentasComprasCard.compras:
      return 'Compras';
  }
}

IconData _iconFor(VentasComprasCard card) {
  switch (card) {
    case VentasComprasCard.ventas:
      return Icons.point_of_sale_outlined;
    case VentasComprasCard.compras:
      return Icons.shopping_bag_outlined;
  }
}

Widget _pageFor(VentasComprasCard card) {
  switch (card) {
    case VentasComprasCard.ventas:
      return const SalesPage();
    case VentasComprasCard.compras:
      return const PurchasesPage();
  }
}
