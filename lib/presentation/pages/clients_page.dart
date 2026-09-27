import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/client_provider.dart';
import '../../models/client_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/client_dialog.dart';
import '../widgets/app_bar_widget.dart';

// Página de Clientes, con su propio módulo de permisos ("clientes"),
// independiente de Proveedores.
class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: 'Clientes', showBack: true),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
        heroTag: 'clients_list_body_fab',
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, null),
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.clients.isEmpty
          ? Center(
              child: Text(
                'No hay clientes registrados',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.s16),
              itemCount: state.clients.length,
              itemBuilder: (context, index) {
                final c = state.clients[index];
                return ContactCard(
                  name: c.name,
                  contactInfo: c.contactInfo,
                  isActive: c.isActive,
                  onEdit: () => _showDialog(context, c),
                );
              },
            ),
    );
  }

  void _showDialog(BuildContext context, ClientModel? client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ClientDialog(client: client),
    );
  }
}

// Tarjeta reutilizable para clientes y proveedores (misma presentación en
// ambas páginas).
class ContactCard extends StatefulWidget {
  final String name;
  final String? contactInfo;
  final bool isActive;
  final VoidCallback onEdit;

  const ContactCard({
    super.key,
    required this.name,
    required this.contactInfo,
    required this.isActive,
    required this.onEdit,
  });

  @override
  State<ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<ContactCard> {
  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: AppColors.surface,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con nombre y botón cerrar
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s24,
                    AppSpacing.s24,
                    AppSpacing.s24,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.name,
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s6),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // Contenido scrollable
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s24,
                      0,
                      AppSpacing.s24,
                      AppSpacing.s24,
                    ),
                    child:
                        widget.contactInfo != null &&
                            widget.contactInfo!.isNotEmpty
                        ? Stack(
                            children: [
                              // Texto de contacto
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.s40,
                                ),
                                child: Text(
                                  widget.contactInfo!,
                                  style: Theme.of(context).textTheme
                                      .displayMedium?.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.6,
                                      ),
                                ),
                              ),
                              // Botón copiar
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: widget.contactInfo!),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Copiado al portapapeles',
                                        ),
                                        backgroundColor: AppColors.primary,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(AppSpacing.s6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.copy_outlined,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Sin información de contacto',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s12),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  if (widget.contactInfo != null &&
                      widget.contactInfo!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      widget.contactInfo!,
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isActive
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.isActive ? 'Activo' : 'Inactivo',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: widget.isActive
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: widget.onEdit,
            ),
          ],
        ),
      ),
    );
  }
}
