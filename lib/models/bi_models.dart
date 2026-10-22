import '../config/rounding.dart';
import 'product_model.dart';

class BiSummary {
  final double ingresos;
  final double gastos;

  const BiSummary({required this.ingresos, required this.gastos});

  double get balance => round2(ingresos - gastos);
}

class BiEntry {
  final String label;
  final double amount;
  final double quantity;

  final String? unit;
  final String? unitType;

  final int? refId;

  const BiEntry({
    required this.label,
    required this.amount,
    required this.quantity,
    this.unit,
    this.unitType,
    this.refId,
  });
}

enum BiGranularity {
  day('Diaria'),
  week('Semanal'),
  month('Mensual');

  final String label;
  const BiGranularity(this.label);
}

class BiTimeBucket {
  final DateTime start;
  final double ingresos;
  final double gastos;

  final int ventas;
  final double bruto;
  final double descuentos;

  const BiTimeBucket({
    required this.start,
    required this.ingresos,
    required this.gastos,
    this.ventas = 0,
    this.bruto = 0,
    this.descuentos = 0,
  });

  double? get ticket => ventas > 0 ? round2(ingresos / ventas) : null;

  double? get descuentoPct =>
      bruto > 0 ? round2(descuentos / bruto * 100) : null;
}

class BiTimeSeries {
  final BiGranularity granularity;
  final List<BiTimeBucket> buckets;

  const BiTimeSeries({required this.granularity, required this.buckets});

  bool get isEmpty => buckets.isEmpty;
}

class LowStockEntry {
  final ProductModel product;
  final String categoryName;

  const LowStockEntry({required this.product, required this.categoryName});

  bool get isOutOfStock => product.stock <= 0;
}

class BiMarginEntry {
  final String name;
  final double revenue;
  final double cost;
  final int units;

  const BiMarginEntry({
    required this.name,
    required this.revenue,
    required this.cost,
    required this.units,
  });

  double get profit => round2(revenue - cost);

  double get marginPct => revenue > 0 ? round2(profit / revenue * 100) : 0;
}

class BiMarginReport {
  final List<BiMarginEntry> entries;

  final int withoutCost;

  const BiMarginReport({required this.entries, required this.withoutCost});
}

class BiPairEntry {
  final String productA;
  final String productB;

  final int sales;

  final double pct;

  const BiPairEntry({
    required this.productA,
    required this.productB,
    required this.sales,
    required this.pct,
  });

  String get label => '$productA + $productB';
}

class BiCoPurchaseReport {
  final List<BiPairEntry> pairs;

  final int totalSales;
  final int multiProductSales;

  const BiCoPurchaseReport({
    required this.pairs,
    required this.totalSales,
    required this.multiProductSales,
  });
}

const int coPurchaseMinSales = 3;

class BiWeekdayEntry {
  final int weekday;
  final double ingresos;
  final int ventas;

  const BiWeekdayEntry({
    required this.weekday,
    required this.ingresos,
    required this.ventas,
  });

  static const List<String> names = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const List<String> shortNames = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  String get name => names[weekday - 1];
  String get shortName => shortNames[weekday - 1];
}

class BiTicketReport {
  final int salesCount;
  final double total;

  const BiTicketReport({required this.salesCount, required this.total});

  double? get average => salesCount > 0 ? round2(total / salesCount) : null;
}

class BiDiscountReport {
  final double totalDiscount;
  final double grossSales;
  final int salesCount;
  final int discountedSales;

  const BiDiscountReport({
    required this.totalDiscount,
    required this.grossSales,
    required this.salesCount,
    required this.discountedSales,
  });

  double? get pct =>
      grossSales > 0 ? round2(totalDiscount / grossSales * 100) : null;
}

class BiEventProfitEntry {
  final String name;
  final double income;
  final double expenses;
  final int salesCount;
  final int purchaseCount;

  const BiEventProfitEntry({
    required this.name,
    required this.income,
    required this.expenses,
    required this.salesCount,
    required this.purchaseCount,
  });

  double get profit => round2(income - expenses);
}

class BiReturnEntry {
  final String name;
  final double revenue;
  final double cost;
  final int units;

  const BiReturnEntry({
    required this.name,
    required this.revenue,
    required this.cost,
    required this.units,
  });

  double get profit => round2(revenue - cost);

