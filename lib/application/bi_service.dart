import '../config/rounding.dart';
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
import '../config/app_clock.dart';

class BiService {
  List<BiEntry> _ranked(Iterable<BiEntry> entries) {
    final list = entries.toList();
    list.sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);
      return byAmount != 0 ? byAmount : a.label.compareTo(b.label);
    });
    return list;
  }

  BiSummary summarize({
    required SalesSummary sales,
    required PurchasesSummary purchases,
  }) {
    return BiSummary(
      ingresos: sales.totalAmount,
      gastos: purchases.totalAmount,
    );
  }

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
          amount: round2(amounts[id]!),
          quantity: quantities[id]!,
          refId: id,
        ),
    ]);
  }

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
          amount: round2(amounts[name]!),
          quantity: quantities[name]!,
        ),
    ]);
  }

  List<BiEntry> purchasesByMaterial({
    required List<PurchaseModel> purchases,
    required Map<int, List<PurchaseItemModel>> itemsByPurchase,
    required List<MaterialModel> materials,
    required List<UnitModel> units,
  }) {
    final materialById = {for (final m in materials) m.id: m};
    final unitNames = {for (final u in units) u.id: u.name};
    final unitTypes = {for (final u in units) u.id: u.type};
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
          amount: round2(amounts[id]!),
          quantity: roundQuantity(
            quantities[id]!,
            unitType: unitTypes[materialById[id]?.unitId] ?? 'medida',
          ),
          unit: unitNames[materialById[id]?.unitId],
          unitType: unitTypes[materialById[id]?.unitId],
          refId: id,
        ),
    ]);
  }

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
            amount: round2(amounts[type]!),
            quantity: quantities[type]!,
          ),
    ];
  }

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
        BiEntry(
          label: names[id]!,
          amount: round2(amounts[id]!),
          quantity: counts[id]!,
          refId: id,
        ),
    ]);
  }

  BiGranularity granularityFor(int days) {
    if (days <= 31) return BiGranularity.day;
    if (days <= 126) return BiGranularity.week;
    return BiGranularity.month;
  }

  DateTime _bucketStart(DateTime date, BiGranularity granularity) {
    final day = dateOnly(date);
    return switch (granularity) {
      BiGranularity.day => day,
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

  BiTimeSeries timeSeries({
    required List<SaleReportRow> rows,
    required List<PurchaseModel> purchases,
    required ReportFilters filters,
  }) {
    final dates = [
      for (final r in rows) dateOnly(r.sale.date),
      for (final p in purchases) dateOnly(p.date),
    ];
    if (dates.isEmpty) {
      return const BiTimeSeries(granularity: BiGranularity.day, buckets: []);
    }

    final today = dateOnly(appNow());
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
    final ventas = <DateTime, int>{};
    final bruto = <DateTime, double>{};
    final descuentos = <DateTime, double>{};
    for (final r in rows) {
      final key = _bucketStart(r.sale.date, granularity);
      ingresos[key] = (ingresos[key] ?? 0) + r.netAmount;
      ventas[key] = (ventas[key] ?? 0) + 1;
      bruto[key] = (bruto[key] ?? 0) + r.subtotalAmount;
      descuentos[key] = (descuentos[key] ?? 0) + r.discountAmount;
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
          ingresos: round2(ingresos[cursor] ?? 0),
          gastos: round2(gastos[cursor] ?? 0),
          ventas: ventas[cursor] ?? 0,
          bruto: round2(bruto[cursor] ?? 0),
          descuentos: round2(descuentos[cursor] ?? 0),
        ),
      );
      cursor = _nextBucket(cursor, granularity);
    }
    return BiTimeSeries(granularity: granularity, buckets: buckets);
  }

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
          revenue: round2(stat.revenue),
          cost: round2(unitCost * stat.units),
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

  BiCoPurchaseReport coPurchases({
    required List<SaleReportRow> rows,
    required Map<int, List<SaleItemModel>> saleItemsMap,
    required List<ProductModel> products,
  }) {
    final names = {for (final p in products) p.id: p.name};
    final counts = <(int, int), int>{};
    final fallbackNames = <int, String>{};
    var multiProduct = 0;
    for (final row in rows) {
      final items = saleItemsMap[row.sale.id] ?? const <SaleItemModel>[];
      for (final item in items) {
        fallbackNames[item.productId] = item.productName;
      }
      final ids = {for (final item in items) item.productId}.toList()..sort();
      if (ids.length < 2) continue;
      multiProduct++;
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final key = (ids[i], ids[j]);
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }

    String nameOf(int id) => names[id] ?? fallbackNames[id] ?? 'Producto';
    final pairs = <BiPairEntry>[];
    counts.forEach((key, sales) {
      if (sales < coPurchaseMinSales) return;
      final a = nameOf(key.$1);
      final b = nameOf(key.$2);
      final aFirst = a.compareTo(b) <= 0;
      pairs.add(
        BiPairEntry(
          productA: aFirst ? a : b,
          productB: aFirst ? b : a,
          sales: sales,
          pct: sales / rows.length * 100,
        ),
      );
    });
    pairs.sort((x, y) {
      final bySales = y.sales.compareTo(x.sales);
      return bySales != 0 ? bySales : x.label.compareTo(y.label);
    });
    return BiCoPurchaseReport(
      pairs: pairs,
      totalSales: rows.length,
      multiProductSales: multiProduct,
    );
  }

  List<BiWeekdayEntry> salesByWeekday({required List<SaleReportRow> rows}) {
    final ingresos = List<double>.filled(7, 0);
    final ventas = List<int>.filled(7, 0);
    for (final row in rows) {
      final i = row.sale.date.weekday - DateTime.monday;
      ingresos[i] += row.netAmount;
      ventas[i]++;
    }
    return [
      for (var i = 0; i < 7; i++)
        BiWeekdayEntry(
          weekday: DateTime.monday + i,
          ingresos: round2(ingresos[i]),
          ventas: ventas[i],
        ),
    ];
  }

  BiTicketReport ticket({required List<SaleReportRow> rows}) {
    return BiTicketReport(
      salesCount: rows.length,
      total: round2(rows.fold(0.0, (sum, r) => sum + r.netAmount)),
    );
  }

  BiDiscountReport discountImpact({required List<SaleReportRow> rows}) {
    return BiDiscountReport(
      totalDiscount: round2(rows.fold(0.0, (sum, r) => sum + r.discountAmount)),
      grossSales: round2(rows.fold(0.0, (sum, r) => sum + r.subtotalAmount)),
      salesCount: rows.length,
      discountedSales: rows.where((r) => r.discountAmount > 0).length,
    );
  }

  List<BiEventProfitEntry> eventProfitability({
    required List<SaleReportRow> rows,
    required List<PurchaseModel> purchases,
    required List<EventModel> events,
  }) {
    final names = {for (final e in events) e.id: e.name};
    final income = <int, double>{};
    final expenses = <int, double>{};
    final salesCount = <int, int>{};
    final purchaseCount = <int, int>{};
    final fallbackNames = <int, String>{};
    for (final row in rows) {
      final id = row.sale.eventId;
      if (id == null) continue;
      income[id] = (income[id] ?? 0) + row.netAmount;
      salesCount[id] = (salesCount[id] ?? 0) + 1;
      fallbackNames[id] = row.eventName ?? 'Evento';
    }
    for (final p in purchases) {
      final id = p.eventId;
      if (id == null) continue;
      expenses[id] = (expenses[id] ?? 0) + p.totalAmount;
      purchaseCount[id] = (purchaseCount[id] ?? 0) + 1;
    }
    final entries = [
      for (final id in {...income.keys, ...expenses.keys})
        BiEventProfitEntry(
          name: names[id] ?? fallbackNames[id] ?? 'Evento',
          income: round2(income[id] ?? 0),
          expenses: round2(expenses[id] ?? 0),
          salesCount: salesCount[id] ?? 0,
          purchaseCount: purchaseCount[id] ?? 0,
        ),
    ];
    entries.sort((a, b) {
      final byProfit = b.profit.compareTo(a.profit);
      return byProfit != 0 ? byProfit : a.name.compareTo(b.name);
    });
    return entries;
  }

  BiReturnReport costReturn({
    required List<SaleReportRow> rows,
    required List<ProductModel> products,
  }) {
    final byId = {for (final p in products) p.id: p};
    final entries = <BiReturnEntry>[];
    var withoutCost = 0;
    _productStats(rows).forEach((id, stat) {
      final product = byId[id];
      final unitCost = product?.productionCost;
      if (unitCost == null || unitCost <= 0) {
        withoutCost++;
        return;
      }
      entries.add(
        BiReturnEntry(
          name: product?.name ?? stat.name,
          revenue: round2(stat.revenue),
          cost: round2(unitCost * stat.units),
          units: stat.units,
        ),
      );
    });
    entries.sort((a, b) {
      final byRatio = b.ratio.compareTo(a.ratio);
      if (byRatio != 0) return byRatio;
      final byProfit = b.profit.compareTo(a.profit);
      return byProfit != 0 ? byProfit : a.name.compareTo(b.name);
    });
    return BiReturnReport(entries: entries, withoutCost: withoutCost);
  }

  ({DateTime first, DateTime last})? resolveRange({
    required Iterable<DateTime> recordDates,
    required ReportFilters filters,
    DateTime? now,
  }) {
    final dates = recordDates.map(dateOnly).toList();
    if (dates.isEmpty) return null;
    final today = dateOnly(now ?? appNow());
    var first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    if (filters.startDate != null) first = dateOnly(filters.startDate!);
    var last = today;
    final requestedEnd = filters.effectiveEndDate;
    if (requestedEnd != null && dateOnly(requestedEnd).isBefore(today)) {
      last = dateOnly(requestedEnd);
    }
    return (first: first, last: last);
  }

  BiProjection projectSales({
    required BiTimeSeries series,
    required ReportFilters filters,
  }) {
    final today = dateOnly(appNow());
    if (series.isEmpty) {
      return const BiProjection.unavailable('No hay ventas en el período.');
    }
    final end = filters.effectiveEndDate;
    if (end != null && dateOnly(end).isBefore(today)) {
      return const BiProjection.unavailable(
        'El período termina antes de hoy; la proyección necesita un período '
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
    final completeCount = buckets
        .where((b) => !_nextBucket(b.start, g).isAfter(today))
        .length;
    final used = completeCount < window ? completeCount : window;
    if (used < 3) {
      return const BiProjection.unavailable(
        'Se necesitan al menos 3 intervalos completos para estimar una '
        'tendencia. Amplía el período.',
      );
    }
    final firstIndex = completeCount - used;

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
    double at(num x) =>
        round2((intercept + slope * x).clamp(0, double.infinity).toDouble());

    final fitted = [
      for (var i = 0; i < used; i++)
        BiTrendPoint(start: buckets[firstIndex + i].start, value: at(i)),
    ];

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
      slope: round2(slope),
    );
  }

  BiEventComparison compareEventDays({
    required List<SaleReportRow> rows,
    required List<EventModel> events,
    required ReportFilters filters,
  }) {
    final range = resolveRange(
      recordDates: [for (final r in rows) r.sale.date],
      filters: filters,
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
      eventRevenue: round2(eventRevenue),
      regularRevenue: round2(regularRevenue),
      eventSales: eventSales,
      regularSales: regularSales,
    );
  }

  BiMaterialCost materialCost({
    required List<PurchaseModel> purchases,
    required double revenue,
  }) {
    return BiMaterialCost(
      materialSpend: round2(
        purchases
            .where((p) => p.isMaterial)
            .fold(0.0, (sum, p) => sum + p.totalAmount),
      ),
      revenue: revenue,
    );
  }

  List<NoMovementEntry> noMovement({
    required List<ProductModel> products,
    required List<SaleModel> sales,
    required Map<int, List<SaleItemModel>> saleItemsMap,
    required int windowDays,
  }) {
    final today = dateOnly(appNow());
    final cutoff = DateTime(today.year, today.month, today.day - (windowDays - 1));

    final lastSale = <int, DateTime>{};
    for (final sale in sales) {
      if (sale.isCanceled || isFutureDated(sale.date)) continue;
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
      final da = a.daysSinceLastSale ?? 1 << 30;
      final db = b.daysSinceLastSale ?? 1 << 30;
      final byDays = db.compareTo(da);
      return byDays != 0 ? byDays : a.product.name.compareTo(b.product.name);
    });
    return entries;
  }

  ({DateTime start, DateTime end}) previousEqualLengthPeriod(
    DateTime start,
    DateTime end,
  ) {
    final s = dateOnly(start);
    final e = dateOnly(end);
    final days = e.difference(s).inDays + 1;
    final prevEnd = DateTime(s.year, s.month, s.day - 1);
    return (
      start: DateTime(prevEnd.year, prevEnd.month, prevEnd.day - (days - 1)),
      end: prevEnd,
    );
  }

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
      final revenue = round2(stat?.revenue ?? 0);
      final units = stat?.units ?? 0;
      final unitCost = product.productionCost;
      final marginPct = unitCost == null || revenue <= 0
          ? (unitCost == null ? null : 0.0)
          : round2((revenue - round2(unitCost * units)) / revenue * 100);
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

  List<BiDrillBucket> _drillBuckets(
    BiTimeSeries series,
    Map<DateTime, double> amounts,
    Map<DateTime, double> quantities,
    Map<DateTime, int> counts, {
    String unitType = 'medida',
  }) {
    return [
      for (final b in series.buckets)
        BiDrillBucket(
          start: b.start,
          amount: round2(amounts[b.start] ?? 0),
          quantity: roundQuantity(quantities[b.start] ?? 0, unitType: unitType),
          count: counts[b.start] ?? 0,
        ),
    ];
  }

  BiProductDetail productDetail({
    required List<SaleReportRow> rows,
    required List<ProductModel> products,
    required int productId,
    required BiTimeSeries series,
  }) {
    final g = series.granularity;
    final amounts = <DateTime, double>{};
    final quantities = <DateTime, double>{};
    final counts = <DateTime, int>{};
    var revenue = 0.0;
    var units = 0.0;
    var salesCount = 0;
    String? fallbackName;
    for (final row in rows) {
      var inSale = false;
      for (final line in row.lines ?? const <SaleLineReport>[]) {
        if (line.item.productId != productId) continue;
        final key = _bucketStart(row.sale.date, g);
        amounts[key] = (amounts[key] ?? 0) + line.netAmount;
        quantities[key] = (quantities[key] ?? 0) + line.item.quantity;
        revenue += line.netAmount;
        units += line.item.quantity;
        fallbackName = line.item.productName;
        if (!inSale) {
          inSale = true;
          salesCount++;
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
    final name = {for (final p in products) p.id: p.name}[productId];
    return BiProductDetail(
      name: name ?? fallbackName ?? 'Producto',
      granularity: g,
      buckets: _drillBuckets(series, amounts, quantities, counts),
      revenue: round2(revenue),
      units: units,
      salesCount: salesCount,
    );
  }

  BiCategoryDetail categoryDetail({
    required List<SaleReportRow> rows,
    required List<ProductModel> products,
    required String categoryName,
  }) {
    final names = {for (final p in products) p.id: p.name};
    final amounts = <int, double>{};
    final quantities = <int, double>{};
    final fallbackNames = <int, String>{};
    for (final row in rows) {
      for (final line in row.lines ?? const <SaleLineReport>[]) {
        if (line.categoryName != categoryName) continue;
        final id = line.item.productId;
        amounts[id] = (amounts[id] ?? 0) + line.netAmount;
        quantities[id] = (quantities[id] ?? 0) + line.item.quantity;
        fallbackNames[id] = line.item.productName;
      }
    }
    final ranked = _ranked([
      for (final id in amounts.keys)
        BiEntry(
          label: names[id] ?? fallbackNames[id] ?? 'Producto',
          amount: round2(amounts[id]!),
          quantity: quantities[id]!,
          refId: id,
        ),
    ]);
    return BiCategoryDetail(
      name: categoryName,
      revenue: round2(ranked.fold(0.0, (s, e) => s + e.amount)),
      units: ranked.fold(0.0, (s, e) => s + e.quantity),
      products: ranked,
    );
  }

  BiEventDetail eventDetail({
    required List<SaleReportRow> rows,
    required List<PurchaseModel> purchases,
    required Map<int, List<PurchaseItemModel>> itemsByPurchase,
    required List<EventModel> events,
    required int eventId,
  }) {
    final sales = [
      for (final row in rows)
        if (row.sale.eventId == eventId) row,
    ]..sort((a, b) => a.sale.date.compareTo(b.sale.date));
    final linked = [
      for (final p in purchases)
        if (p.eventId == eventId) p,
    ]..sort((a, b) => a.date.compareTo(b.date));

    String describe(PurchaseModel p) {
      if (!p.isMaterial) {
        final text = p.description?.trim();
        return text == null || text.isEmpty ? 'Gasto general' : text;
      }
      final names = {
        for (final item in itemsByPurchase[p.id] ?? const <PurchaseItemModel>[])
          item.materialName,
      };
      return names.isEmpty ? 'Compra de materiales' : names.join(', ');
    }

    final name = {for (final e in events) e.id: e.name}[eventId];
    return BiEventDetail(
      name: name ?? (sales.isEmpty ? null : sales.first.eventName) ?? 'Evento',
      sales: [
        for (final row in sales)
          BiEventSaleLine(
            date: row.sale.date,
            clientName: row.clientName,
            amount: row.netAmount,
          ),
      ],
      expenses: [
        for (final p in linked)
          BiEventExpenseLine(
            date: p.date,
            description: describe(p),
            isMaterial: p.isMaterial,
            amount: p.totalAmount,
          ),
      ],
    );
  }

  BiMaterialDetail materialDetail({
    required List<PurchaseModel> purchases,
    required Map<int, List<PurchaseItemModel>> itemsByPurchase,
    required List<MaterialModel> materials,
    required List<UnitModel> units,
    required int materialId,
    required BiTimeSeries series,
  }) {
    final g = series.granularity;
    final amounts = <DateTime, double>{};
    final quantities = <DateTime, double>{};
    final counts = <DateTime, int>{};
    var spend = 0.0;
    var quantity = 0.0;
    var purchaseCount = 0;
    String? fallbackName;
    for (final purchase in purchases) {
      if (!purchase.isMaterial) continue;
      var inPurchase = false;
      for (final item in itemsByPurchase[purchase.id] ?? const []) {
        if (item.materialId != materialId) continue;
        final key = _bucketStart(purchase.date, g);
        amounts[key] = (amounts[key] ?? 0) + item.subtotal;
        quantities[key] = (quantities[key] ?? 0) + item.quantity;
        spend += item.subtotal;
        quantity += item.quantity;
        fallbackName = item.materialName;
        if (!inPurchase) {
          inPurchase = true;
          purchaseCount++;
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
    final material = {for (final m in materials) m.id: m}[materialId];
    final unitName = {for (final u in units) u.id: u.name}[material?.unitId];
    final unitType =
        {for (final u in units) u.id: u.type}[material?.unitId] ?? 'medida';
    return BiMaterialDetail(
      name: material?.name ?? fallbackName ?? 'Material',
      unit: unitName,
      unitType: unitType,
      granularity: g,
      buckets: _drillBuckets(
        series,
        amounts,
        quantities,
        counts,
        unitType: unitType,
      ),
      spend: round2(spend),
      quantity: roundQuantity(quantity, unitType: unitType),
      purchaseCount: purchaseCount,
    );
  }
}

class _ProductStat {
  final String name;
  double revenue = 0;
  int units = 0;

  _ProductStat(this.name);
}
