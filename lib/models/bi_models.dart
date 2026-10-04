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

  // Número de ventas del intervalo, sus ventas brutas (antes de descuentos) y
  // los descuentos dados: de ahí salen el ticket promedio y el impacto de los
  // descuentos en el tiempo, con los mismos intervalos que ingresos y gastos.
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

  // Ticket promedio del intervalo; null si no hubo ventas.
  double? get ticket => ventas > 0 ? ingresos / ventas : null;

  // Descuentos como % de las ventas brutas del intervalo; null sin ventas.
  double? get descuentoPct => bruto > 0 ? descuentos / bruto * 100 : null;
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

// ---------------------------------------------------------------------------
// Indicadores de ventas adicionales
// ---------------------------------------------------------------------------

// Un par de productos que aparecen juntos en las mismas ventas.
class BiPairEntry {
  final String productA;
  final String productB;

  // Ventas (del periodo) que contienen ambos productos.
  final int sales;

  // Esas ventas como % de todas las ventas del periodo.
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
  // Pares con al menos [coPurchaseMinSales] ventas, de más a menos ventas.
  final List<BiPairEntry> pairs;

  // Todas las ventas del periodo (base del porcentaje) y cuántas de ellas
  // llevan 2 o más productos distintos.
  final int totalSales;
  final int multiProductSales;

  const BiCoPurchaseReport({
    required this.pairs,
    required this.totalSales,
    required this.multiProductSales,
  });
}

// Mínimo de ventas en común para que un par se muestre.
const int coPurchaseMinSales = 3;

// Ingresos y ventas de un día de la semana.
class BiWeekdayEntry {
  // DateTime.monday (1) ... DateTime.sunday (7).
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

// Ticket promedio del periodo: ingresos netos ÷ número de ventas.
class BiTicketReport {
  final int salesCount;
  final double total;

  const BiTicketReport({required this.salesCount, required this.total});

  double? get average => salesCount > 0 ? total / salesCount : null;
}

// Descuentos dados en el periodo frente a las ventas brutas.
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

  double? get pct => grossSales > 0 ? totalDiscount / grossSales * 100 : null;
}

// Resultado de un evento: ingresos de sus ventas menos todas sus compras.
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

  double get profit => income - expenses;
}

// Retorno sobre el costo de producción de un producto vendido: ganancia
// (ingresos netos menos costo de producción × unidades) por cada Bs. 1 de ese
// costo.
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

  double get profit => revenue - cost;

  // Ganancia por cada Bs. 1 de costo (el costo siempre es mayor que 0).
  double get ratio => profit / cost;
}

class BiReturnReport {
  // Del mejor al peor retorno.
  final List<BiReturnEntry> entries;

  // Productos vendidos sin costo de producción registrado (no entran).
  final int withoutCost;

  const BiReturnReport({required this.entries, required this.withoutCost});
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
