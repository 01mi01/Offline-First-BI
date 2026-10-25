import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';

class AppSegment<T> {
  final T value;
  final String label;

  const AppSegment(this.value, this.label);
}

class AppSegmented<T> extends StatelessWidget {
  final List<AppSegment<T>> segments;
  final T? selected;
  final ValueChanged<T> onChanged;
  final bool expand;

  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppMiniToggle<T>(
      segments: segments,
      selected: selected,
      onChanged: onChanged,
      expand: expand,
    );
  }
}

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
          onChanged: controller.animateTo,
        ),
      ),
    );
  }
}

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

TextStyle appControlTextStyle(BuildContext context, Color color) =>
    AppText.rowSubtitle(context, color: color).copyWith(
      fontSize: AppMetrics.controlTextSize,
      fontWeight: FontWeight.w500,
    );

InputDecoration appSearchDecoration(
  BuildContext context, {
  required String hintText,
  String? labelText,
  Widget? suffixIcon,
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
    contentPadding: EdgeInsets.zero,
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

class AppSearchBar extends StatefulWidget {
  final String initialText;
  final String hintText;
  final ValueChanged<String> onChanged;
  const AppSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.initialText = '',
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

class AppStepper extends StatelessWidget {
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final Key? minusKey;
  final Key? plusKey;

  const AppStepper({
    super.key,
    required this.onMinus,
    required this.onPlus,
    this.minusKey,
    this.plusKey,
  });

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
                key: minusKey,
                icon: Icons.remove_rounded,
                tooltip: 'Quitar uno',
                onTap: onMinus,
              ),
              Container(width: 1, height: 16, color: AppColors.separator),
              _StepperButton(
                key: plusKey,
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
    super.key,
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
          width: 40,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? AppColors.chevron : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class AppRoundCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppRoundCheck({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      checked: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: AppMetrics.minTap,
          height: AppMetrics.minTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? AppColors.cyanDeep : Colors.transparent,
                border: Border.all(
                  color: value ? AppColors.cyanDeep : AppColors.textMuted,
                  width: 1.5,
                ),
              ),
              child: value
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.onDark.withValues(alpha: 0.92),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class AppMiniToggle<T> extends StatelessWidget {
  final List<AppSegment<T>> segments;
  final T? selected;
  final ValueChanged<T> onChanged;
  final bool expand;

  const AppMiniToggle({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final count = segments.length;
    final index = segments.indexWhere((s) => s.value == selected);
    final alignX = count <= 1 || index < 0 ? -1.0 : -1 + 2 * index / (count - 1);

    return SizedBox(
      height: AppMetrics.minTap,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: expand ? double.infinity : null,
          height: 36,
          padding: const EdgeInsets.all(AppSpacing.s2),
          decoration: BoxDecoration(
            color: AppColors.track,
            borderRadius: BorderRadius.circular(AppMetrics.controlRadius),
          ),
          child: IntrinsicWidth(
            child: Stack(
              children: [
                Positioned.fill(
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
                            borderRadius: BorderRadius.circular(
                              AppMetrics.thumbRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final segment in segments)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (segment.value != selected) {
                              onChanged(segment.value);
                            }
                          },
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 80),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                            ),
                            alignment: Alignment.center,
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
                                  fontSize: 15,
                                  fontWeight: segment.value == selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
