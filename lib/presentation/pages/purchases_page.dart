import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/date_range_filter.dart';
import '../../application/location_options.dart';
import '../../application/purchase_provider.dart';
import '../../application/supplier_provider.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../../models/location_model.dart';
import '../../models/purchase_kind.dart';
import '../../models/purchase_model.dart';
import '../../models/purchase_item_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/purchase_dialog.dart';
import '../widgets/ios_controls.dart';
import '../widgets/ios_filters.dart';
import '../widgets/ios_group.dart';
import '../widgets/screen_header.dart';
import '../widgets/ios_sheet.dart';
import '../widgets/ios_style.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';

class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) => const PurchasesListBody();
}

class PurchasesListBody extends ConsumerWidget {
  const PurchasesListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseProvider);
    final suppliers = ref.watch(supplierProvider).suppliers;
    final kind = ref.watch(purchaseKindFilterProvider);
    final dates = ref.watch(purchaseDateFilterProvider);
    final timeFilter = ref.watch(purchaseTimeFilterProvider);
    final visible = state.purchases
        .where(
          (p) =>
              kind.includes(p) &&
              dates.matches(p.date) &&
              timeFilter.includes(p.date),
        )
        .toList();

    String supplierName(PurchaseModel purchase) =>
        suppliers.where((s) => s.id == purchase.supplierId).firstOrNull?.name ??
        'Sin proveedor';

    return ScreenScaffold.slivers(
      title: 'Compras',
      actions: [
        IconButton(
          tooltip: 'Nueva compra',
          icon: const Icon(
            Icons.add_rounded,
            size: 28,
            color: AppColors.primaryDark,
          ),
          onPressed: () => showPurchaseForm(context),
        ),
      ],
      slivers: [
        if (state.isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.purchases.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: IosEmptyState(
                icon: Icons.shopping_bag_rounded,
                title: 'No se registraron compras',
                actionLabel: 'Nueva compra',
                onAction: () => showPurchaseForm(context),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: Row(
                children: [
                  IosMenuButton<PurchaseKind>(
                    label: kind == PurchaseKind.all ? 'Tipo' : kind.label,
                    active: kind != PurchaseKind.all,
                    selected: kind,
                    options: [
                      for (final k in PurchaseKind.values)
                        IosMenuOption(
                          k,
                          k == PurchaseKind.all ? 'Ambos tipos' : k.label,
                        ),
                    ],
                    onSelected: (value) =>
                        ref.read(purchaseKindFilterProvider.notifier).state =
                            value,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: IosSegmented<RecordTimeFilter>(
                      segments: const [
                        IosSegment(
                          RecordTimeFilter.current,
                          'Compras actuales',
                        ),
                        IosSegment(RecordTimeFilter.all, 'Todas'),
                      ],
                      selected: timeFilter,
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(purchaseTimeFilterProvider.notifier).state =
                              value;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: IosDateRangeFilter(
              value: dates,
              onChanged: (value) =>
                  ref.read(purchaseDateFilterProvider.notifier).state = value,
            ),
          ),
          if (visible.isEmpty)
            const SliverToBoxAdapter(
              child: IosEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Sin resultados',
              ),
            )
          else
            IosSliverGroup(
              dividerIndent: AppIos.dividerIndentWithTile,
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final purchase = visible[index];
                return _PurchaseRow(
                  purchase: purchase,
                  supplierName: supplierName(purchase),
                  onTap: () => showPurchaseDetail(
                    context,
                    purchase,
                    supplierName(purchase),
                  ),
                  onEdit: purchase.isCanceled
                      ? null
                      : () => showPurchaseForm(context, purchase),
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

void showPurchaseForm(BuildContext context, [PurchaseModel? purchase]) {
  showIosSheet<void>(
    context,
    heightFactor: 0.94,
    builder: (_) => PurchaseDialog(purchase: purchase),
  );
}

void showPurchaseDetail(
  BuildContext context,
  PurchaseModel purchase,
  String supplierName,
) {
  showIosSheet<void>(
    context,
    heightFactor: 0.92,
    builder: (_) => _PurchaseDetailSheet(
      purchase: purchase,
      supplierName: supplierName,
      onEdit: purchase.isCanceled
          ? null
          : () => showPurchaseForm(context, purchase),
    ),
  );
}

class _PurchaseRow extends StatelessWidget {
  final PurchaseModel purchase;
  final String supplierName;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _PurchaseRow({
    required this.purchase,
    required this.supplierName,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final canceled = purchase.isCanceled;
    return IosRow(
      leading: IosTile(
        icon: purchase.isMaterial
            ? Icons.shopping_bag_rounded
            : Icons.receipt_long_rounded,
        color: canceled
            ? AppColors.iosTrack
            : (purchase.isMaterial ? AppColors.accent : AppColors.navy),
        iconColor: canceled ? AppColors.textSecondary : null,
      ),
      title: supplierName,
      titleColor: canceled ? AppColors.textSecondary : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text:
                  '${formatDateTime(purchase.date)}  ${purchase.isMaterial ? 'Material' : 'Gasto'}',
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
          if (purchase.description != null && purchase.description!.isNotEmpty)
            Text(
              purchase.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IosText.rowSubtitle(context),
            ),
        ],
      ),
      trailing: Text(
        'Bs. ${fixed2(purchase.totalAmount)}',
        style: IosText.rowTitle(
          context,
          color: canceled ? AppColors.textMuted : AppColors.textPrimary,
        ).copyWith(
          fontWeight: FontWeight.w600,
          decoration: canceled ? TextDecoration.lineThrough : null,
          decorationColor: AppColors.textMuted,
        ),
      ),
      chevron: true,
      onTap: onTap,
      onLongPress: onEdit,
    );
  }
}

class _PurchaseDetailSheet extends ConsumerStatefulWidget {
  final PurchaseModel purchase;
  final String supplierName;
  final VoidCallback? onEdit;

  const _PurchaseDetailSheet({
    required this.purchase,
    required this.supplierName,
    required this.onEdit,
  });

  @override
  ConsumerState<_PurchaseDetailSheet> createState() =>
      _PurchaseDetailSheetState();
}

class _PurchaseDetailSheetState extends ConsumerState<_PurchaseDetailSheet> {
  List<PurchaseItemModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.purchase.isMaterial) {
      _loadItems();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadItems() async {
    final items = await ref
        .read(purchaseProvider.notifier)
        .getItemsForPurchase(widget.purchase.id);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchase = widget.purchase;
    final location = purchase.locationId == null
        ? null
        : ref
              .watch(locationProvider)
              .locations
              .where((l) => l.id == purchase.locationId)
              .firstOrNull;
    final eventName = purchase.eventId == null
        ? null
        : ref
                  .watch(eventProvider)
                  .events
                  .where((e) => e.id == purchase.eventId)
                  .firstOrNull
                  ?.name ??
              '';

    return IosSheetScaffold(
      title: 'Detalle de compra',
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
            value: 'Bs. ${fixed2(purchase.totalAmount)}',
          ),
          IosSection(
            children: [
              IosValueRow(label: 'Proveedor', value: widget.supplierName),
              IosValueRow(label: 'Fecha', value: formatDateTime(purchase.date)),
              IosValueRow(
                label: 'Tipo',
                value: purchase.isMaterial
                    ? 'Compra de materiales'
                    : 'Gasto general',
              ),
              if (purchase.locationId != null)
                IosValueRow(label: 'Ubicación', value: _locationText(location)),
              if (purchase.eventId != null)
                IosValueRow(label: 'Evento', value: eventName ?? ''),
              if (purchase.description != null &&
                  purchase.description!.isNotEmpty)
                IosValueRow(label: 'Descripción', value: purchase.description!),
              if (purchase.notes != null && purchase.notes!.isNotEmpty)
                IosValueRow(label: 'Notas', value: purchase.notes!),
            ],
          ),
          if (purchase.isMaterial)
            IosSection(
              header: 'Materiales',
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.s16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  for (final item in _items)
                    IosRow(
                      title: item.materialName,
                      subtitle: Text(
                        '${formatMaterialQuantity(item.quantity, unitType: item.unitType, unitName: item.unitName)} × Bs. ${fixed2(item.unitPrice)}',
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
                label: 'Total',
                value: 'Bs. ${fixed2(purchase.totalAmount)}',
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
