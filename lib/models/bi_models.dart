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

// Todos los indicadores de la pantalla para un conjunto de filtros.
class BiReport {
  final BiSummary summary;
  final List<BiEntry> salesByProduct;
  final List<BiEntry> salesByCategory;
  final List<BiEntry> purchasesByMaterial;
  final List<BiEntry> salesByPriceType;
  final BiTimeSeries timeSeries;
  final List<BiEntry> salesByEvent;
  final List<LowStockEntry> lowStock;

  const BiReport({
    required this.summary,
    required this.salesByProduct,
    required this.salesByCategory,
    required this.purchasesByMaterial,
    required this.salesByPriceType,
    required this.timeSeries,
    required this.salesByEvent,
    required this.lowStock,
  });
}
