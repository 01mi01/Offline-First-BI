import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Interacción común de los gráficos de Business Intelligence: animación de
// entrada, globo de detalle al tocar, leyenda que oculta series y vista con
// zoom y arrastre sobre el eje del tiempo. Los colores de los gráficos siguen
// saliendo de chartColorAt; aquí solo se usan los colores de la interfaz.

// ---------------------------------------------------------------------------
// Animación de entrada
// ---------------------------------------------------------------------------

const Duration kBiEntranceDuration = Duration(milliseconds: 700);

// Reproduce una vez, al aparecer, un avance [t] de 0 a 1 (con una curva suave)
// que el gráfico usa para crecer, dibujarse o barrerse. Si el sistema pide
// reducir las animaciones, [t] vale 1 desde el primer cuadro. Al cambiar el
// tipo de gráfico el widget se reemplaza y la animación vuelve a correr.
class BiEntrance extends StatefulWidget {
  final Widget Function(BuildContext context, double t) builder;

  const BiEntrance({super.key, required this.builder});

  @override
  State<BiEntrance> createState() => _BiEntranceState();
}

class _BiEntranceState extends State<BiEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kBiEntranceDuration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) => widget.builder(context, _progress.value),
    );
  }
}

// Revela el gráfico de izquierda a derecha (las líneas se dibujan solas).
class BiRevealClip extends StatelessWidget {
  final double t;
  final Widget child;

  const BiRevealClip({super.key, required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    if (t >= 1) return child;
    return ClipRect(clipper: _RevealClipper(t), child: child);
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  final double t;

  _RevealClipper(this.t);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * t, size.height);

  @override
  bool shouldReclip(_RevealClipper oldClipper) => oldClipper.t != t;
}

// Revela el pastel con un barrido en el sentido de las agujas del reloj,
// desde el mismo punto donde empieza la primera rebanada.
class BiSweepClip extends StatelessWidget {
  final double t;
  final Widget child;

  const BiSweepClip({super.key, required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    if (t >= 1) return child;
    return ClipPath(clipper: _SweepClipper(t), child: child);
  }
}

class _SweepClipper extends CustomClipper<Path> {
  final double t;

  _SweepClipper(this.t);

  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    return Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: size.longestSide),
        0,
        2 * math.pi * t,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(_SweepClipper oldClipper) => oldClipper.t != t;
}

// ---------------------------------------------------------------------------
// Globo de detalle
// ---------------------------------------------------------------------------

// Contenido de un globo: lo que se tocó (título) y sus valores ya formateados.
class BiTip {
  final String title;
  final List<String> lines;
  final Color? color;

  const BiTip({required this.title, this.lines = const [], this.color});
}

// Capa que muestra el globo de detalle sobre el gráfico que envuelve. Se
// maneja desde fuera con una GlobalKey (showLocal / showGlobal / hide). El
// globo no captura toques, se cierra solo a los pocos segundos y siempre queda
// dentro de la capa.
class BiTooltipLayer extends StatefulWidget {
  final Widget child;

  // Se llama cuando el globo desaparece (cerrado por el gráfico o por el
  // tiempo), para que el gráfico quite también la marca del punto tocado.
  final VoidCallback? onHidden;

  const BiTooltipLayer({super.key, required this.child, this.onHidden});

  @override
  State<BiTooltipLayer> createState() => BiTooltipLayerState();
}

class BiTooltipLayerState extends State<BiTooltipLayer> {
  static const Duration visibleFor = Duration(seconds: 4);

  Offset? _anchor;
  BiTip? _tip;
  Timer? _timer;

  bool get isShowing => _tip != null;

  // [local] está en las coordenadas de esta capa.
  void showLocal(Offset local, BiTip tip) {
    _timer?.cancel();
    _timer = Timer(visibleFor, hide);
    setState(() {
      _anchor = local;
      _tip = tip;
    });
  }

  void showGlobal(Offset global, BiTip tip) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    showLocal(box.globalToLocal(global), tip);
  }

