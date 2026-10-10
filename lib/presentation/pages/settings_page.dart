import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/ios_group.dart';
import '../widgets/screen_header.dart';
import '../widgets/ios_style.dart';
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
                IosSection(
                  children: [
                    IosRow(
                      leading: AppAvatar(name: username),
                      title: username,
                      subtitle: role.isEmpty
                          ? null
                          : Text(
                              _capitalize(role),
                              style: IosText.rowSubtitle(context),
                            ),
                    ),
                  ],
                ),
                IosSection(
                  header: 'Cuenta',
                  dividerIndent: AppIos.dividerIndentWithTile,
                  children: [
                    _valueRow(
                      context,
                      icon: Icons.person_rounded,
                      color: AppColors.primary,
                      title: 'Usuario',
                      value: username,
                    ),
                    if (email.isNotEmpty)
                      _valueRow(
                        context,
                        icon: Icons.mail_rounded,
                        color: AppColors.chartColor5,
                        title: 'Correo',
                        value: email,
                      ),
                  ],
                ),
                IosSection(
                  header: 'Apariencia',
                  dividerIndent: AppIos.dividerIndentWithTile,
                  children: [
                    IosRow(
                      leading: const IosTile(
                        icon: Icons.dark_mode_rounded,
                        color: AppColors.navy,
                        iconColor: AppColors.textButtons,
                      ),
                      title: 'Tema oscuro',
                      titleColor: AppColors.textSecondary,
                      subtitle: Text(
                        'Próximamente',
                        style: IosText.rowSubtitle(context),
                      ),
                      trailing: const Switch(
                        value: false,
                        onChanged: null,
                        activeTrackColor: AppColors.primaryDark,
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
    return IosRow(
      leading: IosTile(
        icon: icon,
        color: color,
        iconColor: AppColors.textButtons,
      ),
      title: title,
      trailing: Flexible(
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s4),
          child: Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: IosText.rowSubtitle(context),
          ),
        ),
      ),
    );
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
