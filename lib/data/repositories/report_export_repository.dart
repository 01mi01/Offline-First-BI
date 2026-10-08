import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../../models/report_models.dart';
import '../../config/date_formatters.dart';
import '../../config/app_clock.dart';
import '../../config/rounding.dart';

// Genera y comparte reportes de ventas y compras en PDF y Excel
class ReportExportRepository {
  String _fmt(DateTime date) => formatDateTime(date);

  String _fmtShort(DateTime date) => formatDate(date);

  // Importes siempre con dos decimales ("Bs. 70.00"), redondeados half up.
  String _bs(double amount) => 'Bs. ${fixed2(amount)}';

  // Cantidad de un material según su unidad: dos decimales en medidas,
  // fracciones exactas en envases y enteros en piezas.
  String _qty(double value, String unitType, String unitName) =>
      formatMaterialQuantity(value, unitType: unitType, unitName: unitName);

  // Celdas numéricas de Excel: el valor guardado va redondeado a dos decimales
  // y la celda se muestra con dos decimales ("70.00"). Las de [plainColumns]
  // (cantidades por fracciones) llevan el formato general.
  void _appendRow(
    xl.Sheet sheet,
    List<xl.CellValue?> cells, {
    Set<int> plainColumns = const {},
  }) {
    sheet.appendRow(cells);
    final row = sheet.maxRows - 1;
    for (var col = 0; col < cells.length; col++) {
      if (cells[col] is! xl.DoubleCellValue) continue;
      // El paquete excel da "0.00" a todo decimal sin estilo; las cantidades
      // por fracciones piden el formato general de forma explícita.
      sheet
              .cell(
                xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
              )
              .cellStyle =
          xl.CellStyle(
            numberFormat: plainColumns.contains(col)
                ? xl.NumFormat.standard_0
                : xl.NumFormat.standard_2,
          );
    }
  }

