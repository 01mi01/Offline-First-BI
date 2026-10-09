import '../config/rounding.dart';
import '../models/bi_models.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import 'date_range_filter.dart';

// Lógica pura de la pantalla Inicio: qué puede ver cada usuario, el periodo
// elegido, cómo se describe el cambio frente al periodo anterior y cuáles son
// los últimos movimientos. No lee providers ni el reloj (recibe la fecha).

// Qué partes de Inicio puede ver una persona, a partir de los módulos que
// tiene permiso de leer. Un bloque que muestra datos de un módulo solo aparece
// si ese módulo es legible; los que mezclan dos (ganancia = ventas - gastos)
// piden ambos.
class HomeAccess {
  final bool sales;
  final bool purchases;
  final bool inventory;
  final bool clients;
  final bool reports;
  final bool businessIntelligence;

  const HomeAccess({
    this.sales = false,
    this.purchases = false,
    this.inventory = false,
    this.clients = false,
    this.reports = false,
    this.businessIntelligence = false,
  });

  factory HomeAccess.from(List<String> readableModules) => HomeAccess(
    sales: readableModules.contains('ventas'),
    purchases: readableModules.contains('compras'),
    inventory: readableModules.contains('inventario'),
    clients: readableModules.contains('clientes'),
    reports: readableModules.contains('reportes'),
    businessIntelligence: readableModules.contains('business_intelligence'),
  );

  // Ganancia, evolución e ingresos frente a gastos mezclan ventas y compras.
  bool get profit => sales && purchases;

  // Hace falta calcular el reporte del periodo solo si algo lo usa.
  bool get needsReport => sales || purchases;

  bool get hasAnyShortcut => shortcuts.isNotEmpty;

  List<HomeShortcut> get shortcuts => [
    if (inventory) HomeShortcut.products,
    if (sales) HomeShortcut.sales,
    if (reports) HomeShortcut.reports,
    if (businessIntelligence) HomeShortcut.businessIntelligence,
  ];
}

// Accesos rápidos de Inicio, en el orden en que se muestran.
enum HomeShortcut {
  products('Productos'),
  sales('Ventas'),
  reports('Reportes'),
  businessIntelligence('BI');

  final String label;
  const HomeShortcut(this.label);
}

// Periodo que muestra Inicio. La semana empieza en lunes.
enum HomePeriod {
  today('Hoy', 'de hoy', 'hoy'),
  week('Esta semana', 'de la semana', 'esta semana'),
  month('Este mes', 'del mes', 'este mes'),
  year('Este año', 'del año', 'este año');

  final String label;
  // "Ganancia de hoy", "Ventas de la semana"...
  final String ofLabel;
  // "Aún no hay ventas hoy", "... esta semana".
  final String duringLabel;
  const HomePeriod(this.label, this.ofLabel, this.duringLabel);

  DateTime start(DateTime today) {
    final day = dateOnly(today);
    return switch (this) {
      HomePeriod.today => day,
      HomePeriod.week => DateTime(
        day.year,
        day.month,
        day.day - (day.weekday - DateTime.monday),
      ),
      HomePeriod.month => DateTime(day.year, day.month),
      HomePeriod.year => DateTime(day.year),
    };
  }

  // Periodo anterior con los mismos días transcurridos: ayer, la semana
  // anterior hasta el mismo día, el mes anterior hasta el mismo día (o su
  // último día) y el año anterior hasta el mismo mes y día.
  ({DateTime start, DateTime end}) previous(DateTime today) {
    final day = dateOnly(today);
    final from = start(day);
    int lastDay(int year, int month) => DateTime(year, month + 1, 0).day;
    switch (this) {
      case HomePeriod.today:
        final yesterday = DateTime(day.year, day.month, day.day - 1);
        return (start: yesterday, end: yesterday);
      case HomePeriod.week:
        return (
          start: DateTime(from.year, from.month, from.day - 7),
          end: DateTime(day.year, day.month, day.day - 7),
        );
      case HomePeriod.month:
        final first = DateTime(day.year, day.month - 1);
        final last = lastDay(first.year, first.month);
        return (
          start: first,
          end: DateTime(first.year, first.month, day.day < last ? day.day : last),
        );
      case HomePeriod.year:
        final last = lastDay(day.year - 1, day.month);
        return (
          start: DateTime(day.year - 1),
          end: DateTime(day.year - 1, day.month, day.day < last ? day.day : last),
        );
    }
  }

