import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../application/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_group.dart';
import '../widgets/screen_header.dart';
import '../widgets/app_style.dart';
import 'login_page.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_avatar.dart';
import 'users_page.dart';

const String themeLightLabel = 'Claro';
const String themeDarkLabel = 'Oscuro';
const String themeSystemLabel = 'Seguir el tema del teléfono';

Key themeOptionKey(ThemeMode mode) => Key('settings-theme-${mode.name}');

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  void _setThemeMode(WidgetRef ref, ThemeMode mode) {
    ref.read(themeModeProvider.notifier).setMode(mode);
  }

  Widget _themeRow(
    WidgetRef ref, {
    required ThemeMode mode,
    required ThemeMode current,
    required IconData icon,
    required String label,
  }) {
    final selected = mode == current;
    return AppRow(
      key: themeOptionKey(mode),
      leading: AppTile(
        icon: icon,
        color: AppColors.navy,
        iconColor: AppColors.onDark,
      ),
      title: label,
      onTap: () => _setThemeMode(ref, mode),
      trailing: selected
          ? Icon(
              Icons.check_rounded,
              size: AppIconSize.s22,
              color: AppColors.cyanDark,
            )
          : null,
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmCancellation(
      context,
      title: '¿Cerrar sesión?',
      confirmLabel: 'Cerrar sesión',
    );
    if (!confirmed || !context.mounted) return;

    final navigator = Navigator.of(context);
    final auth = ref.read(authProvider.notifier);
    await auth.logout();
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
    final role = user?.appRole.label ?? '';
    final themeMode = ref.watch(themeModeProvider);

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
                              role,
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
                const UsersSettingsEntry(),
                AppSection(
                  header: 'Apariencia',
                  dividerIndent: AppMetrics.dividerIndentWithTile,
                  children: [
                    _themeRow(
                      ref,
                      mode: ThemeMode.light,
                      current: themeMode,
                      icon: Icons.light_mode_rounded,
                      label: themeLightLabel,
                    ),
                    _themeRow(
                      ref,
                      mode: ThemeMode.dark,
                      current: themeMode,
                      icon: Icons.dark_mode_rounded,
                      label: themeDarkLabel,
                    ),
                    _themeRow(
                      ref,
                      mode: ThemeMode.system,
                      current: themeMode,
                      icon: Icons.smartphone_rounded,
                      label: themeSystemLabel,
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
}