  double get ratio => round2(profit / cost);
}

class BiReturnReport {
  final List<BiReturnEntry> entries;

  final int withoutCost;

  const BiReturnReport({required this.entries, required this.withoutCost});
}

class BiTrendPoint {
  final DateTime start;
  final double value;

  const BiTrendPoint({required this.start, required this.value});
}

class BiProjection {
  final String? unavailableReason;
  final BiGranularity granularity;

  final List<BiTrendPoint> fitted;

  final List<BiTrendPoint> projected;

  final double slope;

  const BiProjection({
    required this.granularity,
    required this.fitted,
    required this.projected,
    required this.slope,
  }) : unavailableReason = null;

  const BiProjection.unavailable(String reason)
    : unavailableReason = reason,
      granularity = BiGranularity.day,
      fitted = const [],
      projected = const [],
      slope = 0;

  bool get isAvailable => unavailableReason == null;

  double get projectedTotal =>
      round2(projected.fold(0.0, (s, p) => s + p.value));
}

class BiEventComparison {
  final int eventDays;
  final int regularDays;
  final double eventRevenue;
  final double regularRevenue;
  final int eventSales;
  final int regularSales;

  const BiEventComparison({
    required this.eventDays,
    required this.regularDays,
    required this.eventRevenue,
    required this.regularRevenue,
    required this.eventSales,
    required this.regularSales,
  });

  static const empty = BiEventComparison(
    eventDays: 0,
    regularDays: 0,
    eventRevenue: 0,
    regularRevenue: 0,
    eventSales: 0,
    regularSales: 0,
  );

  double? get eventPerDay =>
      eventDays > 0 ? round2(eventRevenue / eventDays) : null;
  double? get regularPerDay =>
      regularDays > 0 ? round2(regularRevenue / regularDays) : null;
  double? get eventPerSale =>
      eventSales > 0 ? round2(eventRevenue / eventSales) : null;
  double? get regularPerSale =>
      regularSales > 0 ? round2(regularRevenue / regularSales) : null;

  double? get perDayDifferencePct {
    if (eventDays <= 0 || regularDays <= 0) return null;
    final e = eventRevenue / eventDays;
    final r = regularRevenue / regularDays;
    if (r == 0) return null;
    return round2((e - r) / r * 100);
  }
}

class BiMaterialCost {
  final double materialSpend;
  final double revenue;

  const BiMaterialCost({required this.materialSpend, required this.revenue});

  double? get ratioPct =>
      revenue > 0 ? round2(materialSpend / revenue * 100) : null;
}

class NoMovementEntry {
  final ProductModel product;
  final DateTime? lastSale;
  final int? daysSinceLastSale;

  const NoMovementEntry({
    required this.product,
    required this.lastSale,
    required this.daysSinceLastSale,
  });
}

class BiPeriodComparison {
  final String? unavailableReason;
  final DateTime? currentStart;
  final DateTime? currentEnd;
  final DateTime? previousStart;
  final DateTime? previousEnd;
  final BiSummary current;
  final BiSummary previous;

  const BiPeriodComparison({
    required DateTime this.currentStart,
    required DateTime this.currentEnd,
    required DateTime this.previousStart,
    required DateTime this.previousEnd,
    required this.current,
    required this.previous,
  }) : unavailableReason = null;

  const BiPeriodComparison.unavailable(String reason)
    : unavailableReason = reason,
      currentStart = null,
      currentEnd = null,
      previousStart = null,
      previousEnd = null,
      current = const BiSummary(ingresos: 0, gastos: 0),
      previous = const BiSummary(ingresos: 0, gastos: 0);

  bool get isAvailable => unavailableReason == null;

  static double? changePct(double current, double previous) {
    if (previous == 0) return null;
    return round2((current - previous) / previous.abs() * 100);
  }
}

class BiRadarProduct {
  final int id;
  final String name;
  final double revenue;
  final int units;
  final int stock;
  final double? marginPct;
  final double revenueNorm;
  final double marginNorm;
  final double unitsNorm;
  final double rotationNorm;

  const BiRadarProduct({
    required this.id,
    required this.name,
    required this.revenue,
    required this.units,
    required this.stock,
    required this.marginPct,
    required this.revenueNorm,
    required this.marginNorm,
    required this.unitsNorm,
    required this.rotationNorm,
  });
}