  // "Hoy frente a ayer", "Este mes frente al anterior"...
  String get comparisonLabel => switch (this) {
    HomePeriod.today => 'Hoy frente a ayer',
    HomePeriod.week => 'Esta semana frente a la anterior',
    HomePeriod.month => 'Este mes frente al anterior',
    HomePeriod.year => 'Este año frente al anterior',
  };
}

// Margen de ganancia: ganancia como porcentaje de las ventas.
// Sin ventas no hay base y se muestra un guion.
String marginText(double sales, double profit) {
  if (sales <= 0) return '—';
  final pct = profit / sales * 100;
  if (pct.isNaN || pct.isInfinite) return '—';
  return '${fixed2(pct)}%';
}

enum HomeBucket { hour, day, month }

class HomeProfitPoint {
  final DateTime start;
  final double sales;
  final double expenses;

  const HomeProfitPoint(this.start, this.sales, this.expenses);

  double get profit => round2(sales - expenses);
}

class HomeProfitSeries {
  final HomeBucket bucket;
  final List<HomeProfitPoint> points;

  const HomeProfitSeries(this.bucket, this.points);

  bool get hasMovement => points.any((p) => p.sales != 0 || p.expenses != 0);

  // Posiciones de las etiquetas del eje: de 3 a 5, repartidas por igual.
  List<int> get axisIndexes {
    final n = points.length;
    if (n <= 5) return [for (var i = 0; i < n; i++) i];
    const count = 5;
    return {
      for (var k = 0; k < count; k++) ((n - 1) * k / (count - 1)).round(),
    }.toList();
  }
}

typedef HomeAmount = ({DateTime date, double amount});