  // [notify] en false evita avisar a [BiTooltipLayer.onHidden] (por ejemplo
  // al reconstruirse el gráfico, que ya limpia su propio estado).
  void hide({bool notify = true}) {
    _timer?.cancel();
    _timer = null;
    if (_tip == null || !mounted) return;
    setState(() {
      _tip = null;
      _anchor = null;
    });
    if (notify) widget.onHidden?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = _tip;
    final anchor = _anchor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (tip != null && anchor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomSingleChildLayout(
                delegate: _BubbleLayout(anchor),
                child: _Bubble(tip: tip),
              ),
            ),
          ),
      ],
    );
  }
}

class _BubbleLayout extends SingleChildLayoutDelegate {
  final Offset anchor;

  _BubbleLayout(this.anchor);

  // El globo puede ser más alto que la capa (p. ej. un ranking de pocas filas):
  // solo se le limita el ancho.
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (anchor.dx - childSize.width / 2)
        .clamp(0.0, math.max(0.0, size.width - childSize.width))
        .toDouble();
    // Encima del punto tocado; si no cabe, debajo.
    var y = anchor.dy - childSize.height - 12;
    if (y < 0) y = anchor.dy + 16;
    y = y.clamp(0.0, math.max(0.0, size.height - childSize.height)).toDouble();
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_BubbleLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}

class _Bubble extends StatelessWidget {
  final BiTip tip;

