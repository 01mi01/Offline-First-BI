import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../models/access_control.dart';
import 'empty_state.dart';
import 'screen_header.dart';

AccessControl readAccess(BuildContext context) => ProviderScope.containerOf(
  context,
  listen: false,
).read(accessControlProvider);

const String deactivateOnlyNotice =
    'Solo puedes activar o desactivar este registro.';

const String cancelOnlyNotice = 'Solo puedes cancelar este registro.';

const String moduleDeniedMessage = 'No tienes acceso a este módulo.';

class ModuleDeniedScreen extends StatelessWidget {
  final String title;

  const ModuleDeniedScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: title,
      body: const AppEmptyState.hint(
        icon: Icons.lock_rounded,
        text: moduleDeniedMessage,
      ),
    );
  }
}

class ModuleGate extends ConsumerWidget {
  final List<AppModule> modules;
  final String title;
  final Widget child;

  const ModuleGate({
    super.key,
    required this.modules,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessControlProvider);
    if (modules.any(access.canRead)) return child;
    return ModuleDeniedScreen(title: title);
  }
}
