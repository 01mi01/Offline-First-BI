import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../../application/client_provider.dart';
import '../../application/supplier_provider.dart';
import '../../application/location_provider.dart';
import '../../application/event_provider.dart';
import '../../models/sale_model.dart';
import '../../models/purchase_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/report_sale_card.dart';
import '../widgets/report_purchase_card.dart';

enum ReportType { sales, purchases }

class ReportDetailPage extends ConsumerStatefulWidget {
  final String title;
  final ReportType type;
  final List<SaleModel> sales;
  final List<PurchaseModel> purchases;

  const ReportDetailPage({
    super.key,
    required this.title,
    required this.type,
    required this.sales,
    required this.purchases,
  });

  @override
  ConsumerState<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends ConsumerState<ReportDetailPage> {
  bool _isExporting = false;
  
  // Para PDF y Excel
  String _fmt(DateTime date) {
    return '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
  }

  String _fmtShort(DateTime date) {
    return '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
  }

  Future<void> _exportPDF() async {
    setState(() => _isExporting = true);
    try {
      final clients = ref.read(clientProvider).clients;
      final suppliers = ref.read(supplierProvider).suppliers;
      final locations = ref.read(locationProvider).locations;
      final events = ref.read(eventProvider).events;
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) {
            if (widget.type == ReportType.sales) {
              final total = widget.sales.fold(0.0, (s, e) => s + e.finalAmount);
              return [
                pw.Text(
                  widget.title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generado el ${_fmt(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 16),
                _pdfSummary([
                  'Total ventas: ${widget.sales.length}',
                  'Ingresos: Bs. ${total.toStringAsFixed(2)}',
                ]),
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    _pdfHeaderRow([
                      'Fecha',
                      'Cliente',
                      'Ubicación',
                      'Evento',
                      'Total',
                    ]),
                    ...widget.sales.map((s) {
                      final client = clients
                          .where((c) => c.id == s.clientId)
                          .firstOrNull;
                      final location = locations
                          .where((l) => l.id == s.locationId)
                          .firstOrNull;
                      final event = events
                          .where((e) => e.id == s.eventId)
                          .firstOrNull;
                      return _pdfRow([
                        _fmtShort(s.date),
                        client?.name ?? '-',
                        location?.city ?? '-',
                        event?.name ?? '-',
                        'Bs. ${s.finalAmount.toStringAsFixed(2)}',
                      ]);
                    }),
                  ],
                ),
              ];
            } else {
              final total = widget.purchases.fold(
                0.0,
                (s, e) => s + e.totalAmount,
              );
              return [
                pw.Text(
                  widget.title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generado el ${_fmt(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 16),
                _pdfSummary([
                  'Total compras: ${widget.purchases.length}',
                  'Gasto: Bs. ${total.toStringAsFixed(2)}',
                ]),
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    _pdfHeaderRow([
                      'Fecha',
                      'Proveedor',
                      'Tipo',
                      'Descripción',
                      'Total',
                    ]),
                    ...widget.purchases.map((p) {
                      final supplier = suppliers
                          .where((s) => s.id == p.supplierId)
                          .firstOrNull;
                      return _pdfRow([
                        _fmtShort(p.date),
                        supplier?.name ?? '-',
                        p.isMaterial ? 'Material' : 'Gasto',
                        p.description ?? '-',
                        'Bs. ${p.totalAmount.toStringAsFixed(2)}',
                      ]);
                    }),
                  ],
                ),
              ];
            }
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/${widget.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: widget.title);
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
      final clients = ref.read(clientProvider).clients;
      final suppliers = ref.read(supplierProvider).suppliers;
      final locations = ref.read(locationProvider).locations;
      final events = ref.read(eventProvider).events;
      final excel = xl.Excel.createExcel();
      final sheet = excel['Reporte'];
      excel.setDefaultSheet('Reporte');
      excel.delete('Sheet1');

      if (widget.type == ReportType.sales) {
        sheet.appendRow([
          xl.TextCellValue('Fecha'),
          xl.TextCellValue('Cliente'),
          xl.TextCellValue('Ubicación'),
          xl.TextCellValue('Evento'),
          xl.TextCellValue('Subtotal'),
          xl.TextCellValue('Descuento'),
          xl.TextCellValue('Total'),
          xl.TextCellValue('Notas'),
        ]);
        for (final s in widget.sales) {
          final client = clients.where((c) => c.id == s.clientId).firstOrNull;
          final location = locations
              .where((l) => l.id == s.locationId)
              .firstOrNull;
          final event = events.where((e) => e.id == s.eventId).firstOrNull;
          sheet.appendRow([
            xl.TextCellValue(_fmtShort(s.date)),
            xl.TextCellValue(client?.name ?? '-'),
            xl.TextCellValue(location?.city ?? '-'),
            xl.TextCellValue(event?.name ?? '-'),
            xl.DoubleCellValue(s.totalAmount),
            xl.DoubleCellValue(s.discount),
            xl.DoubleCellValue(s.finalAmount),
            xl.TextCellValue(s.notes ?? ''),
          ]);
        }
      } else {
        sheet.appendRow([
          xl.TextCellValue('Fecha'),
          xl.TextCellValue('Proveedor'),
          xl.TextCellValue('Tipo'),
          xl.TextCellValue('Descripción'),
          xl.TextCellValue('Ubicación'),
          xl.TextCellValue('Evento'),
          xl.TextCellValue('Total'),
          xl.TextCellValue('Notas'),
        ]);
        for (final p in widget.purchases) {
          final supplier = suppliers
              .where((s) => s.id == p.supplierId)
              .firstOrNull;
          final location = locations
              .where((l) => l.id == p.locationId)
              .firstOrNull;
          final event = events.where((e) => e.id == p.eventId).firstOrNull;
          sheet.appendRow([
            xl.TextCellValue(_fmtShort(p.date)),
            xl.TextCellValue(supplier?.name ?? '-'),
            xl.TextCellValue(p.isMaterial ? 'Material' : 'Gasto'),
            xl.TextCellValue(p.description ?? '-'),
            xl.TextCellValue(location?.city ?? '-'),
            xl.TextCellValue(event?.name ?? '-'),
            xl.DoubleCellValue(p.totalAmount),
            xl.TextCellValue(p.notes ?? ''),
          ]);
        }
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/${widget.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: widget.title);
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

  pw.Widget _pdfSummary(List<String> items) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: items
            .map((t) => pw.Text(t, style: const pw.TextStyle(fontSize: 10)))
            .toList(),
      ),
    );
  }

  pw.TableRow _pdfHeaderRow(List<String> cells) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: cells
          .map(
            (c) => pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                c,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _pdfRow(List<String> cells) {
    return pw.TableRow(
      children: cells
          .map(
            (c) => pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(c, style: const pw.TextStyle(fontSize: 9)),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientProvider).clients;
    final suppliers = ref.watch(supplierProvider).suppliers;
    final locations = ref.watch(locationProvider).locations;
    final events = ref.watch(eventProvider).events;

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
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.download_outlined, color: AppColors.primary),
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
          ? _SalesDetailList(
              sales: widget.sales,
              clients: clients,
              locations: locations,
              events: events,
            )
          : _PurchasesDetailList(
              purchases: widget.purchases,
              suppliers: suppliers,
              locations: locations,
              events: events,
            ),
    );
  }
}

// Lista detallada de ventas
class _SalesDetailList extends ConsumerWidget {
  final List<SaleModel> sales;
  final List clients;
  final List locations;
  final List events;

