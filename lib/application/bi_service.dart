import '../models/bi_config.dart';
import '../models/bi_models.dart';
import '../models/category_model.dart';
import '../models/default_records.dart';
import '../models/event_model.dart';
import '../models/material_model.dart';
import '../models/product_model.dart';
import '../models/purchase_item_model.dart';
import '../models/purchase_model.dart';
import '../models/report_filters.dart';
import '../models/report_models.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';
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

  // ---------------------------------------------------------------------
  // Indicadores avanzados
  // ---------------------------------------------------------------------

  // Ingresos netos y unidades de cada producto vendido en las ventas dadas.
  Map<int, _ProductStat> _productStats(List<SaleReportRow> rows) {
    final stats = <int, _ProductStat>{};
    for (final row in rows) {
      for (final line in row.lines ?? const <SaleLineReport>[]) {
        final stat = stats.putIfAbsent(
          line.item.productId,
          () => _ProductStat(line.item.productName),
        );
        stat.revenue += line.netAmount;
        stat.units += line.item.quantity;
      }
    }
    return stats;
  }

  // Margen de ganancia por producto: ingresos netos menos el costo de
  // producción de las unidades vendidas. Los productos sin costo de producción
  // registrado no entran al ranking (solo se cuentan).
  BiMarginReport productMargins({
    required List<SaleReportRow> rows,
    required List<ProductModel> products,
  }) {
    final byId = {for (final p in products) p.id: p};
    final entries = <BiMarginEntry>[];
    var withoutCost = 0;
    _productStats(rows).forEach((id, stat) {
      final product = byId[id];
      final unitCost = product?.productionCost;
      if (unitCost == null) {
        withoutCost++;
        return;
      }
      entries.add(
        BiMarginEntry(
          name: product?.name ?? stat.name,
          revenue: stat.revenue,
          cost: unitCost * stat.units,
          units: stat.units,
        ),
      );
    });
    entries.sort((a, b) {
      final byMargin = b.marginPct.compareTo(a.marginPct);
      if (byMargin != 0) return byMargin;
      final byProfit = b.profit.compareTo(a.profit);
      return byProfit != 0 ? byProfit : a.name.compareTo(b.name);
    });
    return BiMarginReport(entries: entries, withoutCost: withoutCost);
  }

  // Primer y último día del periodo: de "Desde" (o del primer registro, si no
  // hay) hasta "Hasta" u hoy, lo que sea anterior. Null sin registros.
  ({DateTime first, DateTime last})? resolveRange({
    required Iterable<DateTime> recordDates,
    required ReportFilters filters,
    DateTime? now,
  }) {
    final dates = recordDates.map(dateOnly).toList();
    if (dates.isEmpty) return null;
    final today = dateOnly(now ?? DateTime.now());
    var first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    if (filters.startDate != null) first = dateOnly(filters.startDate!);
    var last = today;
    final requestedEnd = filters.effectiveEndDate;
    if (requestedEnd != null && dateOnly(requestedEnd).isBefore(today)) {
      last = dateOnly(requestedEnd);
    }
    return (first: first, last: last);
  }

  // Proyección lineal simple de los ingresos. Ajusta una recta (mínimos
  // cuadrados) a los últimos intervalos COMPLETOS (un intervalo en curso no
  // cuenta: está a medias) y la prolonga unos intervalos hacia adelante, sin
  // bajar de 0. Solo se calcula si el periodo llega hasta hoy y hay al menos 3
  // intervalos completos.
  BiProjection projectSales({
    required BiTimeSeries series,
    required ReportFilters filters,
    DateTime? now,
  }) {
    final today = dateOnly(now ?? DateTime.now());
    if (series.isEmpty) {
      return const BiProjection.unavailable('No hay ventas en el periodo.');
    }
    final end = filters.effectiveEndDate;
    if (end != null && dateOnly(end).isBefore(today)) {
      return const BiProjection.unavailable(
        'El periodo termina antes de hoy; la proyección necesita un periodo '
        'que llegue hasta hoy.',
      );
    }

    final g = series.granularity;
    final window = switch (g) {
      BiGranularity.day => 14,
      BiGranularity.week => 8,
      BiGranularity.month => 6,
    };
    final horizon = switch (g) {
      BiGranularity.day => 7,
      BiGranularity.week => 4,
      BiGranularity.month => 3,
    };

    final buckets = series.buckets;
    // Completo = todo el intervalo es anterior a hoy.
    final completeCount = buckets
        .where((b) => !_nextBucket(b.start, g).isAfter(today))
        .length;
    final used = completeCount < window ? completeCount : window;
    if (used < 3) {
      return const BiProjection.unavailable(
        'Se necesitan al menos 3 intervalos completos para estimar una '
        'tendencia. Amplía el periodo.',
      );
    }
    final firstIndex = completeCount - used;

    // Mínimos cuadrados sobre x = 0..used-1.
    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0;
    for (var i = 0; i < used; i++) {
      final y = buckets[firstIndex + i].ingresos;
      sumX += i;
      sumY += y;
      sumXY += i * y;
      sumXX += i * i;
    }
    final n = used.toDouble();
    final denominator = n * sumXX - sumX * sumX;
    final slope = denominator == 0 ? 0.0 : (n * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / n;
    double at(num x) => (intercept + slope * x).clamp(0, double.infinity);

    final fitted = [
      for (var i = 0; i < used; i++)
        BiTrendPoint(start: buckets[firstIndex + i].start, value: at(i)),
    ];

    // Los intervalos futuros empiezan después del intervalo de hoy.
    final currentBucket = _bucketStart(today, g);
    final todayX = buckets.indexWhere((b) => b.start == currentBucket) - firstIndex;
    final baseX = todayX >= 0 ? todayX : used - 1;
    final projected = <BiTrendPoint>[];
    var start = _nextBucket(currentBucket, g);
    for (var k = 1; k <= horizon; k++) {
      projected.add(BiTrendPoint(start: start, value: at(baseX + k)));
      start = _nextBucket(start, g);
    }
    return BiProjection(
      granularity: g,
      fitted: fitted,
      projected: projected,
      slope: slope,
    );
  }

  // Días de evento frente a días regulares dentro del periodo. Un día es "de
  // evento" si cae entre el inicio y el fin de algún evento (sin fin, solo el
  // día de inicio); cada venta se clasifica por SU fecha, esté o no vinculada
  // al evento.
  BiEventComparison compareEventDays({
    required List<SaleReportRow> rows,
    required List<EventModel> events,
    required ReportFilters filters,
    DateTime? now,
  }) {
    final range = resolveRange(
      recordDates: [for (final r in rows) r.sale.date],
      filters: filters,
      now: now,
    );
    if (range == null || range.last.isBefore(range.first)) {
      return BiEventComparison.empty;
    }

    final eventDays = <DateTime>{};
    for (final e in events) {
      var day = dateOnly(e.startDate);
      final endDay = dateOnly(e.endDate ?? e.startDate);
      if (day.isBefore(range.first)) day = range.first;
      final stop = endDay.isAfter(range.last) ? range.last : endDay;
      while (!day.isAfter(stop)) {
        eventDays.add(day);
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }

    final totalDays = range.last.difference(range.first).inDays + 1;
    var eventRevenue = 0.0, regularRevenue = 0.0;
    var eventSales = 0, regularSales = 0;
    for (final r in rows) {
      if (eventDays.contains(dateOnly(r.sale.date))) {
        eventRevenue += r.netAmount;
        eventSales++;
      } else {
        regularRevenue += r.netAmount;
        regularSales++;
      }
    }
    return BiEventComparison(
      eventDays: eventDays.length,
      regularDays: totalDays - eventDays.length,
      eventRevenue: eventRevenue,
      regularRevenue: regularRevenue,
      eventSales: eventSales,
      regularSales: regularSales,
    );
  }

  // Gasto en compras de materiales frente a los ingresos del periodo.
  BiMaterialCost materialCost({
    required List<PurchaseModel> purchases,
    required double revenue,
  }) {
    return BiMaterialCost(
      materialSpend: purchases
          .where((p) => p.isMaterial)
          .fold(0.0, (sum, p) => sum + p.totalAmount),
      revenue: revenue,
    );
  }

  // Productos activos sin ninguna venta en los últimos [windowDays] días
  // (contando hoy). Mide recencia: usa TODAS las ventas válidas (no canceladas
  // ni con fecha futura), sin filtros ni periodo. Primero los que más tiempo
  // llevan sin venderse (y los que nunca se vendieron).
  List<NoMovementEntry> noMovement({
    required List<ProductModel> products,
    required List<SaleModel> sales,
    required Map<int, List<SaleItemModel>> saleItemsMap,
    required int windowDays,
    DateTime? now,
  }) {
    final today = dateOnly(now ?? DateTime.now());
    final cutoff = DateTime(today.year, today.month, today.day - (windowDays - 1));

    final lastSale = <int, DateTime>{};
    for (final sale in sales) {
      if (sale.isCanceled || isFutureDated(sale.date, now: now)) continue;
      final day = dateOnly(sale.date);
      for (final item in saleItemsMap[sale.id] ?? const <SaleItemModel>[]) {
        final previous = lastSale[item.productId];
        if (previous == null || day.isAfter(previous)) {
          lastSale[item.productId] = day;
        }
      }
    }

    final entries = <NoMovementEntry>[];
    for (final p in products) {
      if (!p.isActive) continue;
      final last = lastSale[p.id];
      if (last != null && !last.isBefore(cutoff)) continue;
      entries.add(
        NoMovementEntry(
          product: p,
          lastSale: last,
          daysSinceLastSale: last == null ? null : today.difference(last).inDays,
        ),
      );
    }
    entries.sort((a, b) {
      // Los que nunca se vendieron, primero.
      final da = a.daysSinceLastSale ?? 1 << 30;
      final db = b.daysSinceLastSale ?? 1 << 30;
      final byDays = db.compareTo(da);
      return byDays != 0 ? byDays : a.product.name.compareTo(b.product.name);
    });
    return entries;
  }

  // Periodo inmediatamente anterior y equivalente a [start]–[end]:
  //  - de un mes (desde el día 1): el mismo tramo del mes anterior (si [end] es
  //    el último día del mes, todo el mes anterior);
  //  - de una semana (desde el lunes, 2 a 7 días): la semana anterior;
  //  - de un año (desde el 1 de enero): el mismo tramo del año anterior;
  //  - cualquier otro: los mismos días justo antes de [start].
  // Siempre con el mismo número de días transcurridos, para comparar lo
  // comparable.
  ({DateTime start, DateTime end}) previousPeriod(DateTime start, DateTime end) {
    final s = dateOnly(start);
    final e = dateOnly(end);
    final days = e.difference(s).inDays + 1;

    int lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

    if (s.day == 1 && e.year == s.year && e.month == s.month) {
      final prevStart = DateTime(s.year, s.month - 1, 1);
      final prevLast = lastDayOfMonth(prevStart.year, prevStart.month);
      final isWholeMonth = e.day == lastDayOfMonth(e.year, e.month);
      final endDay = isWholeMonth ? prevLast : (e.day < prevLast ? e.day : prevLast);
      return (
        start: prevStart,
        end: DateTime(prevStart.year, prevStart.month, endDay),
      );
    }
    if (s.month == 1 && s.day == 1 && e.year == s.year && days > 31) {
      final endMonth = e.month;
      final prevLast = lastDayOfMonth(s.year - 1, endMonth);
      final isWholeYear = e.month == 12 && e.day == 31;
      final endDay = isWholeYear ? 31 : (e.day < prevLast ? e.day : prevLast);
      return (
        start: DateTime(s.year - 1, 1, 1),
        end: DateTime(s.year - 1, endMonth, endDay),
      );
    }
    if (s.weekday == DateTime.monday && days >= 2 && days <= 7) {
      return (
        start: DateTime(s.year, s.month, s.day - 7),
        end: DateTime(e.year, e.month, e.day - 7),
      );
    }
    final prevEnd = DateTime(s.year, s.month, s.day - 1);
    return (
      start: DateTime(prevEnd.year, prevEnd.month, prevEnd.day - (days - 1)),
      end: prevEnd,
    );
  }

  // Radar de productos: ingresos, margen, unidades y rotación, normalizados de
  // 0 a 1. Ingresos y unidades se miden contra el producto que más vendió en el
  // periodo; el margen es el % de ganancia (0 sin costo de producción); la
  // rotación es unidades vendidas ÷ (vendidas + stock actual). Si [selectedIds]
  // no trae al menos 2 productos válidos, se toman los 3 de más ingresos.
  BiRadar radar({
    required List<SaleReportRow> rows,
    required List<ProductModel> products,
    required List<int> selectedIds,
  }) {
    final stats = _productStats(rows);
    final byId = {for (final p in products) p.id: p};
    final maxRevenue = stats.values.fold(0.0, (m, s) => s.revenue > m ? s.revenue : m);
    final maxUnits = stats.values.fold(0, (m, s) => s.units > m ? s.units : m);

    var ids = [
      for (final id in selectedIds)
        if (byId.containsKey(id)) id,
    ].take(radarMaxProducts).toList();
    var auto = false;
    if (ids.length < radarMinProducts) {
      auto = true;
      final ranked = stats.entries.where((e) => byId.containsKey(e.key)).toList()
        ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
      ids = ranked.take(3).map((e) => e.key).toList();
    }

    final result = <BiRadarProduct>[];
    for (final id in ids) {
      final product = byId[id]!;
      final stat = stats[id];
      final revenue = stat?.revenue ?? 0;
      final units = stat?.units ?? 0;
      final unitCost = product.productionCost;
      final marginPct = unitCost == null || revenue <= 0
          ? (unitCost == null ? null : 0.0)
          : (revenue - unitCost * units) / revenue * 100;
      final available = units + product.stock;
      result.add(
        BiRadarProduct(
          id: id,
          name: product.name,
          revenue: revenue,
          units: units,
          stock: product.stock,
          marginPct: marginPct,
          revenueNorm: maxRevenue > 0 ? revenue / maxRevenue : 0,
          marginNorm: marginPct == null ? 0 : (marginPct.clamp(0, 100) / 100),
          unitsNorm: maxUnits > 0 ? units / maxUnits : 0,
          rotationNorm: available > 0 ? units / available : 0,
        ),
      );
    }
    return BiRadar(products: result, autoSelected: auto);
  }
}

class _ProductStat {
  final String name;
  double revenue = 0;
  int units = 0;

  _ProductStat(this.name);
}
