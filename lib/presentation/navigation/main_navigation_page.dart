import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/home_page.dart';
import 'contactos_eventos_tab_page.dart';
import 'inventario_tab_page.dart';
import 'nav_resolver.dart';
import 'reportes_bi_tab_page.dart';
import 'ventas_compras_tab_page.dart';

String labelForGroup(NavGroupId group) {
  switch (group) {
    case NavGroupId.home:
      return 'Inicio';
    case NavGroupId.inventario:
      return 'Inventario';
    case NavGroupId.ventasCompras:
      return 'Ventas';
    case NavGroupId.contactos:
      return 'Contactos';
    case NavGroupId.reportes:
      return 'Reportes';
  }
}

IconData iconForGroup(NavGroupId group) {
  switch (group) {
    case NavGroupId.home:
      return Icons.home_outlined;
    case NavGroupId.inventario:
      return Icons.inventory_2_outlined;
    case NavGroupId.ventasCompras:
      return Icons.shopping_cart_outlined;
    case NavGroupId.contactos:
      return Icons.people_outline;
    case NavGroupId.reportes:
      return Icons.bar_chart_outlined;
  }
}

Widget bodyForGroup(NavGroupId group) {
  switch (group) {
    case NavGroupId.home:
      return const HomePage();
    case NavGroupId.inventario:
      return const InventarioTabPage();
    case NavGroupId.ventasCompras:
      return const VentasComprasTabPage();
    case NavGroupId.contactos:
      return const ContactosEventosTabPage();
    case NavGroupId.reportes:
      return const ReportesBiTabPage();
  }
}

// Shell de navegación inferior que reemplaza el drawer lateral. Los tabs
// visibles se resuelven en tiempo de ejecución a partir de los módulos a
// los que el usuario tiene acceso, no de una lista fija: por eso todo el
// árbol se construye desde las listas resueltas por nav_resolver.dart en
// cada build.
class MainNavigationPage extends ConsumerStatefulWidget {
  const MainNavigationPage({super.key});

  @override
  ConsumerState<MainNavigationPage> createState() =>
      _MainNavigationPageState();
}

class _MainNavigationPageState extends ConsumerState<MainNavigationPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final readableModulesAsync = ref.watch(readableModulesProvider);

    return readableModulesAsync.when(
      data: (readableModules) {
        final groups = resolveVisibleGroups(readableModules);
        final index = _selectedIndex >= groups.length ? 0 : _selectedIndex;

        return Scaffold(
          backgroundColor: AppColors.background,
          // El shell en sí no tiene campos de texto propios (los diálogos con
          // formularios se abren en rutas separadas), así que no necesita
          // encogerse por el teclado. Sin esto, en un arranque en frío el
          // engine puede reportar momentáneamente un inset de teclado
          // incorrecto (por `adjustResize` en el manifest de Android),
          // haciendo que el bottomNavigationBar se colapse/oculte hasta que
          // la app se reabre y el inset se recalcula correctamente.
          resizeToAvoidBottomInset: false,
          body: IndexedStack(
            index: index,
            children: groups.map(bodyForGroup).toList(),
          ),
          bottomNavigationBar: _AdaptiveBottomBar(
            groups: groups,
            selectedIndex: index,
            onSelect: (i) => setState(() => _selectedIndex = i),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('No se pudo cargar la aplicación')),
      ),
    );
  }
}

class _AdaptiveBottomBar extends StatelessWidget {
  final List<NavGroupId> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _AdaptiveBottomBar({
    required this.groups,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Si hay más tabs que el límite, los que exceden se agrupan en "Más".
    final overflow = groups.length > maxVisibleNavTabs;
    final visibleGroups = overflow
        ? groups.sublist(0, maxVisibleNavTabs - 1)
        : groups;
    final overflowGroups = overflow
        ? groups.sublist(maxVisibleNavTabs - 1)
        : const <NavGroupId>[];

    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            for (final group in visibleGroups)
              Expanded(
                child: _NavTabButton(
                  label: labelForGroup(group),
                  icon: iconForGroup(group),
                  selected: groups.indexOf(group) == selectedIndex,
                  onTap: () => onSelect(groups.indexOf(group)),
                ),
              ),
            if (overflow)
              Expanded(
                child: _NavTabButton(
                  label: 'Más',
                  icon: Icons.more_horiz,
                  selected: overflowGroups.contains(groups[selectedIndex]),
                  onTap: () => _showOverflowSheet(context, overflowGroups),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOverflowSheet(BuildContext context, List<NavGroupId> overflowGroups) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: overflowGroups
              .map(
                (group) => ListTile(
                  leading: Icon(iconForGroup(group), color: AppColors.primaryDark),
                  title: Text(labelForGroup(group)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onSelect(groups.indexOf(group));
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDark : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
