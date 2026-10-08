import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/date_range_filter.dart';
import '../../application/location_options.dart';
import '../../application/sale_provider.dart';
import '../../application/client_provider.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../../models/location_model.dart';
import '../../models/sale_model.dart';
import '../../models/sale_item_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/sale_dialog.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/catalog_filter_bar.dart';
import '../widgets/date_range_filter_bar.dart';
import '../widgets/status_badge.dart';
import '../../config/date_formatters.dart';

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
    final dates = ref.watch(saleDateFilterProvider);
    final timeFilter = ref.watch(saleTimeFilterProvider);
    final visible = state.sales
        .where((s) => dates.matches(s.date) && timeFilter.includes(s.date))
        .toList();

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
                'No se registraron ventas',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : Column(
              children: [
                // Arriba del todo, a la derecha: ocultar o no las ventas con
                // fecha futura.
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s12),
                  child: FilterChipRow(
                    chips: [
                      FilterMenuChip<RecordTimeFilter>(
                        icon: Icons.event_available_outlined,
                        label: timeFilter == RecordTimeFilter.current
                            ? 'Ventas actuales'
                            : 'Todas',
                        active: timeFilter != RecordTimeFilter.current,
                        selected: timeFilter,
                        options: const [
                          FilterOption(
                            RecordTimeFilter.current,
                            'Ventas actuales',
                          ),
                          FilterOption(RecordTimeFilter.all, 'Todas'),
                        ],
                        onSelected: (value) =>
                            ref.read(saleTimeFilterProvider.notifier).state =
                                value,
                      ),
                    ],
                  ),
                ),
                // Debajo: atajos de fecha y rango Desde/Hasta.
                DateRangeFilterBar(
                  value: dates,
                  onChanged: (value) =>
                      ref.read(saleDateFilterProvider.notifier).state = value,
                ),
                const SizedBox(height: AppSpacing.s8),
                Expanded(
                  child: visible.isEmpty
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
                            final sale = visible[index];
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
                ),
              ],
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
                  // Nombre del cliente (+ etiqueta si la venta está cancelada)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          clientName,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: sale.isCanceled
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                        ),
                      ),
                      if (sale.isCanceled) ...[
                        const SizedBox(width: AppSpacing.s8),
                        const StatusBadge.canceled(),
                      ],
                    ],
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
                              color: sale.isCanceled
                                  ? AppColors.textSecondary
                                  : AppColors.primary,
                              decoration: sale.isCanceled
                                  ? TextDecoration.lineThrough
                                  : null,
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
            // Una venta cancelada es solo historial: sin editar. Cancelar se hace
            // desde el formulario de edición.
            if (!sale.isCanceled) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.primary, size: 20),
                tooltip: 'Editar venta',
                onPressed: onEdit,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => formatDateTime(date);
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

  String _formatDate(DateTime date) => formatDateTime(date);

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
                      if (widget.sale.isCanceled) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Venta cancelada: su stock fue devuelto al inventario.',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(color: AppColors.error),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                      ],
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
                          value: _locationText(
                            ref
                                .watch(locationProvider)
                                .locations
                                .where((l) => l.id == widget.sale.locationId)
                                .firstOrNull,
                          ),
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
                      // Siempre visible: Subtotal - Descuento = Total.
                      const SizedBox(height: AppSpacing.s6),
                      _ReceiptRow(
                        label: 'Descuento',
                        value: widget.sale.discount > 0
                            ? '- Bs. ${widget.sale.discount.toStringAsFixed(2)}'
                            : 'Bs. 0.00',
                        valueColor: widget.sale.discount > 0
                            ? AppColors.error
                            : null,
                      ),
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

// Ubicación mostrada en el detalle: "Ciudad, País" y su zona.
String _locationText(LocationModel? l) => l == null ? '' : locationLabelWithZone(l);
