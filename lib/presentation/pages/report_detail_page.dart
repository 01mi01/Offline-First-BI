import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/report_provider.dart';
import '../../config/rounding.dart';
import '../../models/purchase_model.dart';
import '../../models/report_models.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_group.dart';
import '../widgets/report_records.dart';
import '../widgets/screen_header.dart';

enum ReportType { sales, purchases }

class ReportDetailPage extends ConsumerStatefulWidget {
  final String title;
  final ReportType type;
  final List<SaleReportRow> saleRows;
  final List<PurchaseModel> purchases;

  const ReportDetailPage({
    super.key,
    required this.title,
    required this.type,
    required this.saleRows,
    required this.purchases,
  });

  @override
  ConsumerState<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends ConsumerState<ReportDetailPage> {
  bool _isExporting = false;

  Future<void> _export(Future<void> Function() action) async {
    setState(() => _isExporting = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf() => _export(() async {
    final exports = ref.read(reportExportRepositoryProvider);
    if (widget.type == ReportType.sales) {
      final summary = ref
          .read(reportServiceProvider)
          .summarizeSaleRows(widget.saleRows);
      await exports.exportSalesPdf(
        title: widget.title,
        rows: widget.saleRows,
        summary: summary,
      );
    } else {
      final rows = ref.read(purchaseReportRowsProvider(widget.purchases));
      final summary = ref.read(purchasesSummaryProvider(widget.purchases));
      await exports.exportPurchasesPdf(
        title: widget.title,
        rows: rows,
        summary: summary,
      );
    }
  });

  Future<void> _exportExcel() => _export(() async {
    final exports = ref.read(reportExportRepositoryProvider);
    if (widget.type == ReportType.sales) {
      await exports.exportSalesExcel(
        title: widget.title,
        rows: widget.saleRows,
      );
    } else {
      final rows = ref.read(purchaseReportRowsProvider(widget.purchases));
      await exports.exportPurchasesExcel(title: widget.title, rows: rows);
    }
  });

  @override
  Widget build(BuildContext context) {
    final isSales = widget.type == ReportType.sales;
    final saleSummary = isSales
        ? ref.watch(reportServiceProvider).summarizeSaleRows(widget.saleRows)
        : null;
    final purchaseSummary = isSales
        ? null
        : ref.watch(purchasesSummaryProvider(widget.purchases));
    final purchaseRows = isSales
        ? const <PurchaseReportRow>[]
        : ref.watch(purchaseReportRowsProvider(widget.purchases));

    return ScreenScaffold.slivers(
      title: widget.title,
      actions: [
        PopupMenuButton<String>(
          key: const ValueKey('export-menu'),
          iconSize: AppHeader.iconSize,
          icon: _isExporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.cyanDark,
                  ),
                )
              : const Icon(Icons.download_rounded, color: AppColors.cyanDark),
          onSelected: (v) {
            if (v == 'pdf') _exportPdf();
            if (v == 'excel') _exportExcel();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              key: ValueKey('export-pdf'),
              value: 'pdf',
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text('Exportar PDF'),
                ],
              ),
            ),
            PopupMenuItem(
              key: ValueKey('export-excel'),
              value: 'excel',
              child: Row(
                children: [
                  Icon(
                    Icons.table_chart_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text('Exportar Excel'),
                ],
              ),
            ),
          ],
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: AppSection(
            children: isSales
                ? [
                    AppValueRow(
                      label: 'Total ventas',
                      value: '${saleSummary!.count}',
                    ),
                    AppValueRow(
                      label: 'Ingresos totales',
                      value: 'Bs. ${fixed2(saleSummary.totalAmount)}',
                    ),
                    AppValueRow(
                      label: 'Descuentos',
                      value: 'Bs. ${fixed2(saleSummary.totalDiscount)}',
                    ),
                  ]
                : [
                    AppValueRow(
                      label: 'Total compras',
                      value: '${purchaseSummary!.count}',
                    ),
                    AppValueRow(
                      label: 'Gasto total',
                      value: 'Bs. ${fixed2(purchaseSummary.totalAmount)}',
                    ),
                  ],
          ),
        ),
        AppSliverGroup(
          itemCount: isSales ? widget.saleRows.length : purchaseRows.length,
          itemBuilder: (context, index) => isSales
              ? ReportSaleRowTile(row: widget.saleRows[index])
              : ReportPurchaseRowTile(row: purchaseRows[index]),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.s24 + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}
