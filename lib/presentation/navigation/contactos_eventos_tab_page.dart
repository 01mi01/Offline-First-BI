import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/clients_page.dart';
import '../pages/events_page.dart';
import '../pages/suppliers_page.dart';
import '../widgets/screen_header.dart';
import '../widgets/app_list_row.dart';
import 'nav_resolver.dart';
import '../widgets/profile_button.dart';

// Tab "Clientes, Proveedores y Eventos" de la navegación inferior: pantalla
// de aterrizaje con tarjetas que llevan a cada página existente, mostrando
// solo las tarjetas cuyo módulo el usuario puede leer.
class ContactosEventosTabPage extends ConsumerWidget {
  const ContactosEventosTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readableModules = ref.watch(readableModulesProvider);

    return readableModules.when(
      data: (modules) {
        final cards = resolveContactosCards(modules);

        return ScreenScaffold(
          title: 'Contactos y Eventos',
          actions: const [ProfileButton()],
          body: cards.isEmpty
              ? Center(
                  child: Text(
                    'No tienes acceso a clientes, proveedores ni eventos',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppHeader.sidePadding, 0, AppHeader.sidePadding, AppSpacing.s16),
                  children: [
                    AppListCard(
                      children: [
                        for (var i = 0; i < cards.length; i++)
                          AppListRow(
                            icon: _iconFor(cards[i]),
                            iconColor: AppColors.chartColor1,
                            title: _labelFor(cards[i]),
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _pageFor(cards[i]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('No se pudo cargar Contactos y Eventos')),
      ),
    );
  }
}

String _labelFor(ContactosCard card) {
  switch (card) {
    case ContactosCard.clientes:
      return 'Clientes';
    case ContactosCard.proveedores:
      return 'Proveedores';
    case ContactosCard.eventos:
      return 'Eventos y Ubicaciones';
  }
}

IconData _iconFor(ContactosCard card) {
  switch (card) {
    case ContactosCard.clientes:
      return Icons.person_rounded;
    case ContactosCard.proveedores:
      return Icons.local_shipping_rounded;
    case ContactosCard.eventos:
      return Icons.event_rounded;
  }
}

Widget _pageFor(ContactosCard card) {
  switch (card) {
    case ContactosCard.clientes:
      return const ClientsPage();
    case ContactosCard.proveedores:
      return const SuppliersPage();
    case ContactosCard.eventos:
      return const EventsPage();
  }
}
