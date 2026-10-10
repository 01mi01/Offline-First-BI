import 'dart:io';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Piezas de las listas y el catálogo con estilo plano (ver flat_style.dart):
// filas sin tarjeta separadas por una línea fina, baldosas sin sombra, píldoras
// suaves de estado y un estado vacío sencillo.

// Imagen cuadrada con esquinas redondeadas. Sin imagen (o si el archivo ya no
// existe) muestra un cuadro neutro con [icon].
class FlatThumb extends StatelessWidget {
  final String? imagePath;
  final IconData icon;
  final double size;

  const FlatThumb({
    super.key,
    required this.icon,
    this.imagePath,
    this.size = AppFlat.thumbSize,
  });

  Widget _placeholder() => Container(
    width: size,
    height: size,
    color: AppColors.surface,
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

// Fila plana de una lista: [leading] (imagen o icono), título en negrita y
// líneas tenues debajo a la izquierda, y el dato clave a la derecha
// ([trailing]). Toda la fila responde al toque con una onda suave y termina en
// una línea fina. [below] va debajo de la fila, alineado con el texto (p. ej.
// los materiales de un producto).
class FlatListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Color? titleColor;
  // Líneas debajo del título (textos tenues, pastillas...).
  final List<Widget> details;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;
  final bool showDivider;

  const FlatListRow({
    super.key,
    required this.title,
    this.leading,
    this.titleColor,
    this.details = const [],
    this.trailing,
    this.below,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final indent = leading == null
        ? 0.0
        : AppFlat.thumbSize + AppSpacing.s16;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppFlat.minTap),
            child: Padding(
              padding: AppFlat.rowPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: AppSpacing.s16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: titleColor ?? AppColors.textPrimary,
                              ),
                            ),
                            for (final detail in details) ...[
                              const SizedBox(height: AppSpacing.s4),
                              detail,
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: AppSpacing.s8),
                        trailing!,
                      ],
                    ],
                  ),
                  if (below != null)
                    Padding(
                      padding: EdgeInsets.only(
                        left: indent,
                        top: AppSpacing.s12,
                      ),
                      child: below,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(indent: AppSpacing.s16, endIndent: AppSpacing.s16),
      ],
    );
  }
}

// Línea de texto tenue de una fila (categoría, descripción, stock...).
class FlatMutedText extends StatelessWidget {
  final String text;
  final int? maxLines;
  final bool bold;

  const FlatMutedText(this.text, {super.key, this.maxLines, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: bold ? FontWeight.w600 : null,
      ),
    );
  }
}

// Dato clave a la derecha de una fila (precio, stock): negrita y navy.
class FlatValueText extends StatelessWidget {
  final String text;

  const FlatValueText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      softWrap: false,
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// Pastilla suave de estado: activo en verde oscuro sobre verde suave; inactivo
// en gris sobre el relleno neutro; cancelado en navy sobre rosa suave. Nunca
// depende solo del color: el texto dice el estado.
enum FlatStatus { active, inactive, canceled }

class FlatStatusPill extends StatelessWidget {
  final String label;
  final FlatStatus status;

  const FlatStatusPill({super.key, required this.label, required this.status});

  // Activo / Inactivo con las etiquetas que se quiera ("Activa", "Inactiva").
  factory FlatStatusPill.forState({
    Key? key,
    required bool isActive,
    String activeLabel = 'Activo',
    String inactiveLabel = 'Inactivo',
  }) => FlatStatusPill(
    key: key,
    label: isActive ? activeLabel : inactiveLabel,
    status: isActive ? FlatStatus.active : FlatStatus.inactive,
  );

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (status) {
      FlatStatus.active => (AppColors.successSoft, AppColors.successDark),
      FlatStatus.inactive => (AppColors.surface, AppColors.textSecondary),
      FlatStatus.canceled => (AppColors.errorSoft, AppColors.textPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

// Encabezado de una sección dentro de una pantalla o una fila.
class FlatSectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const FlatSectionHeader(
    this.title, {
    super.key,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// Estado vacío: un icono, una línea tenue y, si se da, la acción principal.
class FlatEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FlatEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.s12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.s20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, AppMetrics.minTap),
                ),
                child: Text(
                  actionLabel!,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Baldosa del catálogo: imagen redondeada y, debajo, el nombre y las líneas de
// precio. Sin tarjeta, sin sombra y sin borde.
class FlatTile extends StatelessWidget {
  final String? imagePath;
  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onTap;

  const FlatTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.imagePath,
    this.lines = const [],
  });

  Widget _placeholder() => Container(
    color: AppColors.surface,
    child: Center(
      child: Icon(icon, color: AppColors.cyanDark, size: 40),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppFlat.tileRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppFlat.tileRadius),
                child: imagePath != null
                    ? Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                for (final line in lines)
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Botón flotante de "agregar": cian con el icono navy (nunca blanco sobre cian)
// y sin sombra.
class FlatFab extends StatelessWidget {
  final String heroTag;
  final VoidCallback onPressed;

  const FlatFab({super.key, required this.heroTag, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      backgroundColor: AppColors.cyanDark,
      foregroundColor: AppColors.onDark,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: const CircleBorder(),
      onPressed: onPressed,
      child: const Icon(Icons.add_rounded, color: AppColors.onDark),
    );
  }
}
