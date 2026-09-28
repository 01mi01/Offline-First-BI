import 'dart:io';
import 'dart:ui';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/data/repositories/report_export_repository.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/models/report_models.dart';
import 'package:offline_first_bi/models/sale_model.dart';
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
      clientName: 'Ana (incluida)',
      locationName: 'La Paz, Bolivia',
      eventName: 'Feria Enero',
    ),
    SaleReportRow(
      sale: buildSale(2, DateTime(2024, 2, 10), 999, 0),
      clientName: 'Beto (excluido del filtro)',
      locationName: 'Cochabamba, Bolivia',
      eventName: 'Expo',
    ),
    SaleReportRow(
      sale: buildSale(3, DateTime(2024, 1, 15), 40, 5),
      clientName: 'Carla (excluida del filtro)',
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
      supplierName: 'Proveedor Andino (incluido)',
      locationName: 'La Paz, Bolivia',
      eventName: 'Feria Enero',
    ),
    PurchaseReportRow(
      purchase: buildPurchase(2, DateTime(2024, 2, 10), 500),
      supplierName: 'Proveedor Valle (excluido del filtro)',
      locationName: 'Cochabamba, Bolivia',
      eventName: 'Expo',
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
      expect(dataRow[1]!.value, xl.TextCellValue('Ana (incluida)'));
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
      expect(rows[1][1]!.value, xl.TextCellValue('Proveedor Andino (incluido)'));
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
