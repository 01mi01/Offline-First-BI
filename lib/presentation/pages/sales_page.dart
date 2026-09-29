import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sale_provider.dart';
import '../../application/client_provider.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../../models/sale_model.dart';
import '../../models/sale_item_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/sale_dialog.dart';
import '../widgets/app_bar_widget.dart';

class SalesPage extends ConsumerWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: 'Ventas', showBack: true),
      body: const SalesListBody(),
    );
  }
}

// Contenido de la lista de ventas, sin AppBar propia. Se usa tanto en
// SalesPage (con AppBar y back) como embebido en el tab "Ventas y Compras"
// de la navegación inferior (sin AppBar).
class SalesListBody extends ConsumerWidget {
  const SalesListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleProvider);
    final clients = ref.watch(clientProvider).clients;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
        heroTag: 'sales_list_body_fab',
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, null),
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.sales.isEmpty
              ? Center(
                  child: Text(
                    'No hay ventas registradas',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  itemCount: state.sales.length,
                  itemBuilder: (context, index) {
                    final sale = state.sales[index];
                    final client = clients
                        .where((c) => c.id == sale.clientId)
                        .firstOrNull;
                    return _SaleCard(
                      sale: sale,
                      clientName: client?.name ?? 'Sin nombre',
                      onEdit: () => _showDialog(context, sale),
                      onTap: () => _showReceipt(context, ref, sale,
                          client?.name ?? 'Sin nombre'),
                    );
                  },
                ),
    );
  }

  void _showDialog(BuildContext context, SaleModel? sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SaleDialog(sale: sale),
    );
  }

  void _showReceipt(BuildContext context, WidgetRef ref, SaleModel sale,
      String clientName) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) =>
          _SaleReceiptDialog(sale: sale, clientName: clientName),
    );
  }
}

// Tarjeta de venta en la lista
class _SaleCard extends StatelessWidget {
  final SaleModel sale;
  final String clientName;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const _SaleCard({
    required this.sale,
    required this.clientName,
    required this.onEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                  // Nombre del cliente
                  Text(
                    clientName,
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  // Fecha
                  Text(
                    _formatDate(sale.date),
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  // Total y descuento
                  Row(
                    children: [
                      Text(
                        'Bs. ${sale.finalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                      ),
                      if (sale.discount > 0) ...[
                        const SizedBox(width: AppSpacing.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                              vertical: AppSpacing.s2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Desc. Bs. ${sale.discount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.primary, size: 20),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Diálogo de recibo completo
class _SaleReceiptDialog extends ConsumerStatefulWidget {
  final SaleModel sale;
  final String clientName;

  const _SaleReceiptDialog(
      {required this.sale, required this.clientName});

  @override
  ConsumerState<_SaleReceiptDialog> createState() =>
      _SaleReceiptDialogState();
}

class _SaleReceiptDialogState
    extends ConsumerState<_SaleReceiptDialog> {
  List<SaleItemModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await ref
        .read(saleProvider.notifier)
        .getItemsForSale(widget.sale.id);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: AppColors.surface,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado
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
                    Text(
                      'Recibo de venta',
                      style: Theme.of(context).textTheme.displayLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
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
                        child: const Icon(Icons.close,
                            color: AppColors.textSecondary, size: 18),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info del cliente y fecha
                      _ReceiptRow(
                          label: 'Cliente',
                          value: widget.clientName),
                      const SizedBox(height: AppSpacing.s8),
                      _ReceiptRow(
                          label: 'Fecha',
                          value: _formatDate(widget.sale.date)),

                      if (widget.sale.locationId != null) ...[
                        const SizedBox(height: AppSpacing.s8),
                        _ReceiptRow(
                          label: 'Ubicación',
                          value: ref
                                  .watch(locationProvider)
                                  .locations
                                  .where((l) => l.id == widget.sale.locationId)
                                  .firstOrNull
                                  ?.city ??
                              '',
                        ),
                      ],
                      if (widget.sale.eventId != null) ...[
                        const SizedBox(height: AppSpacing.s8),
                        _ReceiptRow(
                          label: 'Evento',
                          value: ref
                                  .watch(eventProvider)
                                  .events
                                  .where((e) => e.id == widget.sale.eventId)
                                  .firstOrNull
                                  ?.name ??
                              '',
                        ),
                      ],
                      if (widget.sale.notes != null &&
                          widget.sale.notes!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s8),
                        _ReceiptRow(
                            label: 'Notas', value: widget.sale.notes!),
                      ],

                      const SizedBox(height: AppSpacing.s16),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: AppSpacing.s12),

                      // Ítems
                      Text(
                        'Productos',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.s8),

                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ..._items.map((item) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.s8),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '${item.quantity} × Bs. ${item.unitPrice.toStringAsFixed(2)} (Precio ${item.priceType})',
                                            style: Theme.of(context).textTheme
                                                .labelMedium?.copyWith(
                                                  color: AppColors
                                                      .textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Bs. ${item.subtotal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )),

                      const SizedBox(height: AppSpacing.s12),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: AppSpacing.s12),

                      // Totales
                      _ReceiptRow(
                        label: 'Subtotal',
                        value:
                            'Bs. ${widget.sale.totalAmount.toStringAsFixed(2)}',
                      ),
                      if (widget.sale.discount > 0) ...[
                        const SizedBox(height: AppSpacing.s6),
                        _ReceiptRow(
                          label: 'Descuento',
                          value:
                              '- Bs. ${widget.sale.discount.toStringAsFixed(2)}',
                          valueColor: AppColors.error,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s8),
                      _ReceiptRow(
                        label: 'Total',
                        value:
                            'Bs. ${widget.sale.finalAmount.toStringAsFixed(2)}',
                        bold: true,
                        valueColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fila de recibo
class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: (bold
                    ? Theme.of(context).textTheme.headlineLarge
                    : Theme.of(context).textTheme.displaySmall)
                ?.copyWith(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}