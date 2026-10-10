import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/purchases_page.dart';
import '../pages/sales_page.dart';
import '../widgets/ios_group.dart';
import '../widgets/screen_header.dart';
import '../widgets/profile_button.dart';
import 'nav_resolver.dart';
import '../widgets/app_list_row.dart';

class VentasComprasTabPage extends ConsumerWidget {
  const VentasComprasTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readableModules = ref.watch(readableModulesProvider);

    return readableModules.when(
      data: (modules) {
        final cards = resolveVentasComprasCards(modules);

        return ScreenScaffold(
          title: 'Ventas y Compras',
          actions: const [ProfileButton()],
          body: cards.isEmpty
              ? const IosEmptyState(
                  icon: Icons.point_of_sale_rounded,
                  title: 'No tienes acceso a ventas ni compras',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppHeader.sidePadding, 0, AppHeader.sidePadding, AppSpacing.s16),
                  children: [
                    AppListCard(
                      children: [
                        for (var i = 0; i < cards.length; i++)
                          AppListRow(
                            icon: _iconFor(cards[i]),
                            iconColor: AppColors.chartColor1,
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
      return Icons.point_of_sale_rounded;
    case VentasComprasCard.compras:
      return Icons.shopping_bag_rounded;
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
