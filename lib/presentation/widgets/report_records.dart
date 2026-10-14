import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sale_provider.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';
import '../../models/purchase_item_model.dart';
import '../../models/report_models.dart';
import '../../models/sale_item_model.dart';
import '../../theme/app_theme.dart';
import 'app_group.dart';
import 'app_sheet.dart';
import 'app_style.dart';
import 'record_detail.dart';
import 'record_list.dart';
import 'status_badge.dart';

class ReportSaleRowTile extends StatelessWidget {
  final SaleReportRow row;

  const ReportSaleRowTile({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final discount = row.discountAmount;
    return RecordRow(
      title: row.clientName,
      details: [
        RecordLine(formatDateTime(row.sale.date)),
        if (row.locationName != null) RecordLine(row.locationName!),
        if (row.eventName != null) RecordLine(row.eventName!),
        if (discount > 0) RecordLine('Desc. Bs. ${fixed2(discount)}'),
      ],
      trailing: RecordValue('Bs. ${fixed2(row.netAmount)}'),
      onTap: () => showAppSheet<void>(
        context,
        builder: (_) => _ReportSaleDetail(row: row),
      ),
    );
  }
}

class _ReportSaleDetail extends ConsumerStatefulWidget {
  final SaleReportRow row;

  const _ReportSaleDetail({required this.row});

  @override
  ConsumerState<_ReportSaleDetail> createState() => _ReportSaleDetailState();
}

class _ReportSaleDetailState extends ConsumerState<_ReportSaleDetail> {
  List<_Line>? _lines;

  @override
  void initState() {
    super.initState();
    final lines = widget.row.lines;
    if (lines != null) {
      _lines = [
        for (final l in lines) _Line(l.item.productName, _saleDetail(l.item), l.netAmount),
      ];
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final items = await ref
        .read(saleProvider.notifier)
        .getItemsForSale(widget.row.sale.id);
    if (!mounted) return;
    setState(() {
      _lines = [
        for (final i in items) _Line(i.productName, _saleDetail(i), i.subtotal),
      ];
    });
  }

  String _saleDetail(SaleItemModel item) =>
      '${item.quantity} × Bs. ${fixed2(item.unitPrice)} (Precio ${item.priceType})';

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final lines = _lines;
    return RecordDetailSheet(
      title: 'Detalle de venta',
      children: [
        AppBigTotal(label: 'Total', value: 'Bs. ${fixed2(row.netAmount)}'),
        AppSection(
          children: [
            AppValueRow(label: 'Cliente', value: row.clientName),
            AppValueRow(label: 'Fecha', value: formatDateTime(row.sale.date)),
            if (row.locationName != null)
              AppValueRow(label: 'Ubicación', value: row.locationName!),
            if (row.eventName != null)
              AppValueRow(label: 'Evento', value: row.eventName!),
          ],
        ),
        AppSection(
          header: 'Productos',
          children: [
            if (lines == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.s16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final l in lines) _lineRow(context, l),
          ],
        ),
        AppSection(
          children: [
            AppValueRow(
              label: 'Subtotal',
              value: 'Bs. ${fixed2(row.subtotalAmount)}',
            ),
            AppValueRow(
              label: 'Descuento',
              value: row.discountAmount > 0
                  ? '- Bs. ${fixed2(row.discountAmount)}'
                  : 'Bs. 0.00',
              valueColor: row.discountAmount > 0 ? AppColors.error : null,
            ),
            AppValueRow(
              label: 'Total',
              value: 'Bs. ${fixed2(row.netAmount)}',
              bold: true,
              valueColor: AppColors.textPrimary,
            ),
          ],
        ),
      ],
    );
  }
}

class _Line {
  final String title;
  final String detail;
  final double amount;

  const _Line(this.title, this.detail, this.amount);
}

Widget _lineRow(BuildContext context, _Line line) => AppRow(
  title: line.title,
  subtitle: Text(line.detail, style: AppText.rowSubtitle(context)),
  trailing: Text(
    'Bs. ${fixed2(line.amount)}',
    style: AppText.rowTitle(context).copyWith(fontWeight: FontWeight.w600),
  ),
);

class ReportPurchaseRowTile extends StatelessWidget {
  final PurchaseReportRow row;

  const ReportPurchaseRowTile({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final purchase = row.purchase;
    return RecordRow(
      title: row.supplierName,
      details: [
        RecordLine(formatDateTime(purchase.date)),
        if (purchase.description != null && purchase.description!.isNotEmpty)
          RecordLine(purchase.description!, maxLines: 1),
        if (row.locationName != null) RecordLine(row.locationName!),
        if (row.eventName != null) RecordLine(row.eventName!),
      ],
      pill: StatusBadge.purchaseType(isMaterial: purchase.isMaterial),
      trailing: RecordValue('Bs. ${fixed2(purchase.totalAmount)}'),
      onTap: () => showAppSheet<void>(
        context,
        builder: (_) => _ReportPurchaseDetail(row: row),
      ),
    );
  }
}

class _ReportPurchaseDetail extends StatelessWidget {
  final PurchaseReportRow row;

  const _ReportPurchaseDetail({required this.row});

  String _detail(PurchaseItemModel item) =>
      '${formatMaterialQuantity(item.quantity, unitType: item.unitType, unitName: item.unitName)} × Bs. ${fixed2(item.unitPrice)}';

  @override
  Widget build(BuildContext context) {
    final purchase = row.purchase;
    return RecordDetailSheet(
      title: 'Detalle de compra',
      children: [
        AppBigTotal(
          label: 'Total',
          value: 'Bs. ${fixed2(purchase.totalAmount)}',
        ),
        AppSection(
          children: [
            AppValueRow(label: 'Proveedor', value: row.supplierName),
            AppValueRow(label: 'Fecha', value: formatDateTime(purchase.date)),
            AppValueRow(
              label: 'Tipo',
              valueWidget: StatusBadge.purchaseType(
                isMaterial: purchase.isMaterial,
              ),
            ),
            if (row.locationName != null)
              AppValueRow(label: 'Ubicación', value: row.locationName!),
            if (row.eventName != null)
              AppValueRow(label: 'Evento', value: row.eventName!),
            if (purchase.description != null &&
                purchase.description!.isNotEmpty)
              AppValueRow(label: 'Descripción', value: purchase.description!),
          ],
        ),
        if (purchase.isMaterial && row.items.isNotEmpty)
          AppSection(
            header: 'Materiales',
            children: [
              for (final i in row.items)
                _lineRow(context, _Line(i.materialName, _detail(i), i.subtotal)),
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
