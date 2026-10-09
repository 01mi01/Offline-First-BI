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
import '../widgets/ios_controls.dart';
import '../widgets/ios_filters.dart';
import '../widgets/ios_group.dart';
import '../widgets/ios_scaffold.dart';
import '../widgets/ios_sheet.dart';
import '../widgets/ios_style.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';

class SalesPage extends StatelessWidget {
  final String backLabel;

  const SalesPage({super.key, this.backLabel = 'Ventas y Compras'});

  @override
  Widget build(BuildContext context) => SalesListBody(backLabel: backLabel);
}

class SalesListBody extends ConsumerWidget {
  final String backLabel;

  const SalesListBody({super.key, this.backLabel = 'Ventas y Compras'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleProvider);
    final clients = ref.watch(clientProvider).clients;
    final dates = ref.watch(saleDateFilterProvider);
    final timeFilter = ref.watch(saleTimeFilterProvider);
    final visible = state.sales
        .where((s) => dates.matches(s.date) && timeFilter.includes(s.date))
        .toList();

    String clientName(SaleModel sale) =>
        clients.where((c) => c.id == sale.clientId).firstOrNull?.name ??
        'Sin nombre';

    return IosLargeTitleScaffold(
      title: 'Ventas',
      backLabel: backLabel,
      actions: [
        IconButton(
          tooltip: 'Nueva venta',
          icon: const Icon(
            Icons.add_rounded,
            size: 28,
            color: AppColors.primaryDark,
          ),
          onPressed: () => showSaleForm(context),
        ),
      ],
      slivers: [
        if (state.isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.sales.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: IosEmptyState(
                icon: Icons.point_of_sale_outlined,
                title: 'No se registraron ventas',
                actionLabel: 'Nueva venta',
                onAction: () => showSaleForm(context),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                0,
                AppSpacing.s16,
                0,
              ),
              child: IosSegmented<RecordTimeFilter>(
                segments: const [
                  IosSegment(RecordTimeFilter.current, 'Ventas actuales'),
                  IosSegment(RecordTimeFilter.all, 'Todas'),
                ],
                selected: timeFilter,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(saleTimeFilterProvider.notifier).state = value;
                  }
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: IosDateRangeFilter(
              value: dates,
              onChanged: (value) =>
                  ref.read(saleDateFilterProvider.notifier).state = value,
            ),
          ),
          if (visible.isEmpty)
            const SliverToBoxAdapter(
              child: IosEmptyState(
                icon: Icons.search_off_outlined,
                title: 'Sin resultados',
              ),
            )
          else
            IosSliverGroup(
              dividerIndent: AppIos.dividerIndentWithTile,
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final sale = visible[index];
                return _SaleRow(
                  sale: sale,
                  clientName: clientName(sale),
                  onTap: () =>
                      showSaleReceipt(context, sale, clientName(sale)),
                  onEdit: sale.isCanceled
                      ? null
                      : () => showSaleForm(context, sale),
                );
              },
            ),
        ],
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.s32 + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

void showSaleForm(BuildContext context, [SaleModel? sale]) {
  showIosSheet<void>(
    context,
    heightFactor: 0.94,
    builder: (_) => SaleDialog(sale: sale),
  );
}

void showSaleReceipt(BuildContext context, SaleModel sale, String clientName) {
  showIosSheet<void>(
    context,
    heightFactor: 0.92,
    builder: (_) => _SaleReceiptSheet(
      sale: sale,
      clientName: clientName,
      onEdit: sale.isCanceled ? null : () => showSaleForm(context, sale),
    ),
  );
}

class _SaleRow extends StatelessWidget {
  final SaleModel sale;
  final String clientName;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _SaleRow({
    required this.sale,
    required this.clientName,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final canceled = sale.isCanceled;
    return IosRow(
      leading: IosTile(
        icon: Icons.point_of_sale_outlined,
        color: canceled ? AppColors.iosTrack : AppColors.primaryDark,
        iconColor: canceled ? AppColors.textSecondary : AppColors.surface,
      ),
      title: clientName,
      titleColor: canceled ? AppColors.textSecondary : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: formatDateTime(sale.date),
              children: [
                if (canceled)
                  const TextSpan(
                    text: '  Cancelada',
                    style: TextStyle(color: AppColors.error),
                  ),
              ],
            ),
            style: IosText.rowSubtitle(context),
          ),
          if (sale.discount > 0)
            Text(
              'Desc. Bs. ${fixed2(sale.discount)}',
              style: IosText.rowSubtitle(context),
            ),
        ],
      ),
      trailing: Text(
        'Bs. ${fixed2(sale.finalAmount)}',
        style: IosText.rowTitle(
          context,
          color: canceled ? AppColors.textSecondary : AppColors.textPrimary,
        ).copyWith(
          fontWeight: FontWeight.w600,
          decoration: canceled ? TextDecoration.lineThrough : null,
        ),
      ),
      chevron: true,
      onTap: onTap,
      onLongPress: onEdit,
    );
  }
}

