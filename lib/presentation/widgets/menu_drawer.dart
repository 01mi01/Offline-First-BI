import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/login_page.dart';
import '../pages/inventario_page.dart';
import '../pages/materials_page.dart';

// Opciones del menú lateral con su ícono y etiqueta
final _menuItems = [
  {
    'module': 'inventario',
    'label': 'Inventario',
    'icon': Icons.inventory_2_outlined,
  },
  {
    'module': 'materiales',
    'label': 'Materiales',
    'icon': Icons.palette_outlined,
  },
  {'module': 'ventas', 'label': 'Ventas', 'icon': Icons.point_of_sale_outlined},
  {
    'module': 'compras',
    'label': 'Compras',
    'icon': Icons.shopping_bag_outlined,
  },
  {'module': 'clientes', 'label': 'Clientes', 'icon': Icons.people_outline},
  {
    'module': 'proveedores',
    'label': 'Proveedores',
    'icon': Icons.local_shipping_outlined,
  },
  {'module': 'eventos', 'label': 'Eventos', 'icon': Icons.event_outlined},
  {'module': 'reportes', 'label': 'Reportes', 'icon': Icons.bar_chart_outlined},
  {
    'module': 'business_intelligence',
    'label': 'Business Intelligence',
    'icon': Icons.insights_outlined,
  },
];

class MenuDrawer extends ConsumerWidget {
  const MenuDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Encabezado con nombre y rol del usuario
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //const SizedBox(height: 12),
                  Text(
                    user?.username ?? '',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user?.role ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Módulos del menú
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  return _MenuTile(
                    icon: item['icon'] as IconData,
                    label: item['label'] as String,
                    onTap: () {
                      Navigator.pop(context);
                      final module = item['module'] as String;
                      if (module == 'inventario') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InventarioPage(),
                          ),
                        );
                      } else if (module == 'materiales') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MaterialsPage(),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),

            // Botón cerrar sesión
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                leading: Icon(Icons.logout, color: AppColors.error),
                title: Text(
                  'Cerrar sesión',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  ref.read(authProvider.notifier).logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (_) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tile individual del menú
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
