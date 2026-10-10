import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color color;

  const AppAvatar({
    super.key,
    required this.name,
    this.size = 56,
    this.color = AppColors.primaryDark,
  });

  @override
  Widget build(BuildContext context) {
    final onColor = onColorOf(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: name.isEmpty
            ? Icon(Icons.person_rounded, color: onColor)
            : Text(
                name[0].toUpperCase(),
                textAlign: TextAlign.center,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: onColor,
                ),
              ),
      ),
    );
  }
}
