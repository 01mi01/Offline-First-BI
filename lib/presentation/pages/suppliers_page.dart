import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/supplier_provider.dart';
import '../../application/record_search.dart';
import '../../application/status_filter.dart';
import '../../models/default_records.dart';
import '../../models/supplier_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/supplier_dialog.dart';
import '../widgets/screen_header.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/contact_record.dart';
import '../widgets/app_controls.dart';
import '../widgets/flat_list.dart';
import '../widgets/profile_button.dart';
import '../widgets/filter_panel.dart';
import '../widgets/empty_state.dart';

class SuppliersPage extends ConsumerWidget {
  const SuppliersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      title: 'Proveedores',
      actions: const [ProfileButton()],
      body: const SuppliersListBody(),
    );
  }
}

class SuppliersListBody extends ConsumerWidget {
  const SuppliersListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplierProvider);
    final status = ref.watch(supplierStatusFilterProvider);
    final query = ref.watch(supplierListQueryProvider);
    final visible = ref
        .watch(supplierSearchIndexProvider)
        .search(query)
        .where((r) => status.matches(r.isActive))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FlatFab(
        heroTag: 'suppliers_list_body_fab',
        onPressed: () => _showDialog(context, null),
      ),
      body: Column(
        children: [
          FilterArea(
            search: AppSearchBar(
              initialText: query,
              hintText: 'Buscar proveedor',
              onChanged: (value) =>
                  ref.read(supplierListQueryProvider.notifier).state = value,
            ),
            fields: [
              FilterDropdown<StatusFilter>(
                label: 'Estado',
                options: statusFilterOptions(),
                current: status,
                defaultValue: StatusFilter.all,
                onApply: (value) =>
                    ref.read(supplierStatusFilterProvider.notifier).state = value,
              ),
            ],
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.suppliers.isEmpty
                ? Center(
                    child: AppEmptyState.list(
                      plural: 'proveedores',
                      icon: Icons.local_shipping_rounded,
                      actionLabel: 'Nuevo proveedor',
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
                      final s = visible[index];
                      final protected = s.isDefault
                          ? DefaultRecords.protectedSupplierMessage
                          : null;
                      return ContactRow(
                        name: s.name,
                        contactInfo: s.contactInfo,
                        isActive: s.isActive,
                        protectedMessage: protected,
                        onTap: () => showContactDetail(
                          context,
                          title: 'Detalle del proveedor',
                          name: s.name,
                          contactInfo: s.contactInfo,
                          isActive: s.isActive,
                          protectedMessage: protected,
                          onEdit: () => _showDialog(context, s),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, SupplierModel? supplier) {
    showFormSheet<void>(
      context,
      builder: (_) => SupplierDialog(supplier: supplier),
    );
  }
}
