import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';

// Sección agrupada: encabezado gris arriba, filas dentro de un bloque blanco
// redondeado con separadores finos con sangría, y nota al pie.
class AppSection extends StatelessWidget {
  final String? header;
  final Widget? headerTrailing;
  final String? footer;
  final List<Widget> children;
  final double dividerIndent;
  final EdgeInsetsGeometry padding;

  const AppSection({
    super.key,
    required this.children,
    this.header,
    this.headerTrailing,
    this.footer,
    this.dividerIndent = AppMetrics.dividerIndent,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.s16,
      0,
      AppSpacing.s16,
      AppSpacing.s24,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null || headerTrailing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                0,
                0,
                AppSpacing.s6,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(header ?? '', style: AppText.header(context)),
                  ),
                  ?headerTrailing,
                ],
              ),
            ),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: dividerIndent,
                      color: AppColors.separator,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s6,
                AppSpacing.s16,
                0,
              ),
              child: Text(footer!, style: AppText.footnote(context)),
            ),
        ],
      ),
    );
  }
}

// Icono pequeño en un cuadrado redondeado de color.
class AppTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? iconColor;

  const AppTile({
    super.key,
    required this.icon,
    this.color = AppColors.cyanDark,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppMetrics.tileSize,
      height: AppMetrics.tileSize,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppMetrics.tileRadius),
      ),
      child: Icon(icon, size: 18, color: iconColor ?? onColorOf(color)),
    );
  }
}

// Fila de lista: icono, título, línea gris debajo, valor a la derecha y flecha.
class AppRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Color? titleColor;
  final Widget? subtitle;
  final Widget? trailing;
  final int? trailingFlex;
  final bool chevron;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AppRow({
    super.key,
    required this.title,
    this.leading,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.trailingFlex,
    this.chevron = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppMetrics.rowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s10,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.rowTitle(context, color: titleColor),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.s2),
                      subtitle!,
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.s8),
                if (trailingFlex != null)
                  Flexible(
                    flex: trailingFlex!,
                    fit: FlexFit.tight,
                    child: trailing!,
                  )
                else
                  trailing!,
              ],
              if (chevron) ...[
                const SizedBox(width: AppSpacing.s4),
                const AppChevron(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Fila de solo lectura: etiqueta a la izquierda y valor gris a la derecha.
class AppValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  // Acción pequeña a la derecha del valor (p. ej. copiar).
  final Widget? trailing;

  const AppValueRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppMetrics.rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppText.rowTitle(context).copyWith(
                fontWeight: bold ? FontWeight.w700 : null,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: AppText.rowTitle(
                  context,
                  color: valueColor ?? AppColors.textSecondary,
                ).copyWith(fontWeight: bold ? FontWeight.w700 : null),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// Estado vacío: icono gris, línea en negrita, línea gris y la acción principal.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppColors.chevron),
          const SizedBox(height: AppSpacing.s12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.rowTitle(context).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppText.rowSubtitle(context),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.s20),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, AppMetrics.minTap)),
              child: Text(
                actionLabel!,
                style: AppText.rowTitle(
                  context,
                  color: AppColors.onDark,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Una fila de una lista agrupada: fondo del bloque, esquinas redondeadas en la
// primera y la última, y una línea fina (con sangría) entre filas.
Widget _groupItem(
  Widget row, {
  required bool first,
  required bool last,
  required double dividerIndent,
}) {
  const radius = Radius.circular(AppMetrics.groupRadius);
  return ClipRRect(
    borderRadius: BorderRadius.vertical(
      top: first ? radius : Radius.zero,
      bottom: last ? radius : Radius.zero,
    ),
    child: ColoredBox(
      color: AppColors.surface,
      child: Column(
        children: [
          row,
          if (!last)
            Divider(
              height: 1,
              thickness: 1,
              indent: dividerIndent,
              color: AppColors.separator,
            ),
        ],
      ),
    ),
  );
}

// Lista larga dentro de un bloque agrupado: las filas se construyen al
// desplazarse; la primera y la última redondean las esquinas del bloque.
class AppSliverGroup extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double dividerIndent;

  const AppSliverGroup({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.dividerIndent = AppMetrics.dividerIndent,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _groupItem(
            itemBuilder(context, index),
            first: index == 0,
            last: index == itemCount - 1,
            dividerIndent: dividerIndent,
          ),
          childCount: itemCount,
        ),
      ),
    );
  }
}

// Lo mismo que [AppSliverGroup] para una pantalla que no usa slivers: una lista
// con el bloque agrupado y espacio abajo para el botón flotante.
class AppGroupListView extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double dividerIndent;

  const AppGroupListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.dividerIndent = AppMetrics.dividerIndent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppFlat.listWithFab.bottom + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => _groupItem(
        itemBuilder(context, index),
        first: index == 0,
        last: index == itemCount - 1,
        dividerIndent: dividerIndent,
      ),
    );
  }
}

// Total grande arriba de un detalle.
class AppBigTotal extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  // Pastilla de estado bajo el total (p. ej. "Cancelada").
  final Widget? pill;

  const AppBigTotal({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.pill,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s24,
      ),
      child: Column(
        children: [
          Text(label, style: AppText.rowSubtitle(context)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppText.largeTitle(
                context,
              ).copyWith(fontSize: AppMetrics.bigNumberSize),
            ),
          ),
          if (pill != null) ...[
            const SizedBox(height: AppSpacing.s8),
            pill!,
          ],
          if (note != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              note!,
              textAlign: TextAlign.center,
              style: AppText.rowSubtitle(context),
            ),
          ],
        ],
      ),
    );
  }
}
