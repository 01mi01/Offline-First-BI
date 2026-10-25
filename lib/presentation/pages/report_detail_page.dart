import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/report_provider.dart';
import '../../config/rounding.dart';
import '../../models/purchase_model.dart';
import '../../models/report_models.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_group.dart';
import '../widgets/filter_panel.dart';
import '../widgets/profile_button.dart';
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
      actions: const [ProfileButton()],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              0,
              AppSpacing.s16,
              AppSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilterDropdown<String?>(
                  label: 'Exportar',
                  placeholder: 'Elegir formato',
                  options: const [
                    FilterOption<String?>(
                      'excel',
                      'Exportar Excel',
                      icon: Icons.table_chart_rounded,
                      iconColor: AppColors.success,
                    ),
                    FilterOption<String?>(
                      'pdf',
                      'Exportar PDF',
                      icon: Icons.picture_as_pdf_rounded,
                      iconColor: AppColors.error,
                    ),
                  ],
                  current: null,
                  defaultValue: null,
                  onApply: (value) {
                    if (_isExporting) return;
                    if (value == 'pdf') _exportPdf();
                    if (value == 'excel') _exportExcel();
                  },
                ).build(context),
                if (_isExporting) ...[
                  const SizedBox(height: AppSpacing.s8),
                  const LinearProgressIndicator(color: AppColors.cyanDark),
                ],
              ],
            ),
          ),
        ),
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
                      value: 'Bs. ${fixed2(saleSummary.totalAmount)}',
                    ),
                    AppValueRow(
                      label: 'Descuentos',
                      value: 'Bs. ${fixed2(saleSummary.totalDiscount)}',
                    ),
                  ]
                : [
                    AppValueRow(
                      label: 'Total compras',
                      value: '${purchaseSummary!.count}',
                    ),
                    AppValueRow(
                      label: 'Gasto total',
                      value: 'Bs. ${fixed2(purchaseSummary.totalAmount)}',
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
