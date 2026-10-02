import 'package:flutter/foundation.dart';
import 'report_filters.dart';

// Configuración de Business Intelligence: qué periodo y filtros se aplican,
// qué indicadores se ven y con qué tipo de gráfico.

// Formas de visualizar un indicador. No todas valen para todos los
// indicadores: cada [BiIndicator] declara las suyas.
enum BiChartType {
  bar('Barras'),
  pie('Pastel'),
  line('Líneas'),
  list('Lista'),
  cards('Tarjetas'),
  radar('Radar');

  final String label;
  const BiChartType(this.label);
}

// Grupo con el que se agrupan los indicadores al elegirlos.
enum BiGroup {
  resumen('Resumen'),
  ventas('Ventas'),
  compras('Compras y materiales'),
  inventario('Inventario');

  final String label;
  const BiGroup(this.label);
}

// Los indicadores del módulo, en el orden en que se muestran. Cada uno lleva
// el texto de su icono de información: qué muestra y para qué sirve.
enum BiIndicator {
  summary(
    group: BiGroup.resumen,
    title: 'Resumen del periodo',
    description: 'Ingresos, gastos y balance',
    defaultSelected: true,
    info:
        'Qué muestra: el total de ingresos (ventas ya descontados los '
        'descuentos), el total de gastos (todas las compras) y el balance '
        '(ingresos − gastos) del periodo y los filtros elegidos.\n\n'
        'Para qué sirve: saber de un vistazo si el negocio ganó o perdió '
        'dinero en ese periodo.',
  ),
  periodComparison(
    group: BiGroup.resumen,
    title: 'Comparación entre periodos',
    description: 'Este periodo frente al anterior equivalente',
    chartTypes: [BiChartType.cards, BiChartType.bar],
    defaultSelected: true,
    info:
        'Qué muestra: los ingresos, gastos y balance del periodo elegido junto '
        'a los del periodo inmediatamente anterior de igual tamaño (este mes '
        'frente al mes pasado, esta semana frente a la semana pasada, o los '
        'mismos días justo antes si el rango es a medida), con el porcentaje '
        'de cambio. Se compara el mismo número de días transcurridos, para '
        'que un mes a medias no se mida contra un mes completo.\n\n'
        'Para qué sirve: ver si el negocio va mejor o peor que antes. Requiere '
        'un periodo con fechas (no "todo el historial").',
  ),
  timeSeries(
    group: BiGroup.ventas,
    title: 'Evolución en el tiempo',
    description: 'Ingresos y gastos a lo largo del periodo',
    chartTypes: [BiChartType.line, BiChartType.bar],
    defaultSelected: true,
    info:
        'Qué muestra: cómo cambian los ingresos y los gastos dentro del '
        'periodo, por día, semana o mes según lo largo que sea el rango.\n\n'
        'Para qué sirve: detectar picos, caídas y temporadas fuertes o '
        'flojas.',
  ),
  salesProjection(
    group: BiGroup.ventas,
    title: 'Proyección de ventas',
    description: 'Tendencia reciente extendida hacia adelante',
    info:
        'Qué muestra: los ingresos del periodo (línea continua) y una línea '
        'punteada con la tendencia de los últimos intervalos completos, '
        'prolongada hacia el futuro con una proyección lineal simple.\n\n'
        'Es una estimación basada en la tendencia reciente, no una garantía: '
        'no considera temporadas, eventos ni cambios de precio. Requiere un '
        'periodo que llegue hasta hoy y al menos 3 intervalos completos.\n\n'
        'Para qué sirve: tener una idea orientativa de hacia dónde van las '
        'ventas.',
  ),
  salesByProduct(
    group: BiGroup.ventas,
    title: 'Ventas por producto',
    description: 'Qué productos se vendieron más',
    chartTypes: [BiChartType.bar, BiChartType.pie],
    defaultSelected: true,
    info:
        'Qué muestra: los productos más vendidos del periodo, por ingresos o '
        'por unidades.\n\n'
        'Para qué sirve: saber qué productos sostienen las ventas y cuáles '
        'aportan poco.',
  ),
  productMargin(
    group: BiGroup.ventas,
    title: 'Margen de ganancia por producto',
    description: 'Rentabilidad real de cada producto',
    chartTypes: [BiChartType.bar, BiChartType.list],
    defaultSelected: true,
    info:
        'Qué muestra: la ganancia de cada producto vendido en el periodo: '
        'ingresos menos costo de producción de las unidades vendidas, como '
        'porcentaje del ingreso (margen) y en monto. Solo aparecen productos '
        'con costo de producción registrado.\n\n'
        'Para qué sirve: ver la rentabilidad real, no solo el volumen: un '
        'producto con muchos ingresos puede dejar poca ganancia, y uno que '
        'vende poco puede ser muy rentable.',
  ),
  salesByCategory(
    group: BiGroup.ventas,
    title: 'Ventas por categoría',
    description: 'Ingresos o unidades por categoría',
    chartTypes: [BiChartType.bar, BiChartType.pie],
    defaultSelected: true,
    info:
        'Qué muestra: cuánto se vendió en cada categoría de producto '
        '(incluida "Sin categoría").\n\n'
        'Para qué sirve: saber qué tipo de producto funciona mejor.',
  ),
  salesByPriceType(
    group: BiGroup.ventas,
    title: 'Ventas por tipo de precio',
    description: 'Precio A frente a Precio B',
    chartTypes: [BiChartType.pie, BiChartType.bar],
    defaultSelected: true,
    info:
        'Qué muestra: cuánto se vendió con Precio A y cuánto con Precio B.\n\n'
        'Para qué sirve: entender qué parte de tus ventas sale con cada lista '
        'de precios.',
  ),
  salesByEvent(
    group: BiGroup.ventas,
    title: 'Ventas por evento',
    description: 'Ingresos de las ventas ligadas a cada evento',
    chartTypes: [BiChartType.bar, BiChartType.pie],
    defaultSelected: true,
    info:
        'Qué muestra: los ingresos de las ventas vinculadas a cada evento. '
        'Cada venta cuenta por su propia fecha.\n\n'
        'Para qué sirve: saber qué eventos dejaron más dinero.',
  ),
  eventComparison(
    group: BiGroup.ventas,
    title: 'Evento vs. días regulares',
    description: 'Cuánto se vende en eventos frente a días normales',
    chartTypes: [BiChartType.cards, BiChartType.bar],
    info:
        'Qué muestra: el promedio de ventas por día y por venta en los días '
        'de evento (según las fechas de cada evento) frente a los días sin '
        'evento, dentro del periodo.\n\n'
        'Para qué sirve: responder si vale la pena asistir a eventos. Es una '
        'comparación orientativa: no descuenta lo que cuesta ir al evento.',
  ),
  purchasesByMaterial(
    group: BiGroup.compras,
    title: 'Compras por material',
    description: 'En qué materiales se gastó más',
    chartTypes: [BiChartType.bar, BiChartType.pie],
    defaultSelected: true,
    info:
        'Qué muestra: cuánto se gastó en cada material comprado en el '
        'periodo, con la cantidad comprada.\n\n'
        'Para qué sirve: ver en qué materiales se va el dinero.',
  ),
  materialCostRatio(
    group: BiGroup.compras,
    title: 'Costo de materiales vs. ingresos',
    description: 'Cuánto se gasta en materiales por cada Bs. vendido',
    chartTypes: [BiChartType.cards, BiChartType.bar],
    info:
        'Qué muestra: el total gastado en compras de materiales frente al '
        'total de ingresos por ventas del periodo, y qué porcentaje del '
        'ingreso representa.\n\n'
        'Es un indicador aproximado, no un costo de ventas exacto: el costo '
        'de producción de cada producto se carga a mano y los materiales no '
        'se registran venta por venta; además compras y ventas de un mismo '
        'periodo no siempre corresponden entre sí.\n\n'
        'Para qué sirve: una señal rápida de cuánto de lo que vendes se va en '
        'materiales.',
  ),
  productRadar(
    group: BiGroup.ventas,
    title: 'Perfil comparativo de productos',
    description: 'Compara 2 a 4 productos en un radar',
    chartTypes: [BiChartType.radar],
    info:
        'Cómo leerlo: cada producto es un polígono; cuanto más lejos del '
        'centro llega un vértice, mejor es el producto en ese eje. Un '
        'polígono grande y parejo es un producto fuerte en todo.\n\n'
        'Ejes (todos de 0 a 100 %): Ingresos y Unidades, frente al producto '
        'que más vendió en el periodo; Margen, el porcentaje de ganancia '
        '(0 si no tiene costo de producción); Rotación, la parte del stock '
        'disponible que ya se vendió (unidades vendidas ÷ (vendidas + stock '
        'actual)).\n\n'
        'Para qué sirve: comparar productos a la vez en vez de por una sola '
        'cifra.',
  ),
  lowStock(
    group: BiGroup.inventario,
    title: 'Productos con bajo stock',
    description: 'Productos por agotarse',
    chartTypes: [BiChartType.list],
    defaultSelected: true,
    info:
        'Qué muestra: los productos activos con 3 unidades o menos en '
        'inventario ahora mismo. No depende del periodo ni de los filtros.\n\n'
        'Para qué sirve: saber qué producir o reponer antes de quedarte sin '
        'stock.',
  ),
  noMovement(
    group: BiGroup.inventario,
    title: 'Productos sin movimiento reciente',
    description: 'Productos activos que no se vendieron últimamente',
    chartTypes: [BiChartType.list],
    info:
        'Qué muestra: los productos activos sin ninguna venta en los últimos '
        'días que elijas (7, 15, 30, 60 o 90), con la fecha de su última '
        'venta. No depende del periodo ni de los filtros: mide la '
        'recencia.\n\n'
        'Para qué sirve: detectar inventario que no se está vendiendo.',
  );