  const _SalesDetailList({
    required this.sales,
    required this.clients,
    required this.locations,
    required this.events,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = sales.fold(0.0, (s, e) => s + e.finalAmount);
    final totalDiscount = sales.fold(0.0, (s, e) => s + e.discount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailSummary(
          rows: [
            _SummaryRow(label: 'Total ventas', value: '${sales.length}'),
            _SummaryRow(
              label: 'Ingresos totales',
              value: 'Bs. ${total.toStringAsFixed(2)}',
              valueColor: AppColors.primary,
            ),
            _SummaryRow(
              label: 'Descuentos',
              value: 'Bs. ${totalDiscount.toStringAsFixed(2)}',
              valueColor: AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...sales.map((s) {
          final client = clients.where((c) => c.id == s.clientId).firstOrNull;
          final location = locations
              .where((l) => l.id == s.locationId)
              .firstOrNull;
          final event = events.where((e) => e.id == s.eventId).firstOrNull;
          return ReportSaleCard(
            sale: s,
            clientName: client?.name ?? 'Sin nombre',
            locationName: location != null
                ? '${(location as dynamic).city}, ${(location as dynamic).country}'
                : null,
            eventName: event?.name,
          );
        }),
      ],
    );
  }
}

// Lista detallada de compras
class _PurchasesDetailList extends ConsumerWidget {
  final List<PurchaseModel> purchases;
  final List suppliers;
  final List locations;
  final List events;

  const _PurchasesDetailList({
    required this.purchases,
    required this.suppliers,
    required this.locations,
    required this.events,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = purchases.fold(0.0, (s, e) => s + e.totalAmount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailSummary(
          rows: [
            _SummaryRow(label: 'Total compras', value: '${purchases.length}'),
            _SummaryRow(
              label: 'Gasto total',
              value: 'Bs. ${total.toStringAsFixed(2)}',
              valueColor: AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...purchases.map((p) {
          final supplier = suppliers
              .where((s) => s.id == p.supplierId)
              .firstOrNull;
          final location = locations
              .where((l) => l.id == p.locationId)
              .firstOrNull;
          final event = events.where((e) => e.id == p.eventId).firstOrNull;
          return ReportPurchaseCard(
            purchase: p,
            supplierName: supplier?.name ?? 'Sin nombre',
            locationName: location != null
                ? '${(location as dynamic).city}, ${(location as dynamic).country}'
                : null,
            eventName: event?.name,
          );
        }),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows
            .map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