class BiRadar {
  final List<BiRadarProduct> products;

  final bool autoSelected;

  const BiRadar({required this.products, required this.autoSelected});
}

class BiDrillBucket {
  final DateTime start;
  final double amount;
  final double quantity;
  final int count;

  const BiDrillBucket({
    required this.start,
    required this.amount,
    required this.quantity,
    required this.count,
  });
}

class BiProductDetail {
  final String name;
  final BiGranularity granularity;
  final List<BiDrillBucket> buckets;
  final double revenue;
  final double units;
  final int salesCount;

  const BiProductDetail({
    required this.name,
    required this.granularity,
    required this.buckets,
    required this.revenue,
    required this.units,
    required this.salesCount,
  });

  bool get isEmpty => salesCount == 0;
}

class BiCategoryDetail {
  final String name;
  final double revenue;
  final double units;
  final List<BiEntry> products;

  const BiCategoryDetail({
    required this.name,
    required this.revenue,
    required this.units,
    required this.products,
  });

  bool get isEmpty => products.isEmpty;
}

class BiEventSaleLine {
  final DateTime date;
  final String clientName;
  final double amount;

  const BiEventSaleLine({
    required this.date,
    required this.clientName,
    required this.amount,
  });
}

class BiEventExpenseLine {
  final DateTime date;
  final String description;
  final bool isMaterial;
  final double amount;

  const BiEventExpenseLine({
    required this.date,
    required this.description,
    required this.isMaterial,
    required this.amount,
  });
}

class BiEventDetail {
  final String name;
  final List<BiEventSaleLine> sales;
  final List<BiEventExpenseLine> expenses;

  const BiEventDetail({
    required this.name,
    required this.sales,
    required this.expenses,
  });

  double get income => round2(sales.fold(0.0, (s, l) => s + l.amount));
  double get totalExpenses =>
      round2(expenses.fold(0.0, (s, l) => s + l.amount));
  double get materialExpenses => round2(
    expenses.where((e) => e.isMaterial).fold(0.0, (s, l) => s + l.amount),
  );
  double get generalExpenses => round2(totalExpenses - materialExpenses);
  double get profit => round2(income - totalExpenses);

  bool get isEmpty => sales.isEmpty && expenses.isEmpty;
}

class BiMaterialDetail {
  final String name;
  final String? unit;
  final String unitType;
  final BiGranularity granularity;
  final List<BiDrillBucket> buckets;
  final double spend;
  final double quantity;
  final int purchaseCount;

  const BiMaterialDetail({
    required this.name,
    required this.unit,
    this.unitType = 'medida',
    required this.granularity,
    required this.buckets,
    required this.spend,
    required this.quantity,
    required this.purchaseCount,
  });

  bool get isEmpty => purchaseCount == 0;
}

class BiReport {
  final BiSummary summary;
  final List<BiEntry> salesByProduct;
  final List<BiEntry> salesByCategory;
  final List<BiEntry> purchasesByMaterial;
  final List<BiEntry> salesByPriceType;
  final BiTimeSeries timeSeries;
  final List<BiEntry> salesByEvent;
  final List<LowStockEntry> lowStock;
  final BiMarginReport productMargins;
  final BiProjection projection;
  final BiEventComparison eventComparison;
  final BiMaterialCost materialCost;
  final List<NoMovementEntry> noMovement;
  final BiPeriodComparison periodComparison;
  final BiRadar radar;
  final BiCoPurchaseReport coPurchases;
  final List<BiWeekdayEntry> weekdays;
  final BiTicketReport ticket;
  final List<BiEventProfitEntry> eventProfit;
  final BiDiscountReport discounts;
  final BiReturnReport costReturn;

  const BiReport({
    required this.summary,
    required this.salesByProduct,
    required this.salesByCategory,
    required this.purchasesByMaterial,
    required this.salesByPriceType,
    required this.timeSeries,
    required this.salesByEvent,
    required this.lowStock,
    required this.productMargins,
    required this.projection,
    required this.eventComparison,
    required this.materialCost,
    required this.noMovement,
    required this.periodComparison,
    required this.radar,
    required this.coPurchases,
    required this.weekdays,
    required this.ticket,
    required this.eventProfit,
    required this.discounts,
    required this.costReturn,
  });
}
