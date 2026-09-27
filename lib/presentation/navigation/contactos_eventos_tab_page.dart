import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/clients_page.dart';
import '../pages/events_page.dart';
import '../pages/suppliers_page.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/landing_card.dart';
import 'nav_resolver.dart';

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

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const CustomAppBar(title: 'Contactos y eventos'),
          body: cards.isEmpty
              ? Center(
                  child: Text(
                    'No tienes acceso a clientes, proveedores ni eventos',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    children: cards
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s12,
                            ),
                            child: LandingCard(
                              label: _labelFor(card),
                              icon: _iconFor(card),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _pageFor(card),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('No se pudo cargar Contactos y eventos')),
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
      return 'Eventos';
  }
}

IconData _iconFor(ContactosCard card) {
  switch (card) {
    case ContactosCard.clientes:
      return Icons.person_outline;
    case ContactosCard.proveedores:
      return Icons.local_shipping_outlined;
    case ContactosCard.eventos:
      return Icons.event_outlined;
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