  final BiGroup group;
  final String title;
  final String description;
  final String info;

  // Tipos de gráfico permitidos; el primero es el predeterminado. Con un solo
  // tipo no hay selector.
  final List<BiChartType> chartTypes;

  // ¿Viene marcado al abrir la configuración por primera vez?
  final bool defaultSelected;

  const BiIndicator({
    required this.group,
    required this.title,
    required this.description,
    required this.info,
    this.chartTypes = const [BiChartType.bar],
    this.defaultSelected = false,
  });

  bool get hasChartPicker => chartTypes.length > 1;
}

// Ventanas ofrecidas para "sin movimiento reciente", en días.
const List<int> noMovementWindowOptions = [7, 15, 30, 60, 90];
const int defaultNoMovementDays = 30;

// Mínimo y máximo de productos del radar.
const int radarMinProducts = 2;
const int radarMaxProducts = 4;

class BiConfig {
  final ReportFilters filters;
  final Set<BiIndicator> indicators;
  final Map<BiIndicator, BiChartType> chartTypes;
  final int noMovementDays;
  // Productos elegidos para el radar; vacío = los 3 con más ingresos.
  final List<int> radarProductIds;

  BiConfig({
    this.filters = const ReportFilters(),
    Set<BiIndicator>? indicators,
    this.chartTypes = const {},
    this.noMovementDays = defaultNoMovementDays,
    this.radarProductIds = const [],
  }) : indicators = indicators ?? defaultIndicators;

