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
import '../widgets/app_group.dart';
import '../widgets/screen_header.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_style.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';
import '../widgets/flat_list.dart';
import '../widgets/record_detail.dart';
import '../widgets/record_list.dart';
import '../widgets/status_badge.dart';
import '../widgets/profile_button.dart';
import '../widgets/catalog_filter_bar.dart';
import '../widgets/filter_panel.dart';
import '../widgets/catalog_filter_bar.dart' show RecordTimeSwitcher;
import '../../application/record_search.dart';
import '../widgets/app_controls.dart' show AppSearchBar;
import '../widgets/empty_state.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) => const SalesListBody();
}

class SalesListBody extends ConsumerWidget {
  const SalesListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleProvider);
    final clients = ref.watch(clientProvider).clients;
    final dates = ref.watch(saleDateFilterProvider);
    final timeFilter = ref.watch(saleTimeFilterProvider);
    final query = ref.watch(saleListQueryProvider);
    final visible = ref
        .watch(saleSearchIndexProvider)
        .search(query)
        .where((s) => dates.matches(s.date) && timeFilter.includes(s.date))
        .toList();

    String clientName(SaleModel sale) =>
        clients.where((c) => c.id == sale.clientId).firstOrNull?.name ??
        'Sin nombre';

    final fields = <FilterField>[
      FilterDates(
        current: dates,
        onApply: (value) =>
            ref.read(saleDateFilterProvider.notifier).state = value,
      ),
    ];

    return ScreenScaffold.slivers(
      title: 'Ventas',
      actions: const [ProfileButton()],
      floatingActionButton: FlatFab(
        heroTag: 'sales_list_fab',
        onPressed: () => showSaleForm(context),
      ),
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
              child: AppEmptyState.list(
                plural: 'ventas',
                icon: Icons.point_of_sale_rounded,
                actionLabel: 'Nueva venta',
                onAction: () => showSaleForm(context),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Column(
              children: [
                RecordTimeSwitcher(
                  value: timeFilter,
                  currentLabel: 'Ventas actuales',
                  onChanged: (value) =>
                      ref.read(saleTimeFilterProvider.notifier).state = value,
                ),
                FilterArea(
                  search: AppSearchBar(
                    initialText: query,
                    hintText: 'Buscar por producto o cliente',
                    onChanged: (value) =>
                        ref.read(saleListQueryProvider.notifier).state = value,
                  ),
                  fields: fields,
                ),
              ],
            ),
          ),
          if (visible.isEmpty)
            const SliverToBoxAdapter(
              child: AppEmptyState.noMatch(),
            )
          else
            AppSliverGroup(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final sale = visible[index];
                return _SaleRow(
                  sale: sale,
                  clientName: clientName(sale),
                  onTap: () =>
                      showSaleReceipt(context, sale, clientName(sale)),
                );
              },
            ),
        ],
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppFlat.listWithFab.bottom + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

void showSaleForm(BuildContext context, [SaleModel? sale]) {
  showAppSheet<void>(
    context,
    heightFactor: 0.94,
    builder: (_) => SaleDialog(sale: sale),
  );
}

void showSaleReceipt(BuildContext context, SaleModel sale, String clientName) {
  showAppSheet<void>(
    context,
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

  const _SaleRow({
    required this.sale,
    required this.clientName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canceled = sale.isCanceled;
    return RecordRow(
      title: clientName,
      titleColor: canceled ? AppColors.textSecondary : null,
      details: [
        RecordLine(formatDateTime(sale.date)),
        if (sale.discount > 0) RecordLine('Desc. Bs. ${fixed2(sale.discount)}'),
      ],
      pill: canceled ? const StatusBadge.canceled() : null,
      trailing: RecordValue(
        'Bs. ${fixed2(sale.finalAmount)}',
        canceled: canceled,
      ),
      onTap: onTap,
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

    return RecordDetailSheet(
      title: 'Recibo de venta',
      onEdit: widget.onEdit,
      children: [
          AppBigTotal(
            label: 'Total',
            value: 'Bs. ${fixed2(sale.finalAmount)}',
            pill: sale.isCanceled ? const StatusBadge.canceled() : null,
            note: sale.isCanceled
                ? 'Su stock fue devuelto al inventario.'
                : null,
          ),
          AppSection(
            children: [
              AppValueRow(label: 'Cliente', value: widget.clientName),
              AppValueRow(label: 'Fecha', value: formatDateTime(sale.date)),
              if (sale.locationId != null)
                AppValueRow(label: 'Ubicación', value: _locationText(location)),
              if (sale.eventId != null)
                AppValueRow(label: 'Evento', value: eventName ?? ''),
              if (sale.notes != null && sale.notes!.isNotEmpty)
                AppValueRow(label: 'Notas', value: sale.notes!),
            ],
          ),
          AppSection(
            header: 'Productos',
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.s16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final item in _items)
                  AppRow(
                    title: item.productName,
                    subtitle: Text(
                      '${item.quantity} × Bs. ${fixed2(item.unitPrice)} (Precio ${item.priceType})',
                      style: AppText.rowSubtitle(context),
                    ),
                    trailing: Text(
                      'Bs. ${fixed2(item.subtotal)}',
                      style: AppText.rowTitle(context).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            ],
          ),
          AppSection(
            children: [
              AppValueRow(
                label: 'Subtotal',
                value: 'Bs. ${fixed2(sale.totalAmount)}',
              ),
              AppValueRow(
                label: 'Descuento',
                value: sale.discount > 0
                    ? '- Bs. ${fixed2(sale.discount)}'
                    : 'Bs. 0.00',
                valueColor: sale.discount > 0 ? AppColors.error : null,
              ),
              AppValueRow(
                label: 'Total',
                value: 'Bs. ${fixed2(sale.finalAmount)}',
                bold: true,
                valueColor: AppColors.textPrimary,
              ),
            ],
          ),
      ],
    );
  }
}

String _locationText(LocationModel? l) => l == null ? '' : locationLabelWithZone(l);
