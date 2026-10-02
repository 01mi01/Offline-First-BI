import 'product_model.dart';

// Modelos de los indicadores del módulo de Business Intelligence.

// Tarjetas de resumen del periodo filtrado.
class BiSummary {
  final double ingresos;
  final double gastos;

  const BiSummary({required this.ingresos, required this.gastos});

  double get balance => ingresos - gastos;
}

// Una barra de un ranking (producto, categoría, material, evento...).
// [amount] es el dinero (ingresos o gasto) y [quantity] las unidades vendidas o
// compradas; en los eventos, [quantity] es el número de ventas.
class BiEntry {
  final String label;
  final double amount;
  final double quantity;

  // Unidad de la cantidad, si tiene sentido mostrarla (materiales).
  final String? unit;

  const BiEntry({
    required this.label,
    required this.amount,
    required this.quantity,
    this.unit,
  });
}

// Tamaño de los intervalos de la evolución temporal.
enum BiGranularity {
  day('Diaria'),
  week('Semanal'),
  month('Mensual');

  final String label;
  const BiGranularity(this.label);
}

// Un intervalo (día, semana o mes) de la evolución temporal. [start] es el
// primer día del intervalo.
class BiTimeBucket {
  final DateTime start;
  final double ingresos;
  final double gastos;

  const BiTimeBucket({
    required this.start,
    required this.ingresos,
    required this.gastos,
  });
}

class BiTimeSeries {
  final BiGranularity granularity;
  final List<BiTimeBucket> buckets;

  const BiTimeSeries({required this.granularity, required this.buckets});

  bool get isEmpty => buckets.isEmpty;
}

// Producto con poco stock, con el nombre de su categoría.
class LowStockEntry {
  final ProductModel product;
  final String categoryName;

  const LowStockEntry({required this.product, required this.categoryName});

  bool get isOutOfStock => product.stock <= 0;
}

// Margen de ganancia de un producto vendido en el periodo: ingresos menos el
// costo de producción de las unidades vendidas.
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

  double get profit => revenue - cost;

  // Ganancia como porcentaje del ingreso (0 si no hubo ingreso).
  double get marginPct => revenue > 0 ? profit / revenue * 100 : 0;
}

class BiMarginReport {
  // De mayor a menor margen porcentual.
  final List<BiMarginEntry> entries;

  // Productos vendidos en el periodo que no tienen costo de producción
  // registrado, y por eso no pueden entrar al ranking.
  final int withoutCost;

  const BiMarginReport({required this.entries, required this.withoutCost});
}

// Un punto de la línea de tendencia/proyección.
class BiTrendPoint {
  final DateTime start;
  final double value;

  const BiTrendPoint({required this.start, required this.value});
}

// Proyección lineal simple de los ingresos. Si no se puede calcular,
// [unavailableReason] explica por qué.
class BiProjection {
  final String? unavailableReason;
  final BiGranularity granularity;

  // Tendencia ajustada sobre los últimos intervalos completos (línea
  // punteada sobre lo ya ocurrido).
  final List<BiTrendPoint> fitted;

  // Intervalos futuros estimados, después del intervalo de hoy.
  final List<BiTrendPoint> projected;

  // Cambio estimado de ingresos por intervalo.
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

  double get projectedTotal => projected.fold(0.0, (s, p) => s + p.value);
}

// Ventas de los días con evento frente a los días sin evento.
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

  double? get eventPerDay => eventDays > 0 ? eventRevenue / eventDays : null;
  double? get regularPerDay =>
      regularDays > 0 ? regularRevenue / regularDays : null;
  double? get eventPerSale => eventSales > 0 ? eventRevenue / eventSales : null;
  double? get regularPerSale =>
      regularSales > 0 ? regularRevenue / regularSales : null;

  // Cuánto más (o menos) se vende por día en evento, en porcentaje.
  double? get perDayDifferencePct {
    final e = eventPerDay;
    final r = regularPerDay;
    if (e == null || r == null || r == 0) return null;
    return (e - r) / r * 100;
  }
}

// Gasto en materiales frente a ingresos por ventas.
class BiMaterialCost {
  final double materialSpend;
  final double revenue;

  const BiMaterialCost({required this.materialSpend, required this.revenue});

  // Parte del ingreso que se fue en materiales (en %), si hubo ingresos.
  double? get ratioPct => revenue > 0 ? materialSpend / revenue * 100 : null;
}

// Producto activo sin ventas en la ventana reciente.
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

// Comparación del periodo elegido con el anterior equivalente.
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

  // Cambio porcentual de [current] respecto de [previous]; null si el periodo
  // anterior es 0 (no hay base de comparación). Con base negativa se usa su
  // valor absoluto, para que "mejor" siempre sea positivo.
  static double? changePct(double current, double previous) {
    if (previous == 0) return null;
    return (current - previous) / previous.abs() * 100;
  }
}

// Un producto del radar, con sus valores reales y normalizados (0 a 1).
class BiRadarProduct {
  final int id;
  final String name;
  final double revenue;
  final int units;
  final int stock;
  // Margen en %, o null si el producto no tiene costo de producción.
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

  // true si se eligieron solos (los de más ingresos) por no haber una
  // selección válida.
  final bool autoSelected;

  const BiRadar({required this.products, required this.autoSelected});
}

// Todos los indicadores de la pantalla para un conjunto de parámetros.
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
  });
}
