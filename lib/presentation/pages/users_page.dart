import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_provider.dart';
import '../../application/user_provider.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/user_dialog.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_style.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/flat_list.dart';
import '../widgets/form_style.dart';
import '../widgets/record_detail.dart';
import '../widgets/record_list.dart';
import '../widgets/screen_header.dart';
import '../widgets/status_badge.dart';

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    return ScreenScaffold(
      title: 'Usuarios',
      body: isAdmin
          ? const UsersListBody()
          : const AppEmptyState.hint(
              icon: Icons.lock_rounded,
              text: adminOnlyMessage,
            ),
    );
  }
}

StatusBadge userStatusBadge(UserModel user) => StatusBadge.forState(
  isActive: user.isActive,
  inactiveLabel: 'Bloqueado',
);

class UsersListBody extends ConsumerWidget {
  const UsersListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userManagementProvider);
    final currentId = ref.watch(authProvider).user?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FlatFab(
        heroTag: 'users_list_body_fab',
        onPressed: () => showUserForm(context),
      ),
      body: state.isLoading && state.users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.users.isEmpty
          ? AppEmptyState.hint(
              icon: Icons.error_outline_rounded,
              text: state.error!,
            )
          : AppGroupListView(
              itemCount: state.users.length,
              itemBuilder: (context, index) {
                final user = state.users[index];
                final self = user.id == currentId;
                return RecordRow(
                  key: ValueKey('user_row_${user.id}'),
                  title: user.username,
                  titleSuffix: self ? '(tú)' : null,
                  details: [
                    RecordLine(user.email, maxLines: 1),
                    RecordLine(user.appRole.label, maxLines: 1),
                  ],
                  pill: userStatusBadge(user),
                  onTap: () => showUserDetail(context, user.id),
                );
              },
            ),
    );
  }
}

void showUserForm(BuildContext context, [UserModel? user]) {
  showFormSheet<void>(context, builder: (_) => UserDialog(user: user));
}

void showUserDetail(BuildContext context, int userId) {
  showAppSheet<void>(context, builder: (_) => UserDetailSheet(userId: userId));
}

class UserDetailSheet extends ConsumerStatefulWidget {
  final int userId;

  const UserDetailSheet({super.key, required this.userId});

  @override
  ConsumerState<UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends ConsumerState<UserDetailSheet> {
  String? _error;
  bool _busy = false;

  Future<void> _toggleBlocked(UserModel user) async {
    final block = user.isActive;
    final confirmed = await confirmCancellation(
      context,
      title: block ? '¿Bloquear el usuario?' : '¿Desbloquear el usuario?',
      message: block
          ? '${user.username} no podrá iniciar sesión hasta que lo desbloquees.'
          : '${user.username} podrá volver a iniciar sesión.',
      confirmLabel: block ? 'Bloquear' : 'Desbloquear',
      confirmKind: block ? AppButtonKind.destructive : AppButtonKind.primary,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(userManagementProvider.notifier)
        .setBlocked(user.id, block);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  void _openThen(void Function(NavigatorState navigator) open) {
    final navigator = Navigator.of(context);
    navigator.pop();
    open(navigator);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref
        .watch(userManagementProvider)
        .users
        .where((u) => u.id == widget.userId)
        .firstOrNull;
    if (user == null) return const SizedBox.shrink();
    final self = ref.watch(authProvider).user?.id == user.id;

    return AppSheetScaffold(
      title: 'Detalle del usuario',
      expand: false,
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: () => _openThen(
              (navigator) => showUserForm(navigator.context, user),
            ),
            child: const Text('Editar'),
          ),
          const SizedBox(height: AppButtons.stackGap),
          AppActionButton(
            label: 'Restablecer contraseña',
            kind: AppButtonKind.neutral,
            onPressed: () => _openThen(
              (navigator) => showFormSheet<void>(
                navigator.context,
                builder: (_) => ResetPasswordDialog(user: user),
              ),
            ),
          ),
          if (!self) ...[
            const SizedBox(height: AppButtons.stackGap),
            AppActionButton(
              label: user.isActive ? 'Bloquear' : 'Desbloquear',
              kind: user.isActive
                  ? AppButtonKind.destructive
                  : AppButtonKind.primary,
              onPressed: _busy ? null : () => _toggleBlocked(user),
            ),
          ],
          const SizedBox(height: AppButtons.stackGap),
          AppActionButton(
            label: 'Cerrar',
            kind: AppButtonKind.neutral,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(
          top: AppSpacing.s8,
          bottom: AppSpacing.s16,
        ),
        children: [
          RecordHeadline(
            title: user.username,
            pill: userStatusBadge(user),
            note: self ? 'Este es tu usuario' : null,
          ),
          AppSection(
            header: 'Información',
            children: [
              AppValueRow(label: 'Correo', value: user.email),
              AppValueRow(label: 'Rol', value: user.appRole.label),
            ],
          ),
          if (_error != null) FormErrorText(_error!),
        ],
      ),
    );
  }
}

class UsersSettingsEntry extends ConsumerWidget {
  const UsersSettingsEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isAdminProvider)) return const SizedBox.shrink();
    return AppSection(
      header: 'Administración',
      dividerIndent: AppMetrics.dividerIndentWithTile,
      children: [
        AppRow(
          leading: const AppTile(
            icon: Icons.manage_accounts_rounded,
            color: AppColors.cyanDark,
            iconColor: AppColors.onDark,
          ),
          title: 'Usuarios',
          subtitle: Text(
            'Crear, editar y bloquear usuarios',
            style: AppText.rowSubtitle(context),
          ),
          trailing: const AppChevron(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UsersPage()),
          ),
        ),
      ],
    );
  }
}
