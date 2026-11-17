import 'package:flutter/material.dart';
import '../../application/module_permission_provider.dart';
import '../widgets/module_gate.dart';
import '../../models/access_control.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/client_provider.dart';
import '../../application/record_search.dart';
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

class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ModuleGate(
      modules: const [AppModule.clientes],
      title: 'Clientes',
      child: ScreenScaffold(
        title: 'Clientes',
        actions: const [ProfileButton()],
        body: const ClientsListBody(),
      ),
    );
  }
}

class ClientsListBody extends ConsumerWidget {
  const ClientsListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessControlProvider);
    final state = ref.watch(clientProvider);
    final status = ref.watch(clientStatusFilterProvider);
    final query = ref.watch(clientListQueryProvider);
    final visible = ref
        .watch(clientSearchIndexProvider)
        .search(query)
        .where((r) => status.matches(r.isActive))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: access.canCreate(AppModule.clientes)
          ? FlatFab(
              heroTag: 'clients_list_body_fab',
              onPressed: () => _showDialog(context, null),
            )
          : null,
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
                      actionLabel: access.canCreate(AppModule.clientes)
                          ? 'Nuevo cliente'
                          : null,
                      onAction: access.canCreate(AppModule.clientes)
                          ? () => _showDialog(context, null)
                          : null,
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
                          onEdit: access.canEditOrDeactivate(AppModule.clientes)
                              ? () => _showDialog(context, c)
                              : null,
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
    showFormSheet<void>(context, builder: (_) => ClientDialog(client: client));
  }
}