  // Fuente empaquetada para todo el texto de los PDF. La fuente por defecto
  // del paquete pdf (Helvetica) no soporta Unicode, así que las tildes y la ñ
  // salían rotas; Roboto (los mismos assets de la UI) sí las soporta.
  Future<pw.ThemeData> _pdfTheme() async {
    final regular = await rootBundle.load(
      'assets/fonts/roboto/roboto-regular.ttf',
    );
    final bold = await rootBundle.load('assets/fonts/roboto/roboto-bold.ttf');
    return pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    );
  }

  Future<void> exportSalesPdf({
    required String title,
    required List<SaleReportRow> rows,
    required SalesSummary summary,
  }) async {
    final pdf = pw.Document(theme: await _pdfTheme());

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
            'Generado el ${_fmt(appNow())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          _pdfSummary([
            'Total ventas: ${summary.count}',
            'Descuentos: ${_bs(summary.totalDiscount)}',
            'Ingresos: ${_bs(summary.totalAmount)}',
          ]),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(1.8),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.4),
              4: const pw.FlexColumnWidth(1.1),
              5: const pw.FlexColumnWidth(1.1),
              6: const pw.FlexColumnWidth(1.1),
            },
            children: [
              _pdfHeaderRow([
                'Fecha',
                'Cliente',
                'Ubicación',
                'Evento',
                'Subtotal',
                'Descuento',
                'Total',
              ]),
              ...rows.map(
                (r) => _pdfRow([
                  _fmtShort(r.sale.date),
                  r.clientName,
                  r.locationName ?? '-',
                  r.eventName ?? '-',
                  _bs(r.subtotalAmount),
                  _bs(r.discountAmount),
                  _bs(r.netAmount),
                ]),
              ),
            ],
          ),
          if (rows.any((r) => r.lines != null)) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Detalle por producto',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.4),
                1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(1.4),
                3: const pw.FlexColumnWidth(0.7),
                4: const pw.FlexColumnWidth(1.1),
                5: const pw.FlexColumnWidth(0.7),
                6: const pw.FlexColumnWidth(1.2),
              },
              children: [
                // El descuento es de la venta completa y ya figura en la
                // tabla de arriba; cada línea muestra su importe bruto
                // (precio x cantidad), sin repartirle el descuento.
                _pdfHeaderRow([
                  'Fecha',
                  'Producto',
                  'Categoría',
                  'Tipo',
                  'Precio',
                  'Cant.',
                  'Total',
                ]),
                for (final r in rows)
                  for (final line in r.lines ?? const <SaleLineReport>[])
                    _pdfRow([
                      _fmtShort(r.sale.date),
                      line.item.productName,
                      line.categoryName,
                      line.item.priceType,
                      _bs(line.item.unitPrice),
                      '${line.item.quantity}',
                      _bs(line.subtotal),
                    ]),
              ],
            ),
          ],
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
    final pdf = pw.Document(theme: await _pdfTheme());

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
            'Generado el ${_fmt(appNow())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          _pdfSummary([
            'Total compras: ${summary.count}',
            'Gasto: ${_bs(summary.totalAmount)}',
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
                  _bs(r.purchase.totalAmount),
                ]),
              ),
            ],
          ),
          if (rows.any((r) => r.items.isNotEmpty)) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Detalle de materiales',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.4),
                1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(0.9),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.2),
              },
              children: [
                _pdfHeaderRow([
                  'Fecha',
                  'Proveedor',
                  'Material',
                  'Cant.',
                  'Precio unit.',
                  'Subtotal',
                ]),
                for (final r in rows)
                  for (final item in r.items)
                    _pdfRow([
                      _fmtShort(r.purchase.date),
                      r.supplierName,
                      item.materialName,
                      _qty(item.quantity, item.unitType, item.unitName),
                      _bs(item.unitPrice),
                      _bs(item.subtotal),
                    ]),
              ],
            ),
          ],
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
      _appendRow(sheet, [
        xl.TextCellValue(_fmtShort(r.sale.date)),
        xl.TextCellValue(r.clientName),
        xl.TextCellValue(r.locationName ?? '-'),
        xl.TextCellValue(r.eventName ?? '-'),
        xl.DoubleCellValue(round2(r.subtotalAmount)),
        xl.DoubleCellValue(round2(r.discountAmount)),
        xl.DoubleCellValue(round2(r.netAmount)),
        xl.TextCellValue(r.sale.notes ?? ''),
      ]);
    }

    // Hoja de detalle: una fila por línea de venta incluida en el reporte,
    // para analizar la demanda por producto y categoría. El descuento es de
    // la venta completa y solo figura en la hoja "Reporte" (una vez por
    // venta); aquí cada línea lleva su subtotal bruto, así que sumar la hoja
    // no cuenta el descuento varias veces.
    if (rows.any((r) => r.lines != null)) {
      final detail = excel['Detalle'];
      detail.appendRow([
        xl.TextCellValue('Fecha'),
        xl.TextCellValue('Cliente'),
        xl.TextCellValue('Producto'),
        xl.TextCellValue('Categoría'),
        xl.TextCellValue('Tipo de precio'),
        xl.TextCellValue('Cantidad'),
        xl.TextCellValue('Precio unitario'),
        xl.TextCellValue('Subtotal'),
      ]);
      for (final r in rows) {
        for (final line in r.lines ?? const <SaleLineReport>[]) {
          _appendRow(detail, [
            xl.TextCellValue(_fmtShort(r.sale.date)),
            xl.TextCellValue(r.clientName),
            xl.TextCellValue(line.item.productName),
            xl.TextCellValue(line.categoryName),
            xl.TextCellValue(line.item.priceType),
            xl.IntCellValue(line.item.quantity),
            xl.DoubleCellValue(round2(line.item.unitPrice)),
            xl.DoubleCellValue(round2(line.subtotal)),
          ]);
        }
      }
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
      _appendRow(sheet, [
        xl.TextCellValue(_fmtShort(r.purchase.date)),
        xl.TextCellValue(r.supplierName),
        xl.TextCellValue(r.purchase.isMaterial ? 'Material' : 'Gasto'),
        xl.TextCellValue(r.purchase.description ?? '-'),
        xl.TextCellValue(r.locationName ?? '-'),
        xl.TextCellValue(r.eventName ?? '-'),
        xl.DoubleCellValue(round2(r.purchase.totalAmount)),
        xl.TextCellValue(r.purchase.notes ?? ''),
      ]);
    }

    // Hoja de detalle: una fila por línea de material de cada compra.
    if (rows.any((r) => r.items.isNotEmpty)) {
      final detail = excel['Detalle'];
      detail.appendRow([
        xl.TextCellValue('Fecha'),
        xl.TextCellValue('Proveedor'),
        xl.TextCellValue('Material'),
        xl.TextCellValue('Cantidad'),
        xl.TextCellValue('Precio unitario'),
        xl.TextCellValue('Subtotal'),
      ]);
      for (final r in rows) {
        for (final item in r.items) {
          _appendRow(
            detail,
            [
              xl.TextCellValue(_fmtShort(r.purchase.date)),
              xl.TextCellValue(r.supplierName),
              xl.TextCellValue(item.materialName),
              xl.DoubleCellValue(
                roundQuantity(item.quantity, unitType: item.unitType),
              ),
              xl.DoubleCellValue(round2(item.unitPrice)),
              xl.DoubleCellValue(round2(item.subtotal)),
            ],
            // Cantidades por fracciones (envases): sin forzar dos decimales.
            plainColumns: item.unitType == fractionUnitType ? {3} : const {},
          );
        }
      }
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
      '${dir.path}/${title.replaceAll(' ', '_')}_${formatDateForFileName(appNow())}.$extension',
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
