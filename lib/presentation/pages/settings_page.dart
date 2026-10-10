import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_group.dart';
import '../widgets/screen_header.dart';
import '../widgets/app_style.dart';
import 'login_page.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_avatar.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmCancellation(
      context,
      title: '¿Cerrar sesión?',
      confirmLabel: 'Cerrar sesión',
      dismissLabel: 'Cancelar',
    );
    if (!confirmed || !context.mounted) return;

    final navigator = Navigator.of(context);
    final auth = ref.read(authProvider.notifier);
    await auth.logout();
    // Se vacía toda la pila (Ajustes y el shell) y queda solo el inicio de sesión.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final username = user?.username ?? '';
    final email = user?.email ?? '';
    final role = user?.role ?? '';

    return ScreenScaffold.slivers(
      title: 'Ajustes',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
              children: [
                AppSection(
                  children: [
                    AppRow(
                      leading: AppAvatar(name: username),
                      title: username,
                      subtitle: role.isEmpty
                          ? null
                          : Text(
                              _capitalize(role),
                              style: AppText.rowSubtitle(context),
                            ),
                    ),
                  ],
                ),
                AppSection(
                  header: 'Cuenta',
                  dividerIndent: AppMetrics.dividerIndentWithTile,
                  children: [
                    _valueRow(
                      context,
                      icon: Icons.person_rounded,
                      color: AppColors.cyan,
                      title: 'Usuario',
                      value: username,
                    ),
                    if (email.isNotEmpty)
                      _valueRow(
                        context,
                        icon: Icons.mail_rounded,
                        color: AppColors.blue,
                        title: 'Correo',
                        value: email,
                      ),
                  ],
                ),
                AppSection(
                  header: 'Apariencia',
                  dividerIndent: AppMetrics.dividerIndentWithTile,
                  children: [
                    AppRow(
                      leading: const AppTile(
                        icon: Icons.dark_mode_rounded,
                        color: AppColors.navy,
                        iconColor: AppColors.onDark,
                      ),
                      title: 'Tema oscuro',
                      titleColor: AppColors.textSecondary,
                      subtitle: Text(
                        'Próximamente',
                        style: AppText.rowSubtitle(context),
                      ),
                      trailing: const Switch(
                        value: false,
                        onChanged: null,
                        activeTrackColor: AppColors.cyanDark,
                        inactiveTrackColor: AppColors.border,
                        inactiveThumbColor: AppColors.surface,
                      ),
                    ),
                  ],
                ),
                AppActionButton(
                  label: 'Cerrar sesión',
                  kind: AppButtonKind.destructive,
                  padding: AppButtons.formPadding,
                  onPressed: () => _logout(context, ref),
                ),
              ],
            ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.s16 + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  Widget _valueRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return AppRow(
      leading: AppTile(
        icon: icon,
        color: color,
        iconColor: AppColors.onDark,
      ),
      title: title,
      trailingFlex: 3,
      trailing: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.s4),
        child: Text(
          value,
          maxLines: 1,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          style: AppText.rowSubtitle(context),
        ),
      ),
    );
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
