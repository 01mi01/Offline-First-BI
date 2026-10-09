import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/report_provider.dart';
import '../../models/report_models.dart';
import '../../models/purchase_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/report_sale_card.dart';
import '../widgets/report_purchase_card.dart';
import '../../config/rounding.dart';

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

  Future<void> _exportPDF() async {
    setState(() => _isExporting = true);
    try {
      final exportRepository = ref.read(reportExportRepositoryProvider);
      if (widget.type == ReportType.sales) {
        final summary = ref
            .read(reportServiceProvider)
            .summarizeSaleRows(widget.saleRows);
        await exportRepository.exportSalesPdf(
          title: widget.title,
          rows: widget.saleRows,
          summary: summary,
        );
      } else {
        final rows = ref.read(purchaseReportRowsProvider(widget.purchases));
        final summary = ref.read(purchasesSummaryProvider(widget.purchases));
        await exportRepository.exportPurchasesPdf(
          title: widget.title,
          rows: rows,
          summary: summary,
        );
      }
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

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      final exportRepository = ref.read(reportExportRepositoryProvider);
      if (widget.type == ReportType.sales) {
        await exportRepository.exportSalesExcel(
          title: widget.title,
          rows: widget.saleRows,
        );
      } else {
        final rows = ref.read(purchaseReportRowsProvider(widget.purchases));
        await exportRepository.exportPurchasesExcel(
          title: widget.title,
          rows: rows,
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: widget.title,
        showBack: true,
        actions: [
          PopupMenuButton<String>(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryDark,
                    ),
                  )
                : const Icon(Icons.download_outlined, color: AppColors.primaryDark),
            onSelected: (v) {
              if (v == 'pdf') _exportPDF();
              if (v == 'excel') _exportExcel();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.error,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Exportar PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(
                      Icons.table_chart_outlined,
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
      ),
      body: widget.type == ReportType.sales
          ? _SalesDetailList(rows: widget.saleRows)
          : _PurchasesDetailList(purchases: widget.purchases),
    );
  }
}

// Lista detallada de ventas
class _SalesDetailList extends ConsumerWidget {
  final List<SaleReportRow> rows;

  const _SalesDetailList({required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reportServiceProvider).summarizeSaleRows(rows);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        _DetailSummary(
          rows: [
            _SummaryRow(label: 'Total ventas', value: '${summary.count}'),
            _SummaryRow(
              label: 'Ingresos totales',
              value: 'Bs. ${fixed2(summary.totalAmount)}',
              valueColor: AppColors.primaryDark,
            ),
            _SummaryRow(
              label: 'Descuentos',
              value: 'Bs. ${fixed2(summary.totalDiscount)}',
              valueColor: AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        ...rows.map((r) => ReportSaleCard(row: r)),
      ],
    );
  }
}

// Lista detallada de compras
class _PurchasesDetailList extends ConsumerWidget {
  final List<PurchaseModel> purchases;

  const _PurchasesDetailList({required this.purchases});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(purchasesSummaryProvider(purchases));
    final rows = ref.watch(purchaseReportRowsProvider(purchases));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        _DetailSummary(
          rows: [
            _SummaryRow(label: 'Total compras', value: '${summary.count}'),
            _SummaryRow(
              label: 'Gasto total',
              value: 'Bs. ${fixed2(summary.totalAmount)}',
              valueColor: AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        ...rows.map(
          (r) => ReportPurchaseCard(
            purchase: r.purchase,
            supplierName: r.supplierName,
            locationName: r.locationName,
            eventName: r.eventName,
          ),
        ),
      ],
    );
  }
}

// Resumen de detalle
class _DetailSummary extends StatelessWidget {
  final List<_SummaryRow> rows;

  const _DetailSummary({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows
            .map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      r.label,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      r.value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: r.valueColor ?? AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SummaryRow {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
}
