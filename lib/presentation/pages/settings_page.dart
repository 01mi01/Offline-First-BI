import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/confirm_cancel_dialog.dart';
import 'login_page.dart';

// Ajustes: datos de la cuenta, un espacio reservado para preferencias
// futuras y el cierre de sesión.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmCancellation(
      context,
      title: '¿Cerrar sesión?',
      message:
          'Tendrás que iniciar sesión de nuevo para volver a usar la aplicación.',
      confirmLabel: 'Cerrar sesión',
      dismissLabel: 'Cancelar',
    );
    if (!confirmed || !context.mounted) return;

    final navigator = Navigator.of(context);
    final auth = ref.read(authProvider.notifier);
    await auth.logout();
    // Igual que al iniciar sesión (que reemplaza la ruta por el shell), al
    // cerrarla hay que navegar de forma explícita: se vacía toda la pila
    // (Ajustes y el shell) y queda solo la pantalla de inicio de sesión.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Ajustes', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        children: [
          // Cuenta
          _SectionTitle('Cuenta'),
          _Card(
            child: Row(
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  color: AppColors.primary,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.username ?? '',
                        style: textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if ((user?.email ?? '').isNotEmpty)
                        Text(
                          user!.email,
                          style: textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if ((user?.role ?? '').isNotEmpty)
                        Text(
                          _capitalize(user!.role),
                          style: textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),

          // Preferencias (espacio reservado; todavía no hacen nada)
          _SectionTitle('Preferencias'),
          _Card(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo oscuro',
                        style: textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Próximamente',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sin onChanged: el interruptor queda desactivado.
                const Switch(value: false, onChanged: null),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s32),

          // Cerrar sesión
          OutlinedButton.icon(
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout, color: AppColors.errorDark),
            label: const Text(
              'Cerrar sesión',
              style: TextStyle(
                color: AppColors.errorDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              side: const BorderSide(color: AppColors.errorDark),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
