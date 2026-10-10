import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/supplier_provider.dart';
import '../../application/search_filter.dart';
import '../../application/status_filter.dart';
import '../../models/default_records.dart';
import '../../models/supplier_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/supplier_dialog.dart';
import '../widgets/screen_header.dart';
import 'clients_page.dart' show ContactCard;
import '../widgets/app_controls.dart';
import '../widgets/flat_list.dart';
import '../widgets/profile_button.dart';
import '../widgets/filter_panel.dart';

// Página de Proveedores, con su propio módulo de permisos ("proveedores"),
// independiente de Clientes.
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

// Contenido de la lista de proveedores, sin AppBar propia.
class SuppliersListBody extends ConsumerWidget {
  const SuppliersListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplierProvider);
    final status = ref.watch(supplierStatusFilterProvider);
    final query = ref.watch(supplierListQueryProvider);
    // Búsqueda por nombre (sin distinguir tildes) y filtro por estado.
    final visible = filterByQuery<SupplierModel>(
      state.suppliers.where((r) => status.matches(r.isActive)),
      query,
      (r) => r.name,
    );

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
                    child: Text(
                      'No se registraron proveedores',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : visible.isEmpty
                ? Center(
                    child: Text(
                      'Sin resultados',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: AppSpacing.listWithFab,
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final s = visible[index];
                      return ContactCard(
                        name: s.name,
                        contactInfo: s.contactInfo,
                        isActive: s.isActive,
                        protectedMessage: s.isDefault
                            ? DefaultRecords.protectedSupplierMessage
                            : null,
                        onEdit: () => _showDialog(context, s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, SupplierModel? supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SupplierDialog(supplier: supplier),
    );
  }
}
