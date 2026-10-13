import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/client_provider.dart';
import '../../application/search_filter.dart';
import '../../application/status_filter.dart';
import '../../models/client_model.dart';
import '../../models/default_records.dart';
import '../../theme/app_theme.dart';
import '../dialogs/client_dialog.dart';
import '../widgets/screen_header.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/contact_record.dart';
import '../widgets/app_controls.dart';
import '../widgets/flat_list.dart';
import '../widgets/profile_button.dart';
import '../widgets/filter_panel.dart';
import '../widgets/empty_state.dart';

// Página de Clientes, con su propio módulo de permisos ("clientes"),
// independiente de Proveedores.
class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      title: 'Clientes',
      actions: const [ProfileButton()],
      body: const ClientsListBody(),
    );
  }
}

// Contenido de la lista de clientes, sin AppBar propia.
class ClientsListBody extends ConsumerWidget {
  const ClientsListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientProvider);
    final status = ref.watch(clientStatusFilterProvider);
    final query = ref.watch(clientListQueryProvider);
    // Búsqueda por nombre (sin distinguir tildes) y filtro por estado.
    final visible = filterByQuery<ClientModel>(
      state.clients.where((r) => status.matches(r.isActive)),
      query,
      (r) => r.name,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FlatFab(
        heroTag: 'clients_list_body_fab',
        onPressed: () => _showDialog(context, null),
      ),
      body: Column(
        children: [
          FilterArea(
            search: AppSearchBar(
              initialText: query,
              hintText: 'Buscar cliente',
              onChanged: (value) =>
                  ref.read(clientListQueryProvider.notifier).state = value,
            ),
            fields: [
              FilterDropdown<StatusFilter>(
                label: 'Estado',
                options: statusFilterOptions(),
                current: status,
                defaultValue: StatusFilter.all,
                onApply: (value) =>
                    ref.read(clientStatusFilterProvider.notifier).state = value,
              ),
            ],
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.clients.isEmpty
                ? Center(
                    child: AppEmptyState.list(
                      plural: 'clientes',
                      icon: Icons.person_rounded,
                      actionLabel: 'Nuevo cliente',
                      onAction: () => _showDialog(context, null),
                    ),
                  )
                : visible.isEmpty
                ? const SingleChildScrollView(
                    child: AppEmptyState.noMatch(),
                  )
                : AppGroupListView(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final c = visible[index];
                      final protected = c.isDefault
                          ? DefaultRecords.protectedClientMessage
                          : null;
                      return ContactRow(
                        name: c.name,
                        contactInfo: c.contactInfo,
                        isActive: c.isActive,
                        protectedMessage: protected,
                        onTap: () => showContactDetail(
                          context,
                          title: 'Detalle del cliente',
                          name: c.name,
                          contactInfo: c.contactInfo,
                          isActive: c.isActive,
                          protectedMessage: protected,
                          onEdit: () => _showDialog(context, c),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, ClientModel? client) {
    showAppSheet<void>(context, builder: (_) => ClientDialog(client: client));
  }
}

