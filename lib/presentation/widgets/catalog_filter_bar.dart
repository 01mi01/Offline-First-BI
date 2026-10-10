import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_controls.dart';
import 'focus_utils.dart';
import '../../application/date_range_filter.dart' show RecordTimeFilter;

// Piezas reutilizables para filtrar las listas y el catálogo.

// Envuelve un buscador con resultados debajo (p. ej. el de productos dentro del
// formulario de venta): al enfocarlo, lleva el buscador al borde de arriba del
// área que se desplaza, para que lo escrito quede por encima del teclado y los
// resultados se vean debajo. Solo actúa al enfocar y cuando el teclado termina
// de abrirse; escribir no vuelve a mover la pantalla.
class RevealOnFocus extends StatefulWidget {
  final Widget child;

  const RevealOnFocus({super.key, required this.child});

  @override
  State<RevealOnFocus> createState() => _RevealOnFocusState();
}

class _RevealOnFocusState extends State<RevealOnFocus>
    with WidgetsBindingObserver {
  bool _focused = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _reveal();

  // Se espera un instante para que el propio campo de texto (que también se
  // desplaza para mostrar el cursor) termine primero y no se pisen.
  void _reveal() {
    if (!_focused) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_focused) return;
      revealFieldAtTop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        _focused = hasFocus;
        _reveal();
      },
      child: widget.child,
    );
  }
}

// Selector de "registros actuales / todos" para listas con registros futuros,
// con el mismo control y lugar que el selector de pestañas.
class RecordTimeSwitcher extends StatelessWidget {
  final RecordTimeFilter value;
  final String currentLabel;
  final ValueChanged<RecordTimeFilter> onChanged;

  const RecordTimeSwitcher({
    super.key,
    required this.value,
    required this.currentLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppHeader.sidePadding),
      child: AppSegmented<RecordTimeFilter>(
        segments: [
          AppSegment(RecordTimeFilter.current, currentLabel),
          const AppSegment(RecordTimeFilter.all, 'Todas'),
        ],
        selected: value,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