class _SaleReceiptSheet extends ConsumerStatefulWidget {
  final SaleModel sale;
  final String clientName;
  final VoidCallback? onEdit;

  const _SaleReceiptSheet({
    required this.sale,
    required this.clientName,
    required this.onEdit,
  });

  @override
  ConsumerState<_SaleReceiptSheet> createState() => _SaleReceiptSheetState();
}

class _SaleReceiptSheetState extends ConsumerState<_SaleReceiptSheet> {
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

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final location = sale.locationId == null
        ? null
        : ref
              .watch(locationProvider)
              .locations
              .where((l) => l.id == sale.locationId)
              .firstOrNull;
    final eventName = sale.eventId == null
        ? null
        : ref
                  .watch(eventProvider)
                  .events
                  .where((e) => e.id == sale.eventId)
                  .firstOrNull
                  ?.name ??
              '';

    return IosSheetScaffold(
      title: 'Recibo de venta',
      leadingLabel: widget.onEdit == null ? null : 'Editar',
      onLeading: () {
        Navigator.pop(context);
        widget.onEdit?.call();
      },
      trailingLabel: 'Cerrar',
      child: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s32),
        children: [
          IosBigTotal(
            label: 'Total',
            value: 'Bs. ${fixed2(sale.finalAmount)}',
            note: sale.isCanceled
                ? 'Venta cancelada: su stock fue devuelto al inventario.'
                : null,
          ),
          IosSection(
            children: [
              IosValueRow(label: 'Cliente', value: widget.clientName),
              IosValueRow(label: 'Fecha', value: formatDateTime(sale.date)),
              if (sale.locationId != null)
                IosValueRow(label: 'Ubicación', value: _locationText(location)),
              if (sale.eventId != null)
                IosValueRow(label: 'Evento', value: eventName ?? ''),
              if (sale.notes != null && sale.notes!.isNotEmpty)
                IosValueRow(label: 'Notas', value: sale.notes!),
            ],
          ),
          IosSection(
            header: 'Productos',
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.s16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final item in _items)
                  IosRow(
                    title: item.productName,
                    subtitle: Text(
                      '${item.quantity} × Bs. ${fixed2(item.unitPrice)} (Precio ${item.priceType})',
                      style: IosText.rowSubtitle(context),
                    ),
                    trailing: Text(
                      'Bs. ${fixed2(item.subtotal)}',
                      style: IosText.rowTitle(context).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            ],
          ),
          IosSection(
            children: [
              IosValueRow(
                label: 'Subtotal',
                value: 'Bs. ${fixed2(sale.totalAmount)}',
              ),
              IosValueRow(
                label: 'Descuento',
                value: sale.discount > 0
                    ? '- Bs. ${fixed2(sale.discount)}'
                    : 'Bs. 0.00',
                valueColor: sale.discount > 0 ? AppColors.error : null,
              ),
              IosValueRow(
                label: 'Total',
                value: 'Bs. ${fixed2(sale.finalAmount)}',
                bold: true,
                valueColor: AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _locationText(LocationModel? l) => l == null ? '' : locationLabelWithZone(l);
