import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/supplier_provider.dart';
import '../../application/search_filter.dart';
import '../../application/status_filter.dart';
import '../widgets/catalog_filter_bar.dart';
import '../../models/default_records.dart';
import '../../models/supplier_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/supplier_dialog.dart';
import '../widgets/app_bar_widget.dart';
import 'clients_page.dart' show ContactCard;

// Página de Proveedores, con su propio módulo de permisos ("proveedores"),
// independiente de Clientes.
class SuppliersPage extends ConsumerWidget {
  const SuppliersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: 'Proveedores', showBack: true),
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
      floatingActionButton: FloatingActionButton(
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
        heroTag: 'suppliers_list_body_fab',
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, null),
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      body: Column(
        children: [
          CatalogListHeader(
            chips: [
              StatusFilterChip(
                value: status,
                onChanged: (value) =>
                    ref.read(supplierStatusFilterProvider.notifier).state = value,
              ),
            ],
            search: CatalogSearchField(
              initialText: query,
              hintText: 'Buscar proveedor',
              onChanged: (value) =>
                  ref.read(supplierListQueryProvider.notifier).state = value,
            ),
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
