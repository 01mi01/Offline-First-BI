import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../pages/settings_page.dart';

// Acceso a "Ajustes" (cuenta, preferencias y cerrar sesión) desde la barra
// superior de cada pestaña principal.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.settings_rounded,
        color: AppColors.primaryDark,
        size: 26,
      ),
      tooltip: 'Ajustes',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      ),
    );
  }
}
