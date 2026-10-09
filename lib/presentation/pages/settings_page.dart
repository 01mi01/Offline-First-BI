import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/ios_group.dart';
import '../widgets/ios_scaffold.dart';
import '../widgets/ios_sheet.dart';
import '../widgets/ios_style.dart';
import 'login_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showIosConfirm(
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

    return IosLargeTitleScaffold(
      title: 'Ajustes',
      backLabel: 'Atrás',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: Column(
              children: [
                IosSection(
                  children: [
                    IosRow(
                      leading: _Avatar(name: username),
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
                      icon: Icons.person_outline_rounded,
                      color: AppColors.primaryDark,
                      iconColor: AppColors.surface,
                      title: 'Usuario',
                      value: username,
                    ),
                    if (email.isNotEmpty)
                      _valueRow(
                        context,
                        icon: Icons.mail_outline_rounded,
                        color: AppColors.chartColor5,
                        iconColor: AppColors.surface,
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
                        icon: Icons.dark_mode_outlined,
                        color: AppColors.navy,
                        iconColor: AppColors.surface,
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
                IosDestructiveGroup(
                  label: 'Cerrar sesión',
                  onTap: () => _logout(context, ref),
                ),
              ],
            ),
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
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return IosRow(
      leading: IosTile(icon: icon, color: color, iconColor: iconColor),
      title: title,
      trailing: Flexible(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: IosText.rowSubtitle(context),
        ),
      ),
    );
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        shape: BoxShape.circle,
      ),
      child: name.isEmpty
          ? const Icon(Icons.person_rounded, color: AppColors.surface)
          : Text(
              name[0].toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.surface,
              ),
            ),
    );
  }
}
