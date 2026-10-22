import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_controls.dart';

class ViewModeSwitcher extends StatelessWidget {
  final bool isGrid;
  final ValueChanged<bool> onChanged;

  const ViewModeSwitcher({
    super.key,
    required this.isGrid,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppHeader.sidePadding),
      child: AppSegmented<bool>(
        segments: const [
          AppSegment(false, 'Lista'),
          AppSegment(true, 'Vista de catálogo'),
        ],
        selected: isGrid,
        onChanged: onChanged,
      ),
    );
  }
}
