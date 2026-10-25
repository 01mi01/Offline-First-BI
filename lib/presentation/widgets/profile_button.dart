import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../pages/settings_page.dart';

class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.settings_rounded,
        color: AppColors.cyanDark,
        size: AppHeader.iconSize,
      ),
      tooltip: 'Ajustes',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      ),
    );
  }
}
