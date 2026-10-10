import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import 'main_navigation_page.dart';
import 'nav_resolver.dart';

// Página abierta desde un acceso rápido: con la barra de navegación inferior y
// el botón para volver a Inicio.
class ShellPage extends ConsumerWidget {
  final NavGroupId group;
  final Widget child;

  const ShellPage({super.key, required this.group, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = resolveVisibleGroups(
      ref.watch(readableModulesProvider).valueOrNull ?? const [],
    );
    final selected = groups.indexOf(group);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: selected < 0
          ? null
          : MainBottomBar(
              groups: groups,
              selectedIndex: selected,
              onSelect: (i) {
                ref.read(mainTabIndexProvider.notifier).state = i;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
    );
  }
}
