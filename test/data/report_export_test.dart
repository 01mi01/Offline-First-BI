import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/config/date_formatters.dart';
import 'package:offline_first_bi/data/repositories/report_export_repository.dart';
import 'package:offline_first_bi/models/purchase_item_model.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/models/report_models.dart';
import 'package:offline_first_bi/models/sale_item_model.dart';
import 'package:offline_first_bi/models/sale_model.dart';
import '../support/pdf_text.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

// Verifica que ReportExportRepository (PDF y Excel, ventas y compras) genere
// archivos reales y que su contenido refleje los datos YA FILTRADOS que se le
// pasan (no el dataset completo) -- nunca un dispositivo físico. share_plus y
// path_provider son plugins con canal de plataforma; aquí se sustituyen sus
// PlatformInterface por fakes en proceso (patrón estándar de Flutter:
// extender, no implementar, para satisfacer PlatformInterface.verifyToken),
// de modo que todo corre dentro de `flutter test` en la VM del host y escribe
// archivos reales en un directorio temporal real de esta máquina.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

class _FakeSharePlatform extends SharePlatform {
  final List<List<XFile>> shareCalls = [];

  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    shareCalls.add(files);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

// excel decodifica un número entero (p. ej. 200.0) como IntCellValue aunque
// se haya escrito con xl.DoubleCellValue, así que la comparación numérica se
// hace por valor, no por el subtipo exacto de CellValue.
num _cellNum(xl.CellValue? value) => switch (value) {
      xl.IntCellValue v => v.value,
      xl.DoubleCellValue v => v.value,
      _ => throw StateError('Not a numeric cell: $value'),
    };

void main() {
  // rootBundle (fuente de los PDF) necesita el binding de pruebas.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakeSharePlatform fakeShare;
  late ReportExportRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('report_export_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    fakeShare = _FakeSharePlatform();
    SharePlatform.instance = fakeShare;
    repository = ReportExportRepository();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  SaleModel buildSale(int id, DateTime date, double finalAmount, double discount) =>
      SaleModel(
        id: id,
        totalAmount: finalAmount + discount,
        discount: discount,
        finalAmount: finalAmount,
        date: date,
        notes: 'nota-$id',
        createdAt: date,
      );

  PurchaseModel buildPurchase(int id, DateTime date, double totalAmount) =>
      PurchaseModel(
        id: id,
        isMaterial: true,
        description: 'Descripción $id',
        totalAmount: totalAmount,
        date: date,
        notes: 'nota-$id',
        createdAt: date,
      );

  final fullSaleRows = [
    SaleReportRow(
      sale: buildSale(1, DateTime(2024, 1, 1), 200, 0),
      clientName: 'John Smith (incluida)',
      locationName: 'La Paz - Calacoto, Bolivia',
      eventName: 'Feria del Libro Cochabamba',
    ),
    SaleReportRow(
      sale: buildSale(2, DateTime(2024, 2, 10), 999, 0),
      clientName: 'Emily Johnson (excluido del filtro)',
      locationName: 'Santa Cruz - Equipetrol, Bolivia',
      eventName: 'Exposición de Arte',
    ),
    SaleReportRow(
      sale: buildSale(3, DateTime(2024, 1, 15), 40, 5),
      clientName: 'Ana Martínez (excluida del filtro)',
      locationName: null,
      eventName: null,
    ),
  ];
  // Simula lo que la página de reportes realmente pasa al exportar: solo la
  // fila que sobrevivió al filtro (ver report_detail_page.dart -- exporta
  // siempre widget.sales/widget.purchases ya filtrados por el caller).
  final filteredSaleRows = [fullSaleRows.first];

  final fullPurchaseRows = [
    PurchaseReportRow(
      purchase: buildPurchase(1, DateTime(2024, 1, 1), 100),
      supplierName: 'Riverside Supply Co. (incluido)',
      locationName: 'La Paz - Calacoto, Bolivia',
      eventName: 'Feria del Libro Cochabamba',
    ),
    PurchaseReportRow(
      purchase: buildPurchase(2, DateTime(2024, 2, 10), 500),
      supplierName: 'Harbor Textiles (excluido del filtro)',
      locationName: 'Santa Cruz - Equipetrol, Bolivia',
      eventName: 'Exposición de Arte',
    ),
  ];
  final filteredPurchaseRows = [fullPurchaseRows.first];

  group('exportSalesExcel', () {
    test('writes a real file and shares it', () async {
      await repository.exportSalesExcel(title: 'Reporte ventas', rows: filteredSaleRows);

      expect(fakeShare.shareCalls, hasLength(1));
      final sharedFile = fakeShare.shareCalls.single.single;
      expect(File(sharedFile.path).existsSync(), isTrue);
      expect(File(sharedFile.path).lengthSync(), greaterThan(0));
    });

    test('content reflects the filtered rows, not the full dataset', () async {
      await repository.exportSalesExcel(title: 'Reporte ventas filtrado', rows: filteredSaleRows);
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();

      final excel = xl.Excel.decodeBytes(bytes);
      final sheet = excel.tables['Reporte']!;
      final rows = sheet.rows;

      expect(rows.first.map((c) => c!.value), [
        xl.TextCellValue('Fecha'),
        xl.TextCellValue('Cliente'),
        xl.TextCellValue('Ubicación'),
        xl.TextCellValue('Evento'),
        xl.TextCellValue('Subtotal'),
        xl.TextCellValue('Descuento'),
        xl.TextCellValue('Total'),
        xl.TextCellValue('Notas'),
      ]);

      // Solo debe haber 1 fila de datos (la filtrada), no las 3 del dataset completo.
      expect(rows.length, 2);
      final dataRow = rows[1];
      expect(dataRow[1]!.value, xl.TextCellValue('John Smith (incluida)'));
      expect(_cellNum(dataRow[6]!.value), 200);

      // Los clientes excluidos por el filtro no deben aparecer en ninguna celda.
      final allText = rows
          .expand((r) => r)
          .whereType<xl.Data>()
          .map((d) => d.value.toString())
          .join(' | ');
      expect(allText, isNot(contains('excluido del filtro')));
    });

    test('an empty (filter matches nothing) row list does not crash and writes a header-only file', () async {
      await repository.exportSalesExcel(title: 'Reporte vacío', rows: const []);
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();

      final excel = xl.Excel.decodeBytes(bytes);
      final rows = excel.tables['Reporte']!.rows;
      expect(rows, hasLength(1)); // solo el encabezado
    });
  });

  group('exportSalesExcel with per-line filtering', () {
    // Venta mixta de 120 (descuento 12) filtrada a "Sin categoría": solo la
    // línea Pines grandes (20, con 2 de descuento) debe salir en el reporte.
    SaleReportRow mixedSaleFilteredToPinesGrandes() => SaleReportRow(
      sale: buildSale(1, DateTime(2024, 1, 10), 108, 12),
      clientName: 'John Smith',
      lines: [
        SaleLineReport(
          item: SaleItemModel(
            id: 2,
            saleId: 1,
            productId: 2,
            productName: 'Pines grandes',
            quantity: 2,
            unitPrice: 10,
            priceType: 'B',
            subtotal: 20,
          ),
          categoryId: 1,
          categoryName: 'Sin categoría',
          discountShare: 2,
        ),
      ],
    );

    test('the sale row carries the filtered line amounts, not the whole sale', () async {
      await repository.exportSalesExcel(
        title: 'Reporte mixto',
        rows: [mixedSaleFilteredToPinesGrandes()],
      );
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();
      final sheet = xl.Excel.decodeBytes(bytes).tables['Reporte']!;

      final data = sheet.rows[1];
      expect(_cellNum(data[4]!.value), 20); // subtotal de la línea
      expect(_cellNum(data[5]!.value), 2); // descuento prorrateado
      expect(_cellNum(data[6]!.value), 18); // neto (no 108)
    });

    test('a "Detalle" sheet lists one row per included line with its category', () async {
      await repository.exportSalesExcel(
        title: 'Reporte mixto',
        rows: [mixedSaleFilteredToPinesGrandes()],
      );
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();
      final detail = xl.Excel.decodeBytes(bytes).tables['Detalle']!;

      expect(detail.rows, hasLength(2)); // encabezado + 1 línea
      final row = detail.rows[1];
      expect(row[2]!.value, xl.TextCellValue('Pines grandes'));
      expect(row[3]!.value, xl.TextCellValue('Sin categoría'));
      expect(row[4]!.value, xl.TextCellValue('B'));
      expect(_cellNum(row[6]!.value), 10); // precio unitario
      expect(_cellNum(row[7]!.value), 20); // subtotal bruto de la línea
      // Estuches (la otra línea de la venta) no debe aparecer.
      final text = detail.rows.expand((r) => r).whereType<xl.Data>().join(' ');
      expect(text, isNot(contains('Estuches')));
    });

    test('rows without lines (whole sales) produce no "Detalle" sheet', () async {
      await repository.exportSalesExcel(title: 'Reporte ventas', rows: filteredSaleRows);
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();
      expect(xl.Excel.decodeBytes(bytes).tables.containsKey('Detalle'), isFalse);
    });

    test('the PDF export of filtered rows is written and non-empty', () async {
      final row = mixedSaleFilteredToPinesGrandes();
      await repository.exportSalesPdf(
        title: 'Reporte mixto',
        rows: [row],
        summary: const SalesSummary(count: 1, totalAmount: 18, totalDiscount: 2),
      );
      final file = File(fakeShare.shareCalls.single.single.path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });
  });

  group('PDF text keeps Spanish accents (extracted from the generated file)', () {
    Future<PdfText> lastPdfText() async {
      final bytes = await File(fakeShare.shareCalls.last.single.path).readAsBytes();
      return PdfText.extract(bytes);
    }

    SaleReportRow accentedSaleRow() => SaleReportRow(
      sale: buildSale(1, DateTime(2024, 1, 10), 108, 12),
      clientName: 'Ana Martínez',
      locationName: 'Santa Cruz - Urubó, Bolivia',
      eventName: 'Exposición de Arte',
      lines: [
        SaleLineReport(
          item: SaleItemModel(
            id: 1,
            saleId: 1,
            productId: 1,
            productName: 'Estuches',
            quantity: 2,
            unitPrice: 50,
            priceType: 'A',
            subtotal: 100,
          ),
          categoryId: 1,
          categoryName: 'Sin categoría',
          discountShare: 10,
        ),
      ],
    );

    test('sales PDF: headers, names and category with accents/ñ come out intact', () async {
      await repository.exportSalesPdf(
        title: 'Reporte de Ventas',
        rows: [accentedSaleRow()],
        summary: const SalesSummary(count: 1, totalAmount: 90, totalDiscount: 10),
      );
      final pdf = await lastPdfText();
      final text = pdf.text;

      // Encabezados de columna
      expect(text, contains('Ubicación'));
      expect(text, contains('Categoría'));
      // Datos con tilde y ñ
      expect(text, contains('Ana'));
      expect(text, contains('Martínez'));
      expect(text, contains('Urubó'));
      expect(text, contains('Exposición'));
      expect(text, contains('Arte'));
      expect(text, contains('categoría'));
      // Nada roto: ni caracteres de reemplazo ni la forma sin tilde.
      expect(text, isNot(contains('\uFFFD')));
      expect(text, isNot(contains('Ubicacion')));
      expect(text, isNot(contains('Pena ')));
    });

    test('the PDF embeds Roboto and no longer relies on Helvetica', () async {
      await repository.exportSalesPdf(
        title: 'Reporte de Ventas',
        rows: [accentedSaleRow()],
        summary: const SalesSummary(count: 1, totalAmount: 90, totalDiscount: 10),
      );
      final pdf = await lastPdfText();

      expect(pdf.fontNames.any((n) => n.contains('Roboto')), isTrue);
      expect(pdf.fontNames.any((n) => n.contains('Helvetica')), isFalse);
    });

    test('purchases PDF: supplier, description and column names with accents', () async {
      await repository.exportPurchasesPdf(
        title: 'Reporte de Compras',
        rows: [
          PurchaseReportRow(
            purchase: PurchaseModel(
              id: 1,
              isMaterial: false,
              description: 'Pasaje de avión',
              totalAmount: 30,
              date: DateTime(2024, 1, 5),
              createdAt: DateTime(2024, 1, 5),
            ),
            supplierName: 'Northgate Trading',
          ),
        ],
        summary: const PurchasesSummary(count: 1, totalAmount: 30, materialCount: 0),
      );
      final text = (await lastPdfText()).text;

      expect(text, contains('Descripción'));
      expect(text, contains('Northgate'));
      expect(text, contains('Pasaje'));
      expect(text, contains('avión'));
      expect(text, isNot(contains('\uFFFD')));
    });

    test('the extractor really detects garbling (control: an unsupported char is not returned as typed)', () {
      // Sin ToUnicode para la fuente, cualquier glifo cae en U+FFFD.
      final pdf = PdfText.extract(
        Uint8List.fromList(
          '%PDF-1.5\n1 0 obj\n<<>>\nstream\nBT /F1 10 Tf [<0001>]TJ ET\nendstream\nendobj\n'
              .codeUnits,
        ),
      );
      expect(pdf.text, '\uFFFD');
    });
  });

  // Venta multi-producto con descuento: Tote bag negra 3 x 8 (B) = 24 y Set de pines pequeños
  // 1 x 16 (A) = 16 -> subtotal 40, descuento 4, total 36. discountShare se
  // pasa prorrateado (2.4 / 1.6) tal como lo entrega ReportService; los
  // exports no deben mostrarlo por línea.
  group('sales exports: line totals and sale-level discount', () {
    SaleReportRow multiProductSale() => SaleReportRow(
      sale: buildSale(1, DateTime(2024, 3, 5), 36, 4),
      clientName: 'John Smith',
      lines: [
        SaleLineReport(
          item: SaleItemModel(
            id: 1,
            saleId: 1,
            productId: 1,
            productName: 'Tote bag negra',
            quantity: 3,
            unitPrice: 8,
            priceType: 'B',
            subtotal: 24,
          ),
          categoryId: 1,
          categoryName: 'Pines',
          discountShare: 2.4,
        ),
        SaleLineReport(
          item: SaleItemModel(
            id: 2,
            saleId: 1,
            productId: 2,
            productName: 'Set de pines pequeños',
            quantity: 1,
            unitPrice: 16,
            priceType: 'A',
            subtotal: 16,
          ),
          categoryId: 1,
          categoryName: 'Pines',
          discountShare: 1.6,
        ),
      ],
    );

    const summary = SalesSummary(count: 1, totalAmount: 36, totalDiscount: 4);

    // package:pdf escribe cada palabra como una operación de texto aparte
    // ('Bs.' y '24.00' son dos runs), así que los montos y textos de varias
    // palabras se comprueban sobre el texto unido; las palabras sueltas,
    // sobre los runs.
    Future<PdfText> salesPdf() async {
      await repository.exportSalesPdf(
        title: 'Reporte de Ventas',
        rows: [multiProductSale()],
        summary: summary,
      );
      return PdfText.extract(
        await File(fakeShare.shareCalls.last.single.path).readAsBytes(),
      );
    }

    test('PDF: each product line shows its own gross total, not the discounted sale total', () async {
      final text = (await salesPdf()).text;

      expect(text, contains('Bs. 24.00')); // Tote bag negra: 3 x 8
      expect(text, contains('Bs. 16.00')); // Set de pines pequeños: 1 x 16
      // Ni el total de la venta con descuento (36) ni el neto prorrateado por
      // línea (21.60 / 14.40) deben aparecer como total de una línea.
      expect(text, isNot(contains('Bs. 21.60')));
      expect(text, isNot(contains('Bs. 14.40')));
      expect(text, isNot(contains('Bs. 23.00')));
    });

    test('PDF: the "Precio" column shows the unit price amount, not the price-type letter', () async {
      final pdf = await salesPdf();

      expect(pdf.text, contains('Bs. 8.00'));
      expect(pdf.text, contains('Bs. 16.00'));
      // La letra del tipo de precio sigue visible, pero en su propia columna.
      expect(pdf.runs, contains('Tipo'));
      expect(pdf.runs, contains('B'));
      expect(pdf.runs, contains('A'));
    });

    test('PDF: the sale-level discount is shown (summary and sale table)', () async {
      final pdf = await salesPdf();

      expect(pdf.text, contains('Descuentos: Bs. 4.00')); // resumen
      expect(pdf.runs, contains('Descuento')); // columna de la tabla
      expect(pdf.runs, contains('Subtotal'));
      expect(pdf.text, contains('Bs. 40.00')); // subtotal de la venta
      expect(pdf.text, contains('Bs. 36.00')); // total de la venta
      // El descuento de la venta figura en el resumen y en su fila, y en
      // ningún otro lado (ninguna línea de producto lo repite).
      expect('Bs. 4.00'.allMatches(pdf.text), hasLength(2));
    });

    test('Excel "Reporte": the discount appears once, at sale level', () async {
      await repository.exportSalesExcel(title: 'Multi', rows: [multiProductSale()]);
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();
      final sheet = xl.Excel.decodeBytes(bytes).tables['Reporte']!;

      expect(sheet.rows, hasLength(2)); // encabezado + 1 venta
      final data = sheet.rows[1];
      expect(_cellNum(data[4]!.value), 40); // subtotal
      expect(_cellNum(data[5]!.value), 4); // descuento
      expect(_cellNum(data[6]!.value), 36); // total
    });

    test('Excel "Detalle": keeps one row per line but carries no per-line discount', () async {
      await repository.exportSalesExcel(title: 'Multi', rows: [multiProductSale()]);
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();
      final detail = xl.Excel.decodeBytes(bytes).tables['Detalle']!;

      expect(detail.rows.first.map((c) => c!.value), [
        xl.TextCellValue('Fecha'),
        xl.TextCellValue('Cliente'),
        xl.TextCellValue('Producto'),
        xl.TextCellValue('Categoría'),
        xl.TextCellValue('Tipo de precio'),
        xl.TextCellValue('Cantidad'),
        xl.TextCellValue('Precio unitario'),
        xl.TextCellValue('Subtotal'),
      ]);
      expect(detail.rows, hasLength(3)); // encabezado + 2 líneas

      final toteNegra = detail.rows[1];
      expect(toteNegra[2]!.value, xl.TextCellValue('Tote bag negra'));
      expect(_cellNum(toteNegra[5]!.value), 3);
      expect(_cellNum(toteNegra[6]!.value), 8);
      expect(_cellNum(toteNegra[7]!.value), 24);

      final setPines = detail.rows[2];
      expect(setPines[2]!.value, xl.TextCellValue('Set de pines pequeños'));
      expect(_cellNum(setPines[7]!.value), 16);

      // Sumar las líneas da el subtotal de la venta; el descuento (4) solo
      // existe en la hoja "Reporte", así que no se cuenta dos veces.
      final lineSum = _cellNum(toteNegra[7]!.value) + _cellNum(setPines[7]!.value);
      expect(lineSum, 40);
    });
  });

  group('purchases exports: material line items', () {
    PurchaseReportRow materialPurchase() => PurchaseReportRow(
      purchase: PurchaseModel(
        id: 1,
        isMaterial: true,
        totalAmount: 12,
        date: DateTime(2024, 3, 5),
        createdAt: DateTime(2024, 3, 5),
      ),
      supplierName: 'Riverside Supply Co.',
      items: [
        PurchaseItemModel(
          id: 1,
          purchaseId: 1,
          materialId: 1,
          materialName: 'Tela beige',
          quantity: 2,
          unitPrice: 3.5,
          subtotal: 7,
        ),
        PurchaseItemModel(
          id: 2,
          purchaseId: 1,
          materialId: 2,
          materialName: 'Resina parte A',
          quantity: 2.5,
          unitPrice: 2,
          subtotal: 5,
        ),
      ],
    );

    // Un gasto general no tiene ítems: solo aporta su fila de resumen.
    PurchaseReportRow generalExpense() => PurchaseReportRow(
      purchase: PurchaseModel(
        id: 2,
        isMaterial: false,
        description: 'Participación en feria',
        totalAmount: 50,
        date: DateTime(2024, 3, 6),
        createdAt: DateTime(2024, 3, 6),
      ),
      supplierName: 'Sin proveedor',
    );

    const summary = PurchasesSummary(count: 2, totalAmount: 62, materialCount: 1);

    test('PDF: lists material, quantity, unit price and subtotal for each line', () async {
      await repository.exportPurchasesPdf(
        title: 'Reporte de Compras',
        rows: [materialPurchase(), generalExpense()],
        summary: summary,
      );
      final pdf = PdfText.extract(
        await File(fakeShare.shareCalls.single.single.path).readAsBytes(),
      );

      expect(pdf.text, contains('Detalle de materiales'));
      for (final header in ['Material', 'Cant.', 'Precio', 'unit.', 'Subtotal']) {
        expect(pdf.runs, contains(header));
      }
      expect(pdf.text, contains('Tela beige'));
      expect(pdf.runs, contains('2')); // cantidad entera sin decimales
      expect(pdf.text, contains('Bs. 3.50'));
      expect(pdf.text, contains('Bs. 7.00'));
      expect(pdf.text, contains('Resina parte A'));
      expect(pdf.runs, contains('2.5'));
      expect(pdf.text, contains('Bs. 2.00'));
      expect(pdf.text, contains('Bs. 5.00'));
    });

    test('PDF: without any material lines there is no detail section', () async {
      await repository.exportPurchasesPdf(
        title: 'Solo gastos',
        rows: [generalExpense()],
        summary: const PurchasesSummary(count: 1, totalAmount: 50, materialCount: 0),
      );
      final text = PdfText.extract(
        await File(fakeShare.shareCalls.single.single.path).readAsBytes(),
      ).text;

      expect(text, isNot(contains('Detalle de materiales')));
    });

    test('Excel: a "Detalle" sheet has one row per material line', () async {
      await repository.exportPurchasesExcel(
        title: 'Compras',
        rows: [materialPurchase(), generalExpense()],
      );
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();
      final excel = xl.Excel.decodeBytes(bytes);

      // La hoja de resumen se mantiene igual (una fila por compra).
      expect(excel.tables['Reporte']!.rows, hasLength(3));

      final detail = excel.tables['Detalle']!;
      expect(detail.rows.first.map((c) => c!.value), [
        xl.TextCellValue('Fecha'),
        xl.TextCellValue('Proveedor'),
        xl.TextCellValue('Material'),
        xl.TextCellValue('Cantidad'),
        xl.TextCellValue('Precio unitario'),
        xl.TextCellValue('Subtotal'),
      ]);
      expect(detail.rows, hasLength(3)); // encabezado + 2 líneas (el gasto no aporta)

      final telaBeige = detail.rows[1];
      expect(telaBeige[1]!.value, xl.TextCellValue('Riverside Supply Co.'));
      expect(telaBeige[2]!.value, xl.TextCellValue('Tela beige'));
      expect(_cellNum(telaBeige[3]!.value), 2);
      expect(_cellNum(telaBeige[4]!.value), 3.5);
      expect(_cellNum(telaBeige[5]!.value), 7);

      final resinaA = detail.rows[2];
      expect(resinaA[2]!.value, xl.TextCellValue('Resina parte A'));
      expect(_cellNum(resinaA[3]!.value), 2.5);
      expect(_cellNum(resinaA[4]!.value), 2);
      expect(_cellNum(resinaA[5]!.value), 5);
    });

    test('Excel: without any material lines there is no "Detalle" sheet', () async {
      await repository.exportPurchasesExcel(title: 'Solo gastos', rows: [generalExpense()]);
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();
      expect(xl.Excel.decodeBytes(bytes).tables.containsKey('Detalle'), isFalse);
    });
  });

  group('export file names are readable and date-based', () {
    String lastSharedName() => File(fakeShare.shareCalls.last.single.path).uri.pathSegments.last;
    final today = formatDateForFileName(DateTime.now());

    test('sales PDF: Reporte_de_Ventas_<yyyy-MM-dd>.pdf (no epoch timestamp)', () async {
      await repository.exportSalesPdf(
        title: 'Reporte de Ventas',
        rows: filteredSaleRows,
        summary: const SalesSummary(count: 1, totalAmount: 200, totalDiscount: 0),
      );
      expect(lastSharedName(), 'Reporte_de_Ventas_$today.pdf');
    });

    test('sales Excel: Reporte_de_Ventas_<yyyy-MM-dd>.xlsx', () async {
      await repository.exportSalesExcel(title: 'Reporte de Ventas', rows: filteredSaleRows);
      expect(lastSharedName(), 'Reporte_de_Ventas_$today.xlsx');
    });

    test('purchases PDF and Excel follow the same pattern', () async {
      await repository.exportPurchasesPdf(
        title: 'Reporte de Compras',
        rows: filteredPurchaseRows,
        summary: const PurchasesSummary(count: 1, totalAmount: 100, materialCount: 1),
      );
      expect(lastSharedName(), 'Reporte_de_Compras_$today.pdf');

      await repository.exportPurchasesExcel(title: 'Reporte de Compras', rows: filteredPurchaseRows);
      expect(lastSharedName(), 'Reporte_de_Compras_$today.xlsx');
    });

    test('the name has no long run of digits (a millisecond timestamp)', () async {
      await repository.exportSalesPdf(
        title: 'Reporte de Ventas',
        rows: filteredSaleRows,
        summary: const SalesSummary(count: 1, totalAmount: 200, totalDiscount: 0),
      );
      expect(RegExp(r'\d{10,}').hasMatch(lastSharedName()), isFalse);
    });
  });

  group('dates inside the exports use the app-wide dd/MM/yyyy format', () {
    test('PDF: sale dates, purchase dates and the generation stamp', () async {
      await repository.exportSalesPdf(
        title: 'Reporte de Ventas',
        rows: filteredSaleRows, // venta del 01/01/2024
        summary: const SalesSummary(count: 1, totalAmount: 200, totalDiscount: 0),
      );
      var text = PdfText.extract(
        await File(fakeShare.shareCalls.last.single.path).readAsBytes(),
      ).text;
      expect(text, contains('01/01/2024'));
      expect(text, contains('Generado el ${formatDate(DateTime.now())}'));

      await repository.exportPurchasesPdf(
        title: 'Reporte de Compras',
        rows: filteredPurchaseRows,
        summary: const PurchasesSummary(count: 1, totalAmount: 100, materialCount: 1),
      );
      text = PdfText.extract(
        await File(fakeShare.shareCalls.last.single.path).readAsBytes(),
      ).text;
      expect(text, contains('01/01/2024'));
    });

    test('Excel: the date column is dd/MM/yyyy', () async {
      await repository.exportSalesExcel(title: 'Reporte de Ventas', rows: filteredSaleRows);
      final bytes = await File(fakeShare.shareCalls.last.single.path).readAsBytes();
      final sheet = xl.Excel.decodeBytes(bytes).tables['Reporte']!;
      expect(sheet.rows[1][0]!.value, xl.TextCellValue('01/01/2024'));
    });
  });

  group('exportPurchasesExcel', () {
    test('content reflects the filtered rows, not the full dataset', () async {
      await repository.exportPurchasesExcel(
        title: 'Reporte compras filtrado',
        rows: filteredPurchaseRows,
      );
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();

      final excel = xl.Excel.decodeBytes(bytes);
      final rows = excel.tables['Reporte']!.rows;

      expect(rows.length, 2);
      expect(rows[1][1]!.value, xl.TextCellValue('Riverside Supply Co. (incluido)'));
      expect(_cellNum(rows[1][6]!.value), 100);

      final allText = rows
          .expand((r) => r)
          .whereType<xl.Data>()
          .map((d) => d.value.toString())
          .join(' | ');
      expect(allText, isNot(contains('excluido del filtro')));
    });

    test('an empty (filter matches nothing) row list does not crash', () async {
      await repository.exportPurchasesExcel(title: 'Reporte compras vacío', rows: const []);
      final bytes = await File(fakeShare.shareCalls.single.single.path).readAsBytes();
      final rows = xl.Excel.decodeBytes(bytes).tables['Reporte']!.rows;
      expect(rows, hasLength(1));
    });
  });

  group('exportSalesPdf / exportPurchasesPdf', () {
    // package:pdf produce bytes comprimidos/binarios: no hay una forma
    // confiable de leer el texto de vuelta sin una dependencia adicional de
    // extracción de PDF (no presente en este proyecto). Se verifica en su
    // lugar: (1) que el archivo se genera y no está vacío, (2) que no revienta
    // con una lista vacía (filtro sin resultados), y (3) que el tamaño del
    // archivo cambia según la cantidad de filas que realmente se le pasan --
    // evidencia indirecta pero real de que el contenido depende de los datos
    // filtrados y no de un dataset fijo.
    test('exportSalesPdf writes a non-empty file for filtered rows', () async {
      await repository.exportSalesPdf(
        title: 'Reporte ventas PDF',
        rows: filteredSaleRows,
        summary: const SalesSummary(count: 1, totalAmount: 200, totalDiscount: 0),
      );
      final file = File(fakeShare.shareCalls.single.single.path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });

    test('exportSalesPdf with an empty (filter matches nothing) row list does not crash', () async {
      await repository.exportSalesPdf(
        title: 'Reporte ventas PDF vacío',
        rows: const [],
        summary: const SalesSummary(count: 0, totalAmount: 0, totalDiscount: 0),
      );
      final file = File(fakeShare.shareCalls.single.single.path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });

    test('PDF file size grows with the number of filtered rows (proxy for "content reflects filtered data")', () async {
      await repository.exportSalesPdf(
        title: 'Reporte una fila',
        rows: filteredSaleRows,
        summary: const SalesSummary(count: 1, totalAmount: 200, totalDiscount: 0),
      );
      final oneRowSize = File(fakeShare.shareCalls.single.single.path).lengthSync();

      fakeShare.shareCalls.clear();
      await repository.exportSalesPdf(
        title: 'Reporte tres filas',
        rows: fullSaleRows,
        summary: const SalesSummary(count: 3, totalAmount: 1239, totalDiscount: 5),
      );
      final threeRowsSize = File(fakeShare.shareCalls.single.single.path).lengthSync();

      expect(threeRowsSize, greaterThan(oneRowSize));
    });

    test('exportPurchasesPdf writes a non-empty file for filtered rows', () async {
      await repository.exportPurchasesPdf(
        title: 'Reporte compras PDF',
        rows: filteredPurchaseRows,
        summary: const PurchasesSummary(count: 1, totalAmount: 100, materialCount: 1),
      );
      final file = File(fakeShare.shareCalls.single.single.path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });

    test('exportPurchasesPdf with an empty (filter matches nothing) row list does not crash', () async {
      await repository.exportPurchasesPdf(
        title: 'Reporte compras PDF vacío',
        rows: const [],
        summary: const PurchasesSummary(count: 0, totalAmount: 0, materialCount: 0),
      );
      final file = File(fakeShare.shareCalls.single.single.path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });
  });
}
