import 'dart:io';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'record_list.dart' show imagePlaceholderColor;

class FlatTile extends StatelessWidget {
  final String? imagePath;
  final IconData icon;
  final String title;
  final List<String> lines;
  final Widget? pill;
  final VoidCallback onTap;

  const FlatTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.imagePath,
    this.lines = const [],
    this.pill,
  });

  Widget _placeholder() => Container(
    color: imagePlaceholderColor,
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppFlat.tileRadius),
                    child: imagePath != null
                        ? Image.file(
                            File(imagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  if (pill != null)
                    Positioned(
                      top: AppSpacing.s8,
                      left: AppSpacing.s8,
                      child: pill!,
                    ),
                ],
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

Future<void> showCatalogPopup(
  BuildContext context, {
  required String title,
  required IconData icon,
  String? imagePath,
  String? description,
  List<String> lines = const [],
}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.5),
    builder: (_) => _CatalogPopup(
      title: title,
      icon: icon,
      imagePath: imagePath,
      description: description,
      lines: lines,
    ),
  );
}

class _CatalogPopup extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? imagePath;
  final String? description;
  final List<String> lines;

  const _CatalogPopup({
    required this.title,
    required this.icon,
    required this.imagePath,
    required this.description,
    required this.lines,
  });

  Widget _placeholder() => Container(
    width: double.infinity,
    height: 260,
    color: imagePlaceholderColor,
    child: Icon(icon, color: AppColors.cyanDark, size: 60),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final text = description;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppMetrics.sheetRadius),
        child: Container(
          color: AppColors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  if (imagePath != null)
                    Image.file(
                      File(imagePath!),
                      width: double.infinity,
                      height: 260,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  else
                    _placeholder(),
                  Positioned(
                    top: AppSpacing.s12,
                    right: AppSpacing.s12,
                    child: Material(
                      color: AppColors.surface,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.s12),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (text != null && text.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        text,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (lines.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s12),
                      for (final line in lines)
                        Text(
                          line,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
