import '../models/bi_models.dart';
import '../models/category_model.dart';
import '../models/default_records.dart';
import '../models/material_model.dart';
import '../models/product_model.dart';
import '../models/purchase_item_model.dart';
import '../models/purchase_model.dart';
import '../models/report_filters.dart';
import '../models/report_models.dart';
import '../models/unit_model.dart';
import 'date_range_filter.dart';

// Agregación de los indicadores de Business Intelligence.
//
// Trabaja SOLO con datos ya filtrados por ReportService (fechas propias de
// cada registro, sin ventas canceladas ni registros con fecha futura, filtros
// de producto/categoría/tipo de precio/evento/ubicación): así todos los
// indicadores suman exactamente lo mismo que Reportes.
class BiService {
  // Un ranking sale ordenado de mayor a menor monto (y por nombre si empatan).
  List<BiEntry> _ranked(Iterable<BiEntry> entries) {
    final list = entries.toList();
    list.sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);
      return byAmount != 0 ? byAmount : a.label.compareTo(b.label);
    });
    return list;
  }

  // Ingresos y gastos del periodo filtrado.
  BiSummary summarize({
    required SalesSummary sales,
    required PurchasesSummary purchases,
  }) {
    return BiSummary(
      ingresos: sales.totalAmount,
      gastos: purchases.totalAmount,
    );
  }

  // Ventas por producto: ingresos netos (con la parte del descuento de cada
  // línea) y unidades vendidas.
  List<BiEntry> salesByProduct({
    required List<SaleReportRow> rows,
    required List<ProductModel> products,
  }) {
    final names = {for (final p in products) p.id: p.name};
    final amounts = <int, double>{};
    final quantities = <int, double>{};
    final fallbackNames = <int, String>{};
    for (final row in rows) {
      for (final line in row.lines ?? const <SaleLineReport>[]) {
        final id = line.item.productId;
        amounts[id] = (amounts[id] ?? 0) + line.netAmount;
        quantities[id] = (quantities[id] ?? 0) + line.item.quantity;
        fallbackNames[id] = line.item.productName;
      }
    }
    return _ranked([
      for (final id in amounts.keys)
        BiEntry(
          label: names[id] ?? fallbackNames[id] ?? 'Producto',
          amount: amounts[id]!,
          quantity: quantities[id]!,
        ),
    ]);
  }

  // Ventas por categoría. "Sin categoría" cuenta como una categoría más.
  List<BiEntry> salesByCategory({required List<SaleReportRow> rows}) {
    final amounts = <String, double>{};
    final quantities = <String, double>{};
    for (final row in rows) {
      for (final line in row.lines ?? const <SaleLineReport>[]) {
        final name = line.categoryName;
        amounts[name] = (amounts[name] ?? 0) + line.netAmount;
        quantities[name] = (quantities[name] ?? 0) + line.item.quantity;
      }
    }
    return _ranked([
      for (final name in amounts.keys)
        BiEntry(
          label: name,
          amount: amounts[name]!,
          quantity: quantities[name]!,
        ),
    ]);
  }

  // Compras por material: gasto y cantidad comprada de cada material en las
  // compras de materiales del periodo (los gastos generales no tienen ítems).
  List<BiEntry> purchasesByMaterial({
    required List<PurchaseModel> purchases,
    required Map<int, List<PurchaseItemModel>> itemsByPurchase,
    required List<MaterialModel> materials,
    required List<UnitModel> units,
  }) {
    final materialById = {for (final m in materials) m.id: m};
    final unitNames = {for (final u in units) u.id: u.name};
    final amounts = <int, double>{};
    final quantities = <int, double>{};
    final fallbackNames = <int, String>{};
    for (final purchase in purchases) {
      if (!purchase.isMaterial) continue;
      for (final item in itemsByPurchase[purchase.id] ?? const []) {
        amounts[item.materialId] =
            (amounts[item.materialId] ?? 0) + item.subtotal;
        quantities[item.materialId] =
            (quantities[item.materialId] ?? 0) + item.quantity;
        fallbackNames[item.materialId] = item.materialName;
      }
    }
    return _ranked([
      for (final id in amounts.keys)
        BiEntry(
          label: materialById[id]?.name ?? fallbackNames[id] ?? 'Material',
          amount: amounts[id]!,
          quantity: quantities[id]!,
          unit: unitNames[materialById[id]?.unitId],
        ),
    ]);
  }

  // Ventas por tipo de precio: siempre en el orden A, B (para que cada tipo
  // conserve su color), solo con los tipos que tuvieron ventas.
  List<BiEntry> salesByPriceType({required List<SaleReportRow> rows}) {
    final amounts = <String, double>{};
    final quantities = <String, double>{};
    for (final row in rows) {
      for (final line in row.lines ?? const <SaleLineReport>[]) {
        final type = line.item.priceType;
        amounts[type] = (amounts[type] ?? 0) + line.netAmount;
        quantities[type] = (quantities[type] ?? 0) + line.item.quantity;
      }
    }
    return [
      for (final type in const ['A', 'B'])
        if (amounts.containsKey(type))
          BiEntry(
            label: 'Precio $type',
            amount: amounts[type]!,
            quantity: quantities[type]!,
          ),
    ];
  }

  // Ventas por evento: solo eventos con ventas vinculadas en el periodo. Cada
  // venta cuenta por su propia fecha (ya filtrada), nunca por la del evento.
  // [BiEntry.quantity] es el número de ventas.
  List<BiEntry> salesByEvent({required List<SaleReportRow> rows}) {
    final amounts = <int, double>{};
    final counts = <int, double>{};
    final names = <int, String>{};
    for (final row in rows) {
      final eventId = row.sale.eventId;
      if (eventId == null) continue;
      amounts[eventId] = (amounts[eventId] ?? 0) + row.netAmount;
      counts[eventId] = (counts[eventId] ?? 0) + 1;
      names[eventId] = row.eventName ?? 'Evento';
    }
    return _ranked([
      for (final id in amounts.keys)
        BiEntry(label: names[id]!, amount: amounts[id]!, quantity: counts[id]!),
    ]);
  }

  // Granularidad según el tamaño del rango: diaria hasta 31 días, semanal hasta
  // 18 semanas y mensual a partir de ahí.
  BiGranularity granularityFor(int days) {
    if (days <= 31) return BiGranularity.day;
    if (days <= 126) return BiGranularity.week;
    return BiGranularity.month;
  }

  DateTime _bucketStart(DateTime date, BiGranularity granularity) {
    final day = dateOnly(date);
    return switch (granularity) {
      BiGranularity.day => day,
      // Las semanas empiezan en lunes, igual que el atajo "Esta semana".
      BiGranularity.week => DateTime(
        day.year,
        day.month,
        day.day - (day.weekday - DateTime.monday),
      ),
      BiGranularity.month => DateTime(day.year, day.month),
    };
  }

  DateTime _nextBucket(DateTime start, BiGranularity granularity) =>
      switch (granularity) {
        BiGranularity.day => DateTime(start.year, start.month, start.day + 1),
        BiGranularity.week => DateTime(start.year, start.month, start.day + 7),
        BiGranularity.month => DateTime(start.year, start.month + 1),
      };

  // Evolución de ingresos y gastos en el tiempo. El rango va de "Desde" (o del
  // primer registro, si no hay) hasta "Hasta" o hoy, lo que sea anterior; los
  // intervalos sin movimiento aparecen con 0 para que la línea sea continua.
  BiTimeSeries timeSeries({
    required List<SaleReportRow> rows,
    required List<PurchaseModel> purchases,
    required ReportFilters filters,
    DateTime? now,
  }) {
    final dates = [
      for (final r in rows) dateOnly(r.sale.date),
      for (final p in purchases) dateOnly(p.date),
    ];
    if (dates.isEmpty) {
      return const BiTimeSeries(granularity: BiGranularity.day, buckets: []);
    }

    final today = dateOnly(now ?? DateTime.now());
    var first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    if (filters.startDate != null) first = dateOnly(filters.startDate!);
    var last = today;
    final requestedEnd = filters.effectiveEndDate;
    if (requestedEnd != null && dateOnly(requestedEnd).isBefore(today)) {
      last = dateOnly(requestedEnd);
    }

    final days = last.difference(first).inDays + 1;
    final granularity = granularityFor(days < 1 ? 1 : days);

    final ingresos = <DateTime, double>{};
    final gastos = <DateTime, double>{};
    for (final r in rows) {
      final key = _bucketStart(r.sale.date, granularity);
      ingresos[key] = (ingresos[key] ?? 0) + r.netAmount;
    }
    for (final p in purchases) {
      final key = _bucketStart(p.date, granularity);
      gastos[key] = (gastos[key] ?? 0) + p.totalAmount;
    }

    final buckets = <BiTimeBucket>[];
    var cursor = _bucketStart(first, granularity);
    final lastBucket = _bucketStart(last, granularity);
    while (!cursor.isAfter(lastBucket)) {
      buckets.add(
        BiTimeBucket(
          start: cursor,
          ingresos: ingresos[cursor] ?? 0,
          gastos: gastos[cursor] ?? 0,
        ),
      );
      cursor = _nextBucket(cursor, granularity);
    }
    return BiTimeSeries(granularity: granularity, buckets: buckets);
  }

  // Productos activos con stock bajo, del más escaso al menos. Es el estado
  // ACTUAL del inventario: no depende de ningún filtro ni de fechas.
  List<LowStockEntry> lowStock({
    required List<ProductModel> products,
    required List<CategoryModel> categories,
  }) {
    final categoryNames = {for (final c in categories) c.id: c.name};
    final low = products
        .where((p) => p.isActive && p.stock <= lowStockThreshold)
        .toList();
    low.sort((a, b) {
      final byStock = a.stock.compareTo(b.stock);
      return byStock != 0 ? byStock : a.name.compareTo(b.name);
    });
    return [
      for (final p in low)
        LowStockEntry(
          product: p,
          categoryName: categoryNames[p.categoryId] ?? DefaultRecords.category,
        ),
    ];
  }
}
