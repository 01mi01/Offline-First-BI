import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppAvatar extends StatelessWidget {
  final String name;

  const AppAvatar({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    const color = AppColors.cyanDark;
    final onColor = onColorOf(color);
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(color: color, shape: BoxShape.circle),
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
