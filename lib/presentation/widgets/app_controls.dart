import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';

class AppSegment<T> {
  final T value;
  final String label;

  const AppSegment(this.value, this.label);
}

// Control segmentado: pista a todo el ancho con una pastilla que se desliza a
// la opción elegida. Con [allowDeselect], tocar la opción activa la quita
// (onChanged recibe null).
class AppSegmented<T> extends StatelessWidget {
  final List<AppSegment<T>> segments;
  final T? selected;
  final ValueChanged<T?> onChanged;
  final bool allowDeselect;

  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.allowDeselect = false,
  });

  @override
  Widget build(BuildContext context) {
    final count = segments.length;
    final index = segments.indexWhere((s) => s.value == selected);
    final alignX = count <= 1 || index < 0 ? -1.0 : -1 + 2 * index / (count - 1);

    return SizedBox(
      height: AppMetrics.minTap,
      child: Stack(
        children: [
          Center(
            child: Container(
              height: AppMetrics.segmentedHeight,
              padding: const EdgeInsets.all(AppSpacing.s2),
              decoration: BoxDecoration(
                color: AppColors.track,
                borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment(alignX, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: index < 0 ? 0 : 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppMetrics.thumbRadius),
                        boxShadow: AppShadows.thumb,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
              child: Row(
                children: [
                  for (final segment in segments)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (segment.value == selected) {
                            if (allowDeselect) onChanged(null);
                            return;
                          }
                          onChanged(segment.value);
                        },
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s4,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                segment.label,
                                maxLines: 1,
                                style: AppText.rowSubtitle(
                                  context,
                                  color: segment.value == selected
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ).copyWith(
                                  fontSize: AppMetrics.headerSize + 1,
                                  fontWeight: segment.value == selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Selector de pestañas: el control segmentado conectado al TabController del
// DefaultTabController más cercano, con el mismo lugar y relleno en cada pantalla.
class AppTabSwitcher extends StatelessWidget {
  final List<String> labels;

  const AppTabSwitcher({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppHeader.sidePadding),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => AppSegmented<int>(
          segments: [
            for (var i = 0; i < labels.length; i++) AppSegment(i, labels[i]),
          ],
          selected: controller.index,
          onChanged: (i) {
            if (i != null) controller.animateTo(i);
          },
        ),
      ),
    );
  }
}

// Texto de los controles de filtro (chips, atajos, interruptor, fechas y
// botones): un solo tamaño. El nombre va regular y gris; el valor, en negrita.
TextStyle filterNameStyle(BuildContext context) => AppText.rowSubtitle(
  context,
  color: AppColors.textSecondary,
).copyWith(fontSize: AppMetrics.filterTextSize);

TextStyle filterLabelStyle(BuildContext context) => AppText.rowSubtitle(
  context,
  color: AppColors.textSecondary,
).copyWith(fontSize: AppMetrics.filterLabelSize);

TextStyle filterValueStyle(BuildContext context, {bool active = false}) =>
    AppText.rowSubtitle(
      context,
      color: active ? AppColors.cyanDark : AppColors.textSecondary,
    ).copyWith(
      fontSize: AppMetrics.filterTextSize,
      fontWeight: FontWeight.bold,
    );

// Texto del buscador.
TextStyle appControlTextStyle(BuildContext context, Color color) =>
    AppText.rowSubtitle(context, color: color).copyWith(
      fontSize: AppMetrics.controlTextSize,
      fontWeight: FontWeight.w500,
    );

// Aspecto de todos los campos de búsqueda: relleno gris, esquinas como las de
// los botones y lupa.
InputDecoration appSearchDecoration(
  BuildContext context, {
  required String hintText,
  String? labelText,
  Widget? suffixIcon,
  EdgeInsetsGeometry contentPadding = EdgeInsets.zero,
}) {
  OutlineInputBorder border() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    hintStyle: appControlTextStyle(context, AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.track,
    isDense: true,
    contentPadding: contentPadding,
    border: border(),
    enabledBorder: border(),
    focusedBorder: border(),
    prefixIcon: const Icon(
      Icons.search_rounded,
      size: 20,
      color: AppColors.textSecondary,
    ),
    suffixIcon: suffixIcon,
  );
}

// Barra de búsqueda: campo gris con lupa y botón para borrar.
class AppSearchBar extends StatefulWidget {
  final String initialText;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  const AppSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.initialText = '',
    this.autofocus = false,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppMetrics.controlHeight,
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        scrollPadding: EdgeInsets.zero,
        style: appControlTextStyle(context, AppColors.textPrimary),
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value);
        },
        decoration: appSearchDecoration(
          context,
          hintText: widget.hintText,
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                    widget.onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

// Control de cantidad con menos y más.
class AppStepper extends StatelessWidget {
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const AppStepper({super.key, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppMetrics.minTap,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.track,
            borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepperButton(
                icon: Icons.remove_rounded,
                tooltip: 'Quitar uno',
                onTap: onMinus,
              ),
              Container(width: 1, height: 18, color: AppColors.separator),
              _StepperButton(
                icon: Icons.add_rounded,
                tooltip: 'Agregar uno',
                onTap: onPlus,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
        child: SizedBox(
          width: AppMetrics.minTap,
          height: AppMetrics.segmentedHeight,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? AppColors.chevron : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
