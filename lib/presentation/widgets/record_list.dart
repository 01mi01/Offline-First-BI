import 'dart:io';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';

// Fila común de todas las listas de registros (ventas, compras, productos,
// categorías, materiales, clientes, proveedores, eventos, ubicaciones y el
// registro de uso). Va dentro de [AppSliverGroup] o [AppGroupListView], que
// ponen el fondo y la línea fina entre filas.
//
// De izquierda a derecha: [thumb] (solo productos y categorías), el texto
// (título, [details] y la [pill] de estado), el dato clave [trailing] y la
// flecha. [below] va debajo de la fila, alineado con el texto.
class RecordRow extends StatelessWidget {
  final String title;
  final String? titleSuffix;
  final Color? titleColor;
  final List<Widget> details;
  final Widget? pill;
  final Widget? trailing;
  final Widget? thumb;
  final Widget? below;
  final VoidCallback? onTap;

  const RecordRow({
    super.key,
    required this.title,
    this.titleSuffix,
    this.titleColor,
    this.details = const [],
    this.pill,
    this.trailing,
    this.thumb,
    this.below,
    this.onTap,
  });

  Widget _title(BuildContext context) {
    final style = AppText.rowTitle(context, color: titleColor);
    final suffix = titleSuffix;
    if (suffix == null) return Text(title, style: style);
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: AppSpacing.s6),
        Text(
          suffix,
          maxLines: 1,
          softWrap: false,
          style: AppText.rowSubtitle(
            context,
            color: AppColors.textMuted,
          ).copyWith(fontSize: AppMetrics.headerSize + 1),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasThumb = thumb != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppMetrics.rowMinHeight),
        child: Center(
          child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: hasThumb ? AppSpacing.s14 : AppSpacing.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (hasThumb) ...[
                    thumb!,
                    const SizedBox(width: AppSpacing.s12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(context),
                        for (final detail in details) ...[
                          const SizedBox(height: AppSpacing.s2),
                          detail,
                        ],
                        if (pill != null) ...[
                          const SizedBox(height: AppSpacing.s6),
                          pill!,
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.s8),
                    trailing!,
                  ],
                  const SizedBox(width: AppSpacing.s4),
                  const AppChevron(),
                ],
              ),
              if (below != null)
                Padding(
                  padding: EdgeInsets.only(
                    left: hasThumb ? AppFlat.thumbSize + AppSpacing.s12 : 0,
                    top: AppSpacing.s10,
                  ),
                  child: below,
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

// Fondo del marcador de imagen (productos y categorías): el mismo tono cian
// oscuro suave de los iconos del menú de Inventario.
final Color imagePlaceholderColor = AppColors.cyanDark.withValues(alpha: 0.14);

// Imagen cuadrada con esquinas redondeadas. Sin imagen (o si el archivo ya no
// existe) muestra un cuadro neutro con [icon]. Solo la usan productos y
// categorías.
class RecordThumb extends StatelessWidget {
  final String? imagePath;
  final IconData icon;
  final double size;

  const RecordThumb({
    super.key,
    required this.icon,
    this.imagePath,
    this.size = AppFlat.thumbSize,
  });

  Widget _placeholder() => Container(
    width: size,
    height: size,
    color: imagePlaceholderColor,
    child: Icon(icon, color: AppColors.cyanDark, size: size * 0.45),
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppFlat.thumbRadius),
      child: imagePath != null
          ? Image.file(
              File(imagePath!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }
}

// Línea de texto tenue de una fila (fecha, categoría, descripción, stock...).
class RecordLine extends StatelessWidget {
  final String text;
  final int? maxLines;
  final Color? color;

  const RecordLine(this.text, {super.key, this.maxLines, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: AppText.rowSubtitle(context, color: color),
    );
  }
}

// Precio de una fila de producto: pequeño, en negrita suave.
class RecordPrice extends StatelessWidget {
  final String text;

  const RecordPrice(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      softWrap: false,
      style: AppText.rowSubtitle(
        context,
        color: AppColors.textPrimary,
      ).copyWith(fontSize: AppMetrics.headerSize + 1, fontWeight: FontWeight.w600),
    );
  }
}

// Dato clave a la derecha de una fila (importe, stock, precio). Tachado y
// atenuado cuando el registro está cancelado.
class RecordValue extends StatelessWidget {
  final String text;
  final bool canceled;

  const RecordValue(this.text, {super.key, this.canceled = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      softWrap: false,
      textAlign: TextAlign.end,
      style:
          AppText.rowTitle(
            context,
            color: canceled ? AppColors.textMuted : AppColors.textPrimary,
          ).copyWith(
            fontWeight: FontWeight.w600,
            decoration: canceled ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.textMuted,
          ),
    );
  }
}