  const _Bubble({required this.tip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('bi-tooltip'),
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowNeutral,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tip.color != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: tip.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s6),
                ],
                Flexible(
                  child: Text(
                    tip.title,
                    style: theme.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            // Una línea vacía (p. ej. el texto de cantidad de un indicador que no
            // tiene) no deja un hueco en el globo.
            for (final line in tip.lines.where((l) => l.isNotEmpty))
              Text(
                line,
                style: theme.labelMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leyenda que oculta series
// ---------------------------------------------------------------------------

class BiLegendItem {
  final String label;
  final Color color;
  final bool dashed;

  const BiLegendItem({
    required this.label,
    required this.color,
    this.dashed = false,
  });
}

// Resultado de tocar la serie [index] en una leyenda de [total] series: la
// oculta o la vuelve a mostrar, pero nunca deja todas ocultas (ocultar la
// última visible no hace nada).
Set<int> toggleSeries(Set<int> hidden, int index, int total) {
  final next = {...hidden};
  if (next.contains(index)) {
    next.remove(index);
  } else if (next.length < total - 1) {
    next.add(index);
  }
  return next;
}

// Leyenda de un gráfico con varias series: tocar un elemento oculta o muestra
// esa serie.
class BiToggleLegend extends StatelessWidget {
  final List<BiLegendItem> items;
  final Set<int> hidden;
  final ValueChanged<int> onToggle;
  final String keyPrefix;

  const BiToggleLegend({
    super.key,
    required this.items,
    required this.hidden,
    required this.onToggle,
    this.keyPrefix = 'bi-legend',
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s4,
      children: [
        for (var i = 0; i < items.length; i++)
          _LegendChip(
            key: ValueKey('$keyPrefix-$i'),
            item: items[i],
            visible: !hidden.contains(i),
            onTap: () => onToggle(i),
          ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final BiLegendItem item;
  final bool visible;
  final VoidCallback onTap;

  const _LegendChip({
    super.key,
    required this.item,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondary.withValues(alpha: 0.7);
    return Semantics(
      button: true,
      toggled: visible,
      label: item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s6,
              vertical: AppSpacing.s4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: visible && !item.dashed
                        ? item.color
                        : Colors.transparent,
                    border: visible && !item.dashed
                        ? null
                        : Border.all(
                            color: visible ? item.color : muted,
                            width: 2,
                          ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.s6),
                Flexible(
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: visible ? AppColors.textSecondary : muted,
                      decoration: visible ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zoom y arrastre sobre el eje del tiempo
// ---------------------------------------------------------------------------

// Ancho reservado a la izquierda del gráfico para el eje de montos; el eje del
// tiempo se dibuja aparte y necesita saber dónde empieza el área de trazado.
const double kBiMoneyAxisReserved = 40;

typedef BiZoomChartBuilder =
    Widget Function(BuildContext context, double minX, double maxX);

// Un gráfico de líneas sobre el tiempo con zoom de dos dedos y arrastre
// horizontal para moverse. fl_chart 0.68 no trae zoom, así que la ventana
// visible del eje X (minX–maxX) la controla este widget con los punteros en
// bruto: esos eventos no entran en la competencia de gestos, de modo que el
// gráfico conserva sus toques y la lista sigue desplazándose en vertical.
// Las etiquetas del eje de abajo se dibujan aquí, alineadas con la ventana.
//
// [chartBuilder] debe crear el gráfico con [minX]/[maxX] recibidos, sin ejes
// inferiores y con los datos recortados al área (FlClipData.all()).
class BiZoomableTimeChart extends StatefulWidget {
  // El eje X completo va de 0 a [maxX]; hay [count] posiciones enteras con
  // etiqueta ([labelOf]).
  final double maxX;
  final int count;
  final String Function(int index) labelOf;
  final BiZoomChartBuilder chartBuilder;
  final GlobalKey<BiTooltipLayerState>? tooltipKey;
  // Se llama cuando el globo del gráfico desaparece (ver
  // [BiTooltipLayer.onHidden]).
  final VoidCallback? onTooltipHidden;
  final double height;
  final double rightPadding;

  const BiZoomableTimeChart({
    super.key,
    required this.maxX,
    required this.count,
    required this.labelOf,
    required this.chartBuilder,
    this.tooltipKey,
    this.onTooltipHidden,
    this.height = 220,
    this.rightPadding = AppSpacing.s8,
  });

  // Menor ancho visible, en intervalos.
  static const double minVisibleSpan = 2;

  @override
  State<BiZoomableTimeChart> createState() => _BiZoomableTimeChartState();
}

class _BiZoomableTimeChartState extends State<BiZoomableTimeChart> {
  late double _min = 0;
  late double _max = widget.maxX;

  final Map<int, Offset> _pointers = {};
  double _plotWidth = 1;

  // Dos dedos: distancia y ventana al empezar, y el valor de X bajo los dedos.
  double _pinchStartDistance = 1;
  double _pinchStartSpan = 1;
  double _pinchFocalValue = 0;

  // Arrastre de un dedo: dónde empezó, la ventana de entonces y si es
  // horizontal (null mientras no se sabe).
  Offset _dragOrigin = Offset.zero;
  double _dragStartMin = 0;
  bool? _dragIsHorizontal;

  bool get _zoomable => widget.maxX >= BiZoomableTimeChart.minVisibleSpan + 1;

  bool get _zoomed => _min > 0.0001 || _max < widget.maxX - 0.0001;

  @override
  void didUpdateWidget(BiZoomableTimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxX != widget.maxX) {
      _min = 0;
      _max = widget.maxX;
    }
  }

  void _setWindow(double min, double span) {
    final full = widget.maxX;
    final width = span.clamp(
      math.min(BiZoomableTimeChart.minVisibleSpan, full),
      full,
    );
    final lo = min.clamp(0.0, full - width);
    if ((lo - _min).abs() < 1e-9 && (lo + width - _max).abs() < 1e-9) return;
    widget.tooltipKey?.currentState?.hide();
    setState(() {
      _min = lo;
      _max = lo + width;
    });
  }

  void reset() => _setWindow(0, widget.maxX);

  // Posición de un dedo como fracción del área de trazado (0 a 1).
  double _fraction(double dx) =>
      ((dx - kBiMoneyAxisReserved) / _plotWidth).clamp(0.0, 1.0);

  void _beginPinch() {
    final points = _pointers.values.toList();
    _pinchStartDistance = math.max(1, (points[0] - points[1]).distance);
    _pinchStartSpan = _max - _min;
    final focal = (points[0].dx + points[1].dx) / 2;
    _pinchFocalValue = _min + _fraction(focal) * _pinchStartSpan;
  }

  void _rebaseDrag() {
    final point = _pointers.values.first;
    _dragOrigin = point;
    _dragStartMin = _min;
    _dragIsHorizontal = true;
  }

  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (!_zoomable) return;
    if (_pointers.length == 2) {
      _beginPinch();
    } else if (_pointers.length == 1) {
      _dragOrigin = e.localPosition;
      _dragStartMin = _min;
      _dragIsHorizontal = null;
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (!_zoomable) return;
    if (_pointers.length == 2) {
      final points = _pointers.values.toList();
      final distance = math.max(1.0, (points[0] - points[1]).distance);
      final span = _pinchStartSpan * _pinchStartDistance / distance;
      final focal = (points[0].dx + points[1].dx) / 2;
      // El valor que estaba bajo los dedos sigue bajo ellos.
      final clamped = span
          .clamp(
            math.min(BiZoomableTimeChart.minVisibleSpan, widget.maxX),
            widget.maxX,
          )
          .toDouble();
      _setWindow(_pinchFocalValue - _fraction(focal) * clamped, clamped);
    } else if (_pointers.length == 1 && _zoomed) {
      final delta = e.localPosition - _dragOrigin;
      _dragIsHorizontal ??= (delta.dx.abs() > 8 || delta.dy.abs() > 8)
          ? delta.dx.abs() > delta.dy.abs()
          : null;
      if (_dragIsHorizontal == true) {
        final span = _max - _min;
        _setWindow(_dragStartMin - delta.dx / _plotWidth * span, span);
      }
    }
  }

  void _onUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (!_zoomable) return;
    if (_pointers.length == 1) {
      _rebaseDrag();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _plotWidth = math.max(
                1,
                constraints.maxWidth -
                    kBiMoneyAxisReserved -
                    widget.rightPadding,
              );
              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _onDown,
                onPointerMove: _onMove,
                onPointerUp: _onUp,
                onPointerCancel: _onUp,
                child: Padding(
                  padding: EdgeInsets.only(right: widget.rightPadding),
                  child: BiTooltipLayer(
                    key: widget.tooltipKey,
                    onHidden: widget.onTooltipHidden,
                    child: BiEntrance(
                      key: const ValueKey('bi-entrance-lines'),
                      builder: (context, t) => BiRevealClip(
                        t: t,
                        child: widget.chartBuilder(context, _min, _max),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _TimeAxisLabels(
          min: _min,
          max: _max,
          count: widget.count,
          labelOf: widget.labelOf,
          plotWidthOf: (width) =>
              math.max(1, width - kBiMoneyAxisReserved - widget.rightPadding),
        ),
        SizedBox(
          height: 36,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _zoomed
                ? TextButton.icon(
                    key: const ValueKey('bi-zoom-reset'),
                    onPressed: reset,
                    icon: const Icon(Icons.zoom_out_map_rounded, size: 16),
                    label: const Text('Restablecer vista'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.cyanDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// Etiquetas del eje del tiempo: unas 5 a la vez sea cual sea el zoom, cada una
// pegada a su intervalo.
class _TimeAxisLabels extends StatelessWidget {
  final double min;
  final double max;
  final int count;
  final String Function(int index) labelOf;
  final double Function(double width) plotWidthOf;

  const _TimeAxisLabels({
    required this.min,
    required this.max,
    required this.count,
    required this.labelOf,
    required this.plotWidthOf,
  });

  static const double _labelWidth = 48;

  @override
  Widget build(BuildContext context) {
    final visibleCount = ((max - min) + 1).round();
    final every = math.max(1, (visibleCount / 5).ceil());
    final first = (min - 1e-6).ceil();
    final last = math.min((max + 1e-6).floor(), count - 1);

    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plot = plotWidthOf(constraints.maxWidth);
          final span = max - min;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = math.max(0, first); i <= last; i++)
                if (i % every == 0)
                  Positioned(
                    left:
                        kBiMoneyAxisReserved +
                        (i - min) / (span <= 0 ? 1 : span) * plot -
                        _labelWidth / 2,
                    top: AppSpacing.s6,
                    width: _labelWidth,
                    child: Text(
                      labelOf(i),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
