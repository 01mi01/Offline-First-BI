import 'dart:io';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Piezas del catálogo (baldosas sin sombra) y el botón flotante de "agregar".

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
