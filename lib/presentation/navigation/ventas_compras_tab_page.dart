import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/purchases_page.dart';
import '../pages/sales_page.dart';
import '../widgets/ios_group.dart';
import '../widgets/ios_scaffold.dart';
import '../widgets/profile_button.dart';
import 'nav_resolver.dart';

class VentasComprasTabPage extends ConsumerWidget {
  const VentasComprasTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readableModules = ref.watch(readableModulesProvider);

    return readableModules.when(
      data: (modules) {
        final cards = resolveVentasComprasCards(modules);

        return IosLargeTitleScaffold(
          title: 'Ventas y Compras',
          actions: const [ProfileButton()],
          slivers: [
            SliverToBoxAdapter(
              child: cards.isEmpty
                  ? const IosEmptyState(
                      icon: Icons.point_of_sale_outlined,
                      title: 'No tienes acceso a ventas ni compras',
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s8),
                      child: IosSection(
                        dividerIndent: AppIos.dividerIndentWithTile,
                        children: [
                          for (final card in cards)
                            IosRow(
                              leading: IosTile(
                                icon: _iconFor(card),
                                color: _colorFor(card),
                                iconColor: card == VentasComprasCard.compras
                                    ? AppColors.onPrimary
                                    : AppColors.surface,
                              ),
                              title: _labelFor(card),
                              chevron: true,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _pageFor(card),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
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

Color _colorFor(VentasComprasCard card) {
  switch (card) {
    case VentasComprasCard.ventas:
      return AppColors.primaryDark;
    case VentasComprasCard.compras:
      return AppColors.accent;
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
