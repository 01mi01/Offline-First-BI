import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum AppButtonKind { destructive, neutral, primary }

class AppActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.kind,
    this.icon,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ElevatedButton(
        onPressed: onPressed,
        style: switch (kind) {
          AppButtonKind.destructive => destructiveButtonStyle,
          AppButtonKind.neutral => neutralButtonStyle,
          AppButtonKind.primary => null,
        },
        child: icon == null
            ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: AppIconSize.s18),
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
