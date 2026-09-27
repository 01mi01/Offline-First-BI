import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../../models/report_models.dart';

// Genera y comparte reportes de ventas y compras en PDF y Excel
class ReportExportRepository {
  String _fmt(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _fmtShort(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> exportSalesPdf({
    required String title,
    required List<SaleReportRow> rows,
    required SalesSummary summary,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generado el ${_fmt(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          _pdfSummary([
            'Total ventas: ${summary.count}',
            'Ingresos: Bs. ${summary.totalAmount.toStringAsFixed(2)}',
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
              _pdfHeaderRow(['Fecha', 'Cliente', 'Ubicación', 'Evento', 'Total']),
              ...rows.map(
                (r) => _pdfRow([
                  _fmtShort(r.sale.date),
                  r.clientName,
                  r.locationName ?? '-',
                  r.eventName ?? '-',
                  'Bs. ${r.sale.finalAmount.toStringAsFixed(2)}',
                ]),
              ),
            ],
          ),
        ],
      ),
    );

    final file = await _writeTempFile(title, 'pdf', await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: title);
  }

  Future<void> exportPurchasesPdf({
    required String title,
    required List<PurchaseReportRow> rows,
    required PurchasesSummary summary,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generado el ${_fmt(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          _pdfSummary([
            'Total compras: ${summary.count}',
            'Gasto: Bs. ${summary.totalAmount.toStringAsFixed(2)}',
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
              ...rows.map(
                (r) => _pdfRow([
                  _fmtShort(r.purchase.date),
                  r.supplierName,
                  r.purchase.isMaterial ? 'Material' : 'Gasto',
                  r.purchase.description ?? '-',
                  'Bs. ${r.purchase.totalAmount.toStringAsFixed(2)}',
                ]),
              ),
            ],
          ),
        ],
      ),
    );

    final file = await _writeTempFile(title, 'pdf', await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: title);
  }

  Future<void> exportSalesExcel({
    required String title,
    required List<SaleReportRow> rows,
  }) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Reporte'];
    excel.setDefaultSheet('Reporte');
    excel.delete('Sheet1');

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
    for (final r in rows) {
      sheet.appendRow([
        xl.TextCellValue(_fmtShort(r.sale.date)),
        xl.TextCellValue(r.clientName),
        xl.TextCellValue(r.locationName ?? '-'),
        xl.TextCellValue(r.eventName ?? '-'),
        xl.DoubleCellValue(r.sale.totalAmount),
        xl.DoubleCellValue(r.sale.discount),
        xl.DoubleCellValue(r.sale.finalAmount),
        xl.TextCellValue(r.sale.notes ?? ''),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) return;
    final file = await _writeTempFile(title, 'xlsx', bytes);
    await Share.shareXFiles([XFile(file.path)], text: title);
  }

  Future<void> exportPurchasesExcel({
    required String title,
    required List<PurchaseReportRow> rows,
  }) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Reporte'];
    excel.setDefaultSheet('Reporte');
    excel.delete('Sheet1');

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
    for (final r in rows) {
      sheet.appendRow([
        xl.TextCellValue(_fmtShort(r.purchase.date)),
        xl.TextCellValue(r.supplierName),
        xl.TextCellValue(r.purchase.isMaterial ? 'Material' : 'Gasto'),
        xl.TextCellValue(r.purchase.description ?? '-'),
        xl.TextCellValue(r.locationName ?? '-'),
        xl.TextCellValue(r.eventName ?? '-'),
        xl.DoubleCellValue(r.purchase.totalAmount),
        xl.TextCellValue(r.purchase.notes ?? ''),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) return;
    final file = await _writeTempFile(title, 'xlsx', bytes);
    await Share.shareXFiles([XFile(file.path)], text: title);
  }

  Future<File> _writeTempFile(
    String title,
    String extension,
    List<int> bytes,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(bytes);
    return file;
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
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
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
}