  static Set<BiIndicator> get defaultIndicators => {
    for (final i in BiIndicator.values)
      if (i.defaultSelected) i,
  };

  // Tipo de gráfico vigente de un indicador: el elegido si sigue siendo
  // válido, y si no, el predeterminado.
  BiChartType chartTypeFor(BiIndicator indicator) {
    final chosen = chartTypes[indicator];
    return chosen != null && indicator.chartTypes.contains(chosen)
        ? chosen
        : indicator.chartTypes.first;
  }

  BiConfig copyWith({
    ReportFilters? filters,
    Set<BiIndicator>? indicators,
    Map<BiIndicator, BiChartType>? chartTypes,
    int? noMovementDays,
    List<int>? radarProductIds,
  }) {
    return BiConfig(
      filters: filters ?? this.filters,
      indicators: indicators ?? this.indicators,
      chartTypes: chartTypes ?? this.chartTypes,
      noMovementDays: noMovementDays ?? this.noMovementDays,
      radarProductIds: radarProductIds ?? this.radarProductIds,
    );
  }

  // Lo único que cambia los CÁLCULOS (el resto es presentación).
  BiQuery get query => BiQuery(
    filters: filters,
    noMovementDays: noMovementDays,
    radarProductIds: radarProductIds,
  );
}

// Parámetros de cálculo de un reporte (clave del provider).
class BiQuery {
  final ReportFilters filters;
  final int noMovementDays;
  final List<int> radarProductIds;

  const BiQuery({
    required this.filters,
    this.noMovementDays = defaultNoMovementDays,
    this.radarProductIds = const [],
  });

  @override
  bool operator ==(Object other) =>
      other is BiQuery &&
      other.filters == filters &&
      other.noMovementDays == noMovementDays &&
      listEquals(other.radarProductIds, radarProductIds);

  @override
  int get hashCode =>
      Object.hash(filters, noMovementDays, Object.hashAll(radarProductIds));
}