const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _hourLabel(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:00';

// Etiqueta corta del eje: hora, día de la semana, número de día o mes.
String homeAxisLabel(HomePeriod period, DateTime start) => switch (period) {
  HomePeriod.today => _hourLabel(start),
  HomePeriod.week => _weekdays[start.weekday - 1],
  HomePeriod.month => '${start.day}',
  HomePeriod.year => _months[start.month - 1],
};

// Etiqueta del intervalo tocado: "14:00", "Mar 7 oct", "oct 2026".
String homeBucketLabel(HomeBucket bucket, DateTime start) => switch (bucket) {
  HomeBucket.hour => _hourLabel(start),
  HomeBucket.day =>
    '${_weekdays[start.weekday - 1]} ${start.day} ${_months[start.month - 1]}',
  HomeBucket.month => '${_months[start.month - 1]} ${start.year}',
};

// Ventas, gastos y ganancia por intervalo: horas en Hoy, días en la semana y
// el mes, meses en el año. Va del inicio del periodo hasta el intervalo actual,
// con ceros donde no hubo movimiento.
HomeProfitSeries buildProfitSeries({
  required HomePeriod period,
  required List<HomeAmount> sales,
  required List<HomeAmount> expenses,
  required DateTime now,
}) {
  final today = dateOnly(now);
  final from = period.start(today);
  final bucket = switch (period) {
    HomePeriod.today => HomeBucket.hour,
    HomePeriod.year => HomeBucket.month,
    _ => HomeBucket.day,
  };

  DateTime keyOf(DateTime d) => switch (bucket) {
    HomeBucket.hour => DateTime(d.year, d.month, d.day, d.hour),
    HomeBucket.day => DateTime(d.year, d.month, d.day),
    HomeBucket.month => DateTime(d.year, d.month),
  };
  DateTime next(DateTime d) => switch (bucket) {
    HomeBucket.hour => DateTime(d.year, d.month, d.day, d.hour + 1),
    HomeBucket.day => DateTime(d.year, d.month, d.day + 1),
    HomeBucket.month => DateTime(d.year, d.month + 1),
  };

  final last = keyOf(now);
  final salesByKey = <DateTime, double>{};
  final expensesByKey = <DateTime, double>{};
  void add(Map<DateTime, double> into, HomeAmount item) {
    var key = keyOf(item.date);
    if (key.isAfter(last)) key = last;
    into[key] = (into[key] ?? 0) + item.amount;
  }

  for (final s in sales) {
    add(salesByKey, s);
  }
  for (final e in expenses) {
    add(expensesByKey, e);
  }

  final points = <HomeProfitPoint>[];
  for (var cursor = keyOf(from); !cursor.isAfter(last); cursor = next(cursor)) {
    points.add(
      HomeProfitPoint(
        cursor,
        round2(salesByKey[cursor] ?? 0),
        round2(expensesByKey[cursor] ?? 0),
      ),
    );
  }
  return HomeProfitSeries(bucket, points);
}

// Cambio de un valor frente al periodo anterior, listo para mostrarse.
enum HomeTrend { up, down, flat, none }

class HomeChange {
  final HomeTrend trend;

  // Porcentaje ya redondeado; null si no hay base de comparación.
  final double? pct;

  const HomeChange._(this.trend, this.pct);

  static const HomeChange none = HomeChange._(HomeTrend.none, null);

  // [current] frente a [previous]. Con periodo anterior en 0 no hay base y no
  // se inventa un porcentaje (nunca NaN ni infinito).
  factory HomeChange.of(double current, double previous) {
    final pct = BiPeriodComparison.changePct(current, previous);
    if (pct == null || pct.isNaN || pct.isInfinite) return none;
    if (pct > 0) return HomeChange._(HomeTrend.up, pct);
    if (pct < 0) return HomeChange._(HomeTrend.down, pct);
    return HomeChange._(HomeTrend.flat, 0);
  }

  // "+12.50%", "-8.00%", "0.00%"; siempre con signo cuando hay cambio.
  String get label {
    final value = pct;
    if (value == null) return 'Sin comparación';
    final text = fixed2(value.abs());
    return switch (trend) {
      HomeTrend.up => '+$text%',
      HomeTrend.down => '-$text%',
      _ => '$text%',
    };
  }
}

// Un movimiento reciente: una venta o una compra.
class HomeActivity {
  final SaleModel? sale;
  final PurchaseModel? purchase;
  final String title;
  final DateTime date;
  final double amount;
  final bool isCanceled;

  HomeActivity.sale({
    required SaleModel this.sale,
    required this.title,
  }) : purchase = null,
       date = sale.date,
       amount = sale.finalAmount,
       isCanceled = sale.isCanceled;

  HomeActivity.purchase({
    required PurchaseModel this.purchase,
    required this.title,
  }) : sale = null,
       date = purchase.date,
       amount = purchase.totalAmount,
       isCanceled = purchase.isCanceled;

  bool get isSale => sale != null;
}

// Los últimos [limit] movimientos (ventas y compras) del más reciente al más
// antiguo. Los registros con fecha futura todavía no ocurrieron y no cuentan;
// los cancelados sí aparecen (con su etiqueta). [clientName] y [supplierName]
// dan el título de cada fila; solo entra lo que la persona puede ver.
List<HomeActivity> recentActivity({
  required List<SaleModel> sales,
  required List<PurchaseModel> purchases,
  required String Function(SaleModel) clientName,
  required String Function(PurchaseModel) supplierName,
  required DateTime now,
  bool includeSales = true,
  bool includePurchases = true,
  int limit = 5,
}) {
  final items = <HomeActivity>[
    if (includeSales)
      for (final s in sales)
        if (!isFutureDated(s.date, now: now))
          HomeActivity.sale(sale: s, title: clientName(s)),
    if (includePurchases)
      for (final p in purchases)
        if (!isFutureDated(p.date, now: now))
          HomeActivity.purchase(purchase: p, title: supplierName(p)),
  ];
  items.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    // Misma fecha y hora: el registrado después va primero.
    final aCreated = a.sale?.createdAt ?? a.purchase!.createdAt;
    final bCreated = b.sale?.createdAt ?? b.purchase!.createdAt;
    return bCreated.compareTo(aCreated);
  });
  return items.take(limit).toList();
}
