import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Controles de estilo plano (ver flat_style.dart): alternador compacto de vista
// y pestañas de texto con un subrayado corto.

// Alternador lista / catálogo: dos botones de icono dentro de una píldora
// neutra; el activo es una píldora blanca con el icono navy.
class FlatViewToggle extends StatelessWidget {
  final bool isGrid;
  final ValueChanged<bool> onToggle;

  const FlatViewToggle({super.key, required this.isGrid, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            icon: Icons.list,
            tooltip: 'Vista de lista',
            active: !isGrid,
            onTap: () => onToggle(false),
          ),
          _Segment(
            icon: Icons.grid_view_rounded,
            tooltip: 'Vista de catálogo',
            active: isGrid,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _Segment({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
          child: SizedBox(
            width: AppFlat.minTap,
            height: AppFlat.minTap - AppSpacing.s4,
            child: Icon(
              icon,
              size: 20,
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// Pestañas de texto: la activa en navy y negrita con un subrayado corto cian;
// las demás en gris. Va en `bottom` de una AppBar.
class FlatTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<String> labels;

  const FlatTabBar({super.key, required this.labels});

  @override
  Size get preferredSize => const Size.fromHeight(AppFlat.minTap);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    return TabBar(
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: style,
      unselectedLabelStyle: style?.copyWith(fontWeight: FontWeight.w500),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(width: 3, color: AppColors.primaryDark),
        borderRadius: BorderRadius.all(Radius.circular(3)),
        insets: EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.hairline,
      dividerHeight: 1,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      tabs: [for (final label in labels) Tab(text: label)],
    );
  }
}
