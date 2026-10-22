import 'dart:async';

import 'package:flutter/material.dart';
import '../../application/record_search.dart';
import '../../theme/app_theme.dart';
import 'form_widgets.dart';
import 'focus_utils.dart';
import 'app_controls.dart';
import 'app_style.dart';
import 'empty_state.dart';

class PickerOption<T> {
  final T? value;
  final String label;
  final String? subtitle;
  final String? selectedLabel;
  final String? searchText;

  const PickerOption(
    this.value,
    this.label, {
    this.subtitle,
    this.selectedLabel,
    this.searchText,
  });
}

class SearchablePickerField<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<PickerOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String searchHint;

  final Widget? labelAction;

  final bool searchStyle;

  final bool showLabel;

  final ValueChanged<bool>? onFocusChanged;

  const SearchablePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.searchHint = 'Buscar',
    this.labelAction,
    this.searchStyle = false,
    this.showLabel = true,
    this.onFocusChanged,
  });

  @override
  State<SearchablePickerField<T>> createState() =>
      _SearchablePickerFieldState<T>();
}

class _SearchablePickerFieldState<T> extends State<SearchablePickerField<T>>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _revealTimer;
  SearchIndex<PickerOption<T>>? _index;
  List<PickerOption<T>>? _indexSource;

  SearchIndex<PickerOption<T>> get _optionIndex {
    if (_index == null || !identical(_indexSource, widget.options)) {
      _indexSource = widget.options;
      _index = SearchIndex(
        widget.options,
        (o) => '${o.label} ${o.subtitle ?? ''} ${o.searchText ?? ''}',
      );
    }
    return _index!;
  }

  String get _selectedLabel {
    for (final option in widget.options) {
      if (option.value == widget.value) return option.selectedLabel ?? option.label;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _controller.text = _selectedLabel;
    _focus.addListener(_onFocusChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(SearchablePickerField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focus.hasFocus) return;
      final label = _selectedLabel;
      if (_controller.text != label) _controller.text = label;
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() => _reveal();

  void _onFocusChange() {
    widget.onFocusChanged?.call(_focus.hasFocus);
    if (_focus.hasFocus) {
      _controller.clear();
      setState(() {});
      _reveal();
    } else {
      _controller.text = _selectedLabel;
      setState(() {});
    }
  }

  void _reveal() {
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_focus.hasFocus) return;
      revealFieldAtTop(context);
    });
  }

  InputDecoration _decoration(
    BuildContext context,
    String? labelText,
    bool focused,
    String query,
  ) {
    final clear = focused && query.isNotEmpty
        ? IconButton(
            tooltip: 'Borrar búsqueda',
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
            onPressed: () {
              _controller.clear();
              setState(() {});
            },
          )
        : null;
    if (widget.searchStyle) {
      return appSearchDecoration(
        context,
        hintText: widget.searchHint,
        labelText: labelText,
        suffixIcon: clear,
      );
    }
    return InputDecoration(
      labelText: labelText,
      hintText: widget.searchHint,
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: AppColors.textSecondary,
        size: 20,
      ),
      suffixIcon: clear,
    );
  }

  Widget _sized(Widget field) => widget.searchStyle
      ? SizedBox(height: AppMetrics.controlHeight, child: field)
      : field;

  void _choose(PickerOption<T> option) {
    _controller.text = option.selectedLabel ?? option.label;
    widget.onChanged(option.value);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final query = _controller.text;
    final hasQuery = focused && query.trim().isNotEmpty;
    final visible = hasQuery
        ? _optionIndex.search(query)
        : widget.options.where((o) => o.value == null).toList();

    final view = View.of(context);
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final resultsHeight = (screenHeight * 0.25).clamp(120.0, 200.0);

    return TextFieldTapRegion(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: widget.label,
            inset: widget.searchStyle ? 0 : AppSpacing.s4,
            hidden: !widget.showLabel,
            action: widget.labelAction,
            builder: (labelText) => _sized(TextField(
            controller: _controller,
            focusNode: _focus,
            onTapOutside: (_) => _focus.unfocus(),
            textInputAction: TextInputAction.search,
            scrollPadding: EdgeInsets.zero,
            onChanged: (_) => setState(() {}),
            decoration: _decoration(context, labelText, focused, query),
          ))),
          if (focused) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              height: resultsHeight,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: _results(context, visible, hasQuery),
            ),
          ],
        ],
      ),
    );
  }

  Widget _results(
    BuildContext context,
    List<PickerOption<T>> visible,
    bool hasQuery,
  ) {
    final empty = hasQuery
        ? const AppEmptyState.noMatch(compact: true)
        : const AppEmptyState.hint(
            key: ValueKey('picker-type-to-search'),
            icon: Icons.search_rounded,
            text: 'Escribe para buscar.',
            compact: true,
          );
    if (visible.isEmpty) return empty;
    final tiles = [for (final option in visible) _buildTile(context, option)];
    if (hasQuery) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.s8),
        children: tiles,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s8),
      child: Column(children: [...tiles, Expanded(child: empty)]),
    );
  }

  Widget _buildTile(BuildContext context, PickerOption<T> option) {
    final isSelected = option.value == widget.value;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      title: Text(
        option.label,
        style: AppText.rowSubtitle(context, color: AppColors.textPrimary)
            .copyWith(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: option.subtitle == null
          ? null
          : Text(option.subtitle!, style: AppText.footnote(context)),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.cyanDark)
          : null,
      onTap: () => _choose(option),
    );
  }
}
