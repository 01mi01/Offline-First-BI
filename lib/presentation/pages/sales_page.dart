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
    final state = ref.watch(saleProvider);
    final clients = ref.watch(clientProvider).clients;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: 'Ventas', showBack: true),
      floatingActionButton: FloatingActionButton(
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
                  padding: const EdgeInsets.all(16),
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Fecha
                  Text(
                    _formatDate(sale.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Total y descuento
                  Row(
                    children: [
                      Text(
                        'Bs. ${sale.finalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      if (sale.discount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Desc. Bs. ${sale.discount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recibo de venta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
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
              const SizedBox(height: 16),

              // Contenido scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info del cliente y fecha
                      _ReceiptRow(
                          label: 'Cliente',
                          value: widget.clientName),
                      const SizedBox(height: 8),
                      _ReceiptRow(
                          label: 'Fecha',
                          value: _formatDate(widget.sale.date)),

                      if (widget.sale.locationId != null) ...[
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                        _ReceiptRow(
                            label: 'Notas', value: widget.sale.notes!),
                      ],

                      const SizedBox(height: 16),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),

                      // Ítems
                      const Text(
                        'Productos',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ..._items.map((item) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
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
                                            '${item.quantity} × Bs. ${item.unitPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.textSecondary,
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

                      const SizedBox(height: 12),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),

                      // Totales
                      _ReceiptRow(
                        label: 'Subtotal',
                        value:
                            'Bs. ${widget.sale.totalAmount.toStringAsFixed(2)}',
                      ),
                      if (widget.sale.discount > 0) ...[
                        const SizedBox(height: 6),
                        _ReceiptRow(
                          label: 'Descuento',
                          value:
                              '- Bs. ${widget.sale.discount.toStringAsFixed(2)}',
                          valueColor: AppColors.error,
                        ),
                      ],
                      const SizedBox(height: 8),
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
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}