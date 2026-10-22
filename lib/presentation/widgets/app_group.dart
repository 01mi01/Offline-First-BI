import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';

class AppSection extends StatelessWidget {
  final String? header;
  final List<Widget> children;
  final double dividerIndent;
  final EdgeInsetsGeometry padding;

  const AppSection({
    super.key,
    required this.children,
    this.header,
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
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                0,
                0,
                AppSpacing.s6,
              ),
              child: Text(header!, style: AppText.formLabel(context)),
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
        ],
      ),
    );
  }
}

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

class AppRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Color? titleColor;
  final Widget? subtitle;
  final Widget? trailing;
  final int? trailingFlex;
  final VoidCallback? onTap;

  const AppRow({
    super.key,
    required this.title,
    this.leading,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.trailingFlex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
            ],
          ),
        ),
      ),
    );
  }
}

class AppValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? valueWidget;
  final bool bold;
  final Color? valueColor;

  const AppValueRow({
    super.key,
    required this.label,
    this.value = '',
    this.valueWidget,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppMetrics.rowMinHeight),
      child: Center(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12 + 1,
          AppSpacing.s16,
          AppSpacing.s12 - 1,
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
              child: valueWidget != null
                  ? Align(alignment: Alignment.centerRight, child: valueWidget)
                  : Text(
                      value,
                      textAlign: TextAlign.end,
                      style: AppText.rowTitle(
                        context,
                        color: valueColor ?? AppColors.textSecondary,
                      ).copyWith(fontWeight: bold ? FontWeight.w700 : null),
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

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

class AppSliverGroup extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const AppSliverGroup({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
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
            dividerIndent: AppMetrics.dividerIndent,
          ),
          childCount: itemCount,
        ),
      ),
    );
  }
}

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

class AppBigTotal extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
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
