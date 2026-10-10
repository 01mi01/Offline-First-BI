import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'ios_style.dart';

class IosSegment<T> {
  final T value;
  final String label;

  const IosSegment(this.value, this.label);
}

// Control segmentado: pista gris redondeada con una pastilla blanca que se
// desliza a la opción elegida. Con [allowDeselect], tocar la opción activa la
// quita (onChanged recibe null).
class IosSegmented<T> extends StatelessWidget {
  final List<IosSegment<T>> segments;
  final T? selected;
  final ValueChanged<T?> onChanged;
  final bool allowDeselect;

  const IosSegmented({
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
      height: AppIos.minTap,
      child: Stack(
        children: [
          Center(
            child: Container(
              height: AppIos.segmentedHeight,
              padding: const EdgeInsets.all(AppSpacing.s2),
              decoration: BoxDecoration(
                color: AppColors.iosTrack,
                borderRadius: BorderRadius.circular(AppIos.controlRadius),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
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
                        borderRadius: BorderRadius.circular(AppIos.thumbRadius),
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
                                style: IosText.rowSubtitle(
                                  context,
                                  color: AppColors.textPrimary,
                                ).copyWith(
                                  fontSize: AppIos.headerSize + 1,
                                  fontWeight: segment.value == selected
                                      ? FontWeight.w600
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

class IosMenuOption<T> {
  final T value;
  final String label;

  const IosMenuOption(this.value, this.label);
}

// Botón que abre un menú de opciones, con el valor elegido y flechas arriba y
// abajo.
class IosMenuButton<T> extends StatelessWidget {
  final String label;
  final bool active;
  final List<IosMenuOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const IosMenuButton({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppIos.groupRadius),
      ),
      onSelected: (i) => onSelected(options[i].value),
      itemBuilder: (context) => [
        for (var i = 0; i < options.length; i++)
          CheckedPopupMenuItem<int>(
            value: i,
            checked: options[i].value == selected,
            child: Text(options[i].label),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppIos.minTap),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            height: AppIos.segmentedHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.iosTrack,
              borderRadius: BorderRadius.circular(AppIos.controlRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IosText.rowSubtitle(
                    context,
                    color: active ? AppColors.primaryDark : AppColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: AppSpacing.s4),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: active ? AppColors.primaryDark : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Barra de búsqueda: campo gris redondeado con lupa y botón para borrar.
class IosSearchBar extends StatefulWidget {
  final String initialText;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  const IosSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.initialText = '',
    this.autofocus = false,
  });

  @override
  State<IosSearchBar> createState() => _IosSearchBarState();
}

class _IosSearchBarState extends State<IosSearchBar> {
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
      height: AppIos.searchHeight,
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        scrollPadding: EdgeInsets.zero,
        style: IosText.rowTitle(context),
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value);
        },
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: IosText.rowTitle(context, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.iosTrack,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppIos.controlRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppIos.controlRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppIos.controlRadius),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
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
class IosStepper extends StatelessWidget {
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const IosStepper({super.key, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppIos.minTap,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.iosTrack,
            borderRadius: BorderRadius.circular(AppIos.controlRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepperButton(
                icon: Icons.remove_rounded,
                tooltip: 'Quitar uno',
                onTap: onMinus,
              ),
              Container(width: 1, height: 18, color: AppColors.iosSeparator),
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
        borderRadius: BorderRadius.circular(AppIos.controlRadius),
        child: SizedBox(
          width: AppIos.minTap,
          height: AppIos.segmentedHeight,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? AppColors.iosChevron : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
