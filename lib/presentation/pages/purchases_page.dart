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
import '../widgets/app_group.dart';
import '../widgets/screen_header.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_style.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';
import '../widgets/flat_list.dart';
import '../widgets/record_detail.dart';
import '../widgets/transaction_rows.dart';
import '../../application/report_provider.dart' show purchaseItemsMapProvider;
import '../widgets/status_badge.dart';
import '../widgets/profile_button.dart';
import '../widgets/catalog_filter_bar.dart';
import '../widgets/filter_panel.dart';
import '../widgets/catalog_filter_bar.dart' show RecordTimeSwitcher;
import '../../application/record_search.dart';
import '../widgets/app_controls.dart' show AppSearchBar;
import '../widgets/empty_state.dart';

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
    final query = ref.watch(purchaseListQueryProvider);
    final visible = ref
        .watch(purchaseSearchIndexProvider)
        .search(query)
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

    final fields = <FilterField>[
      FilterDropdown<PurchaseKind>(
        label: 'Tipo',
        options: [
          for (final k in PurchaseKind.values)
            FilterOption(k, k == PurchaseKind.all ? 'Ambos tipos' : k.label),
        ],
        current: kind,
        defaultValue: PurchaseKind.all,
        onApply: (value) =>
            ref.read(purchaseKindFilterProvider.notifier).state = value,
      ),
      FilterDates(
        current: dates,
        onApply: (value) =>
            ref.read(purchaseDateFilterProvider.notifier).state = value,
      ),
    ];

    return ScreenScaffold.slivers(
      title: 'Compras',
      actions: const [ProfileButton()],
      floatingActionButton: FlatFab(
        heroTag: 'purchases_list_fab',
        onPressed: () => showPurchaseForm(context),
      ),
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
              child: AppEmptyState.list(
                plural: 'compras',
                icon: Icons.shopping_bag_rounded,
                actionLabel: 'Nueva compra',
                onAction: () => showPurchaseForm(context),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Column(
              children: [
                RecordTimeSwitcher(
                  value: timeFilter,
                  currentLabel: 'Compras actuales',
                  onChanged: (value) =>
                      ref.read(purchaseTimeFilterProvider.notifier).state = value,
                ),
                FilterArea(
                  search: AppSearchBar(
                    initialText: query,
                    hintText: 'Buscar por material o proveedor',
                    onChanged: (value) =>
                        ref.read(purchaseListQueryProvider.notifier).state =
                            value,
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
                final purchase = visible[index];
                return _PurchaseRow(
                  purchase: purchase,
                  supplierName: supplierName(purchase),
                  onTap: () => showPurchaseDetail(
                    context,
                    purchase,
                    supplierName(purchase),
                  ),
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

void showPurchaseForm(BuildContext context, [PurchaseModel? purchase]) {
  showAppSheet<void>(
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
  showAppSheet<void>(
    context,
    builder: (_) => _PurchaseDetailSheet(
      purchase: purchase,
      supplierName: supplierName,
      onEdit: purchase.isCanceled
          ? null
          : () => showPurchaseForm(context, purchase),
    ),
  );
}

class _PurchaseRow extends ConsumerWidget {
  final PurchaseModel purchase;
  final String supplierName;
  final VoidCallback onTap;

  const _PurchaseRow({
    required this.purchase,
    required this.supplierName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(purchaseItemsMapProvider).valueOrNull?[purchase.id];
    return purchaseRecordRow(
      materialNames: [for (final i in items ?? const []) i.materialName],
      description: purchase.description,
      isMaterial: purchase.isMaterial,
      supplierName: supplierName,
      date: purchase.date,
      amount: purchase.totalAmount,
      canceled: purchase.isCanceled,
      onTap: onTap,
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

    return RecordDetailSheet(
      title: 'Detalle de compra',
      onEdit: widget.onEdit,
      children: [
          AppBigTotal(
            label: 'Total',
            value: 'Bs. ${fixed2(purchase.totalAmount)}',
            pill: purchase.isCanceled ? const StatusBadge.canceled() : null,
          ),
          AppSection(
            children: [
              AppValueRow(label: 'Proveedor', value: widget.supplierName),
              AppValueRow(label: 'Fecha', value: formatDateTime(purchase.date)),
              AppValueRow(
                label: 'Tipo',
                valueWidget: StatusBadge.purchaseType(
                  isMaterial: purchase.isMaterial,
                ),
              ),
              if (purchase.locationId != null)
                AppValueRow(label: 'Ubicación', value: _locationText(location)),
              if (purchase.eventId != null)
                AppValueRow(label: 'Evento', value: eventName ?? ''),
              if (purchase.description != null &&
                  purchase.description!.isNotEmpty)
                AppValueRow(label: 'Descripción', value: purchase.description!),
              if (purchase.notes != null && purchase.notes!.isNotEmpty)
                AppValueRow(label: 'Notas', value: purchase.notes!),
            ],
          ),
          if (purchase.isMaterial)
            AppSection(
              header: 'Materiales',
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.s16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  for (final item in _items)
                    AppRow(
                      title: item.materialName,
                      subtitle: Text(
                        '${formatMaterialQuantity(item.quantity, unitType: item.unitType, unitName: item.unitName)} × Bs. ${fixed2(item.unitPrice)}',
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
                label: 'Total',
                value: 'Bs. ${fixed2(purchase.totalAmount)}',
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
