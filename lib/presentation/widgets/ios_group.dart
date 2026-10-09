import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'ios_style.dart';

// Sección agrupada: encabezado gris arriba, filas dentro de un bloque blanco
// redondeado con separadores finos con sangría, y nota al pie.
class IosSection extends StatelessWidget {
  final String? header;
  final Widget? headerTrailing;
  final String? footer;
  final List<Widget> children;
  final double dividerIndent;

  const IosSection({
    super.key,
    required this.children,
    this.header,
    this.headerTrailing,
    this.footer,
    this.dividerIndent = AppIos.dividerIndent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s24,
      ),
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
                    child: Text(header ?? '', style: IosText.header(context)),
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
              borderRadius: BorderRadius.circular(AppIos.groupRadius),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: dividerIndent,
                      color: AppColors.iosSeparator,
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
              child: Text(footer!, style: IosText.footnote(context)),
            ),
        ],
      ),
    );
  }
}

// Icono pequeño en un cuadrado redondeado de color, como en Ajustes de iOS.
class IosTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;

  const IosTile({
    super.key,
    required this.icon,
    this.color = AppColors.primaryDark,
    this.iconColor = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppIos.tileSize,
      height: AppIos.tileSize,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppIos.tileRadius),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}

// Fila de lista: icono, título, línea gris debajo, valor a la derecha y flecha.
class IosRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Color? titleColor;
  final Widget? subtitle;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const IosRow({
    super.key,
    required this.title,
    this.leading,
    this.titleColor,
    this.subtitle,
    this.trailing,
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
        constraints: const BoxConstraints(minHeight: AppIos.rowMinHeight),
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
                      style: IosText.rowTitle(context, color: titleColor),
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
                trailing!,
              ],
              if (chevron) ...[
                const SizedBox(width: AppSpacing.s4),
                const IosChevron(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Fila de solo lectura: etiqueta a la izquierda y valor gris a la derecha.
class IosValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const IosValueRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppIos.rowMinHeight),
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
              style: IosText.rowTitle(context).copyWith(
                fontWeight: bold ? FontWeight.w700 : null,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: IosText.rowTitle(
                  context,
                  color: valueColor ?? AppColors.textSecondary,
                ).copyWith(fontWeight: bold ? FontWeight.w700 : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Fila de formulario con un campo de texto: etiqueta a la izquierda y el campo
// alineado a la derecha, sin borde.
class IosTextFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final Key? fieldKey;

  const IosTextFieldRow({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.suffix,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s16),
            child: Text(label, style: IosText.rowTitle(context)),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: TextFormField(
              key: fieldKey,
              controller: controller,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              textAlign: TextAlign.end,
              style: IosText.rowTitle(context),
              validator: validator,
              onChanged: onChanged,
              decoration: iosFieldDecoration(
                context,
                hint: hint,
                helper: helper,
                suffix: suffix,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Campo de varias líneas: la etiqueta arriba y el texto debajo.
class IosTextAreaRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final Key? fieldKey;

  const IosTextAreaRow({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: IosText.rowTitle(context)),
          TextFormField(
            key: fieldKey,
            controller: controller,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            minLines: 2,
            maxLines: 4,
            style: IosText.rowTitle(context),
            validator: validator,
            decoration: iosFieldDecoration(context, hint: hint).copyWith(
              contentPadding: const EdgeInsets.only(top: AppSpacing.s6),
            ),
          ),
        ],
      ),
    );
  }
}

// Grupo con una sola acción destructiva centrada, como "Cerrar sesión".
class IosDestructiveGroup extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const IosDestructiveGroup({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IosSection(
      children: [
        InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppIos.rowMinHeight),
            child: Center(
              child: Text(
                label,
                style: IosText.rowTitle(context, color: AppColors.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Aviso de error de un formulario.
class IosErrorNote extends StatelessWidget {
  final String message;

  const IosErrorNote({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: AppColors.errorSoft,
          borderRadius: BorderRadius.circular(AppIos.groupRadius),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.error),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                message,
                style: IosText.rowSubtitle(
                  context,
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

// Estado vacío: icono gris, línea en negrita, línea gris y la acción principal.
class IosEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const IosEmptyState({
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
          Icon(icon, size: 52, color: AppColors.iosChevron),
          const SizedBox(height: AppSpacing.s12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: IosText.rowTitle(context).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: IosText.rowSubtitle(context),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.s20),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, AppIos.minTap)),
              child: Text(
                actionLabel!,
                style: IosText.rowTitle(
                  context,
                  color: AppColors.textButtons,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Lista larga dentro de un bloque agrupado: las filas se construyen al
// desplazarse; la primera y la última redondean las esquinas del bloque.
class IosSliverGroup extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double dividerIndent;

  const IosSliverGroup({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.dividerIndent = AppIos.dividerIndent,
  });

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(AppIos.groupRadius);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final first = index == 0;
          final last = index == itemCount - 1;
          return ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: first ? radius : Radius.zero,
              bottom: last ? radius : Radius.zero,
            ),
            child: ColoredBox(
              color: AppColors.surface,
              child: Column(
                children: [
                  itemBuilder(context, index),
                  if (!last)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: dividerIndent,
                      color: AppColors.iosSeparator,
                    ),
                ],
              ),
            ),
          );
        }, childCount: itemCount),
      ),
    );
  }
}

// Total grande arriba de un detalle, como el resumen de Cartera o Salud en iOS.
class IosBigTotal extends StatelessWidget {
  final String label;
  final String value;
  final String? note;

  const IosBigTotal({
    super.key,
    required this.label,
    required this.value,
    this.note,
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
          Text(label, style: IosText.rowSubtitle(context)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: IosText.largeTitle(
                context,
              ).copyWith(fontSize: AppIos.bigNumberSize),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              note!,
              textAlign: TextAlign.center,
              style: IosText.error(context),
            ),
          ],
        ],
      ),
    );
  }
}
