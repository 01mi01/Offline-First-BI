import 'dart:io';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';

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
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s6,
      children: [
        Text(title, style: style),
        Text(
          suffix,
          maxLines: 1,
          softWrap: false,
          style: AppText.rowSubtitle(
            context,
            color: AppColors.textMuted,
          ).copyWith(fontSize: AppMetrics.formLabelSize),
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

final Color imagePlaceholderColor = AppColors.cyanDark.withValues(alpha: AppOpacity.a14);

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
      ).copyWith(fontSize: AppMetrics.formLabelSize, fontWeight: FontWeight.w600),
    );
  }
}

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
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
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
