import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/purchase_provider.dart';
import '../../application/supplier_provider.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../../models/purchase_kind.dart';
import '../../models/purchase_model.dart';
import '../../models/purchase_item_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/purchase_dialog.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/catalog_filter_bar.dart';
import '../../config/date_formatters.dart';

class PurchasesPage extends ConsumerWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: 'Compras', showBack: true),
      body: const PurchasesListBody(),
    );
  }
}

// Contenido de la lista de compras, sin AppBar propia. Se usa tanto en
// PurchasesPage (con AppBar y back) como embebido en el tab "Ventas y
// Compras" de la navegación inferior (sin AppBar).
class PurchasesListBody extends ConsumerWidget {
  const PurchasesListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseProvider);
    final suppliers = ref.watch(supplierProvider).suppliers;
    final kind = ref.watch(purchaseKindFilterProvider);
    final visible = state.purchases.where(kind.includes).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
        heroTag: 'purchases_list_body_fab',
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, null),
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.purchases.isEmpty
          ? Center(
              child: Text(
                'No se registraron compras',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : Column(
              children: [
                // Filtro por tipo: solo materiales, solo gastos o ambos.
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s12),
                  child: FilterChipRow(
                    chips: [
                      FilterMenuChip<PurchaseKind>(
                        icon: Icons.filter_list,
                        label: kind == PurchaseKind.all
                            ? 'Tipo'
                            : kind.label,
                        active: kind != PurchaseKind.all,
                        selected: kind,
                        options: [
                          for (final k in PurchaseKind.values)
                            FilterOption(
                              k,
                              k == PurchaseKind.all ? 'Ambos tipos' : k.label,
                            ),
                        ],
                        onSelected: (value) => ref
                            .read(purchaseKindFilterProvider.notifier)
                            .state = value,
                      ),
                    ],
                  ),
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
                            final purchase = visible[index];
                            final supplier = suppliers
                                .where((s) => s.id == purchase.supplierId)
                                .firstOrNull;
                            return _PurchaseCard(
                              purchase: purchase,
                              supplierName: supplier?.name ?? 'Sin proveedor',
                              onEdit: () => _showDialog(context, purchase),
                              onTap: () => _showDetail(
                                context,
                                ref,
                                purchase,
                                supplier?.name ?? 'Sin proveedor',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _showDialog(BuildContext context, PurchaseModel? purchase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PurchaseDialog(purchase: purchase),
    );
  }

  void _showDetail(
    BuildContext context,
    WidgetRef ref,
    PurchaseModel purchase,
    String supplierName,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) =>
          _PurchaseDetailDialog(purchase: purchase, supplierName: supplierName),
    );
  }
}

// Tarjeta de compra
class _PurchaseCard extends StatelessWidget {
  final PurchaseModel purchase;
  final String supplierName;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const _PurchaseCard({
    required this.purchase,
    required this.supplierName,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          supplierName,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                      // Pill material o gasto
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8,
                          vertical: AppSpacing.s2,
                        ),
                        decoration: BoxDecoration(
                          // "Gasto" va en el color neutro de texto (ni verde
                          // ni el rojo de las acciones destructivas).
                          color: purchase.isMaterial
                              ? AppColors.primary.withOpacity(0.1)
                              : AppColors.textSecondary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          purchase.isMaterial ? 'Material' : 'Gasto',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: purchase.isMaterial
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    _formatDate(purchase.date),
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (purchase.description != null &&
                      purchase.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      purchase.description!,
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s6),
                  Text(
                    'Bs. ${purchase.totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.displayMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => formatDateTime(date);
}

// Diálogo de detalle de compra
class _PurchaseDetailDialog extends ConsumerStatefulWidget {
  final PurchaseModel purchase;
  final String supplierName;

  const _PurchaseDetailDialog({
    required this.purchase,
    required this.supplierName,
  });

  @override
  ConsumerState<_PurchaseDetailDialog> createState() =>
      _PurchaseDetailDialogState();
}

class _PurchaseDetailDialogState extends ConsumerState<_PurchaseDetailDialog> {
  List<PurchaseItemModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.purchase.isMaterial)
      _loadItems();
    else
      setState(() => _loading = false);
  }

  Future<void> _loadItems() async {
    final items = await ref
        .read(purchaseProvider.notifier)
        .getItemsForPurchase(widget.purchase.id);
    if (mounted)
      setState(() {
        _items = items;
        _loading = false;
      });
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
                      'Detalle de compra',
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
                      _DetailRow(
                        label: 'Proveedor',
                        value: widget.supplierName,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      _DetailRow(
                        label: 'Fecha',
                        value: _formatDate(widget.purchase.date),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      _DetailRow(
                        label: 'Tipo',
                        value: widget.purchase.isMaterial
                            ? 'Compra de materiales'
                            : 'Gasto general',
                      ),
                      if (widget.purchase.locationId != null) ...[
                        const SizedBox(height: AppSpacing.s8),
                        _DetailRow(
                          label: 'Ubicación',
                          value:
                              ref
                                  .watch(locationProvider)
                                  .locations
                                  .where(
                                    (l) => l.id == widget.purchase.locationId,
                                  )
                                  .firstOrNull
                                  ?.city ??
                              '',
                        ),
                      ],
                      if (widget.purchase.eventId != null) ...[
                        const SizedBox(height: AppSpacing.s8),
                        _DetailRow(
                          label: 'Evento',
                          value:
                              ref
                                  .watch(eventProvider)
                                  .events
                                  .where((e) => e.id == widget.purchase.eventId)
                                  .firstOrNull
                                  ?.name ??
                              '',
                        ),
                      ],
                      if (widget.purchase.description != null &&
                          widget.purchase.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s8),
                        _DetailRow(
                          label: 'Descripción',
                          value: widget.purchase.description!,
                        ),
                      ],
                      if (widget.purchase.notes != null &&
                          widget.purchase.notes!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s8),
                        _DetailRow(
                          label: 'Notas',
                          value: widget.purchase.notes!,
                        ),
                      ],

                      if (widget.purchase.isMaterial) ...[
                        const SizedBox(height: AppSpacing.s16),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          'Materiales',
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
                          ..._items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.s8,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.materialName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '${formatNumber(item.quantity)} × Bs. ${item.unitPrice.toStringAsFixed(2)}',
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
                            ),
                          ),
                      ],

                      const SizedBox(height: AppSpacing.s12),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: AppSpacing.s8),
                      _DetailRow(
                        label: 'Total',
                        value:
                            'Bs. ${widget.purchase.totalAmount.toStringAsFixed(2)}',
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

// Fila de detalle
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _DetailRow({
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
          width: 90,
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
