import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../application/module_permission_provider.dart';
import '../../application/sale_provider.dart';
import '../../application/purchase_provider.dart';
import '../../application/product_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';
import '../pages/sales_page.dart';
import '../pages/purchases_page.dart';
import '../pages/inventario_page.dart';
import '../pages/reports_page.dart';
import '../../config/date_formatters.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    // Las ventas canceladas no cuentan como ingreso ni como "últimas ventas".
    final sales = ref
        .watch(saleProvider)
        .sales
        .where((s) => !s.isCanceled)
        .toList();
    final purchases = ref.watch(purchaseProvider).purchases;
    final products = ref.watch(productProvider).products;
    final readableModules = ref.watch(readableModulesProvider).valueOrNull ?? [];

    // Métricas rápidas
    final totalIngresos = sales.fold(0.0, (sum, s) => sum + s.finalAmount);
    final totalGastos = purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
    final productosActivos = products.where((p) => p.isActive).length;
    final stockBajo = products.where((p) => p.isActive && p.stock <= 3).length;

    // Tarjetas de acceso rápido, solo para módulos que el usuario puede leer
    final quickAccessCards = <_QuickAccessCard>[
      if (readableModules.contains('ventas'))
        _QuickAccessCard(
          label: 'Ventas',
          icon: Icons.point_of_sale_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SalesPage()),
          ),
        ),
      if (readableModules.contains('compras'))
        _QuickAccessCard(
          label: 'Compras',
          icon: Icons.shopping_bag_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PurchasesPage()),
          ),
        ),
      if (readableModules.contains('inventario'))
        _QuickAccessCard(
          label: 'Inventario',
          icon: Icons.inventory_2_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InventarioPage()),
          ),
        ),
      if (readableModules.contains('reportes'))
        _QuickAccessCard(
          label: 'Reportes',
          icon: Icons.bar_chart_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsPage()),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Inicio'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saludo
            Text(
              'Hola, ${user?.username ?? ""}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s32),

            // Panel de resumen
            Text(
              'Panel de resumen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Métricas
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Ingresos',
                    value: 'Bs. ${totalIngresos.toStringAsFixed(2)}',
                    icon: Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: _MetricCard(
                    label: 'Gastos',
                    value: 'Bs. ${totalGastos.toStringAsFixed(2)}',
                    icon: Icons.trending_down_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Productos activos',
                    value: '$productosActivos',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: _MetricCard(
                    label: 'Stock bajo',
                    value: '$stockBajo',
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s32),

            // Acceso rápido — solo se muestra si hay algo que mostrar, y
            // solo con las tarjetas de los módulos accesibles (reflow, sin
            // relleno para simular tarjetas que el usuario no tiene).
            if (quickAccessCards.isNotEmpty) ...[
              Text(
                'Acceso rápido',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: quickAccessCards,
              ),
              const SizedBox(height: AppSpacing.s32),
            ],

            // Últimas ventas
            if (sales.isNotEmpty) ...[
              Text(
                'Últimas ventas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              ...sales
                  .take(3)
                  .map(
                    (s) => Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDate(s.date),
                            style: Theme.of(
                              context,
                            ).textTheme.displaySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Bs. ${s.finalAmount.toStringAsFixed(2)}',
                            style: Theme.of(
                              context,
                            ).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => formatDateTime(date);
}

// Tarjeta de métricaS
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// Tarjeta de acceso rápido
class _QuickAccessCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
