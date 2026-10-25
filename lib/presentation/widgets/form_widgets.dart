import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_buttons.dart';
import 'record_list.dart' show imagePlaceholderColor;
import 'app_style.dart';
import 'form_style.dart';

class LabeledField extends StatelessWidget {
  final String label;
  final Widget Function(String? labelText) builder;
  final double inset;
  final bool hidden;
  final Widget? action;

  const LabeledField({
    super.key,
    required this.label,
    required this.builder,
    this.inset = AppSpacing.s4,
    this.hidden = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    if (hidden) return builder(null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormSectionLabel(
          label,
          action: action,
          inset: math.max(0.0, inset),
        ),
        SizedBox(height: action == null ? AppSpacing.s6 : 0),
        builder(null),
      ],
    );
  }
}

const double _actionRowHeight = AppMetrics.presetHeight;

class FormSectionLabel extends StatelessWidget {
  final String text;
  final Widget? action;
  final double inset;

  const FormSectionLabel(
    this.text, {
    super.key,
    this.action,
    this.inset = AppSpacing.s4,
  });

  @override
  Widget build(BuildContext context) {
    final label = Padding(
      padding: EdgeInsets.only(left: inset),
      child: Text(
        text,
        style: AppFormTheme.isActive(context)
            ? AppText.formLabel(context)
            : Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
      ),
    );
    if (action == null) return label;
    return SizedBox(
      height: _actionRowHeight,
      child: Row(
        children: [
          Expanded(child: label),
          action!,
        ],
      ),
    );
  }
}

class FormAddButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const FormAddButton({
    super.key,
    required this.onPressed,
    this.label = 'Agregar',
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: AppIconSize.s18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.cyanDark,
        minimumSize: const Size(AppMetrics.minTap, _actionRowHeight),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: AppText.formLabel(context),
      ),
    );
  }
}

class AppDateField extends StatelessWidget {
  final String label;
  final String? valueText;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? errorText;

  const AppDateField({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.hint = 'Seleccionar',
    this.onClear,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final text = valueText;
    return LabeledField(
      label: label,
      builder: (_) => InkWell(
        borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
        onTap: onTap,
        child: InputDecorator(
          isEmpty: text == null,
          baseStyle: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.cyanDark,
              size: AppIconSize.s20,
            ),
            suffixIcon: text != null && onClear != null
                ? IconButton(
                    tooltip: 'Quitar fecha',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: AppIconSize.s18,
                    ),
                    onPressed: onClear,
                  )
                : null,
          ),
          child: Text(text ?? ''),
        ),
      ),
    );
  }
}

class DropdownOption<T> {
  final T? value;
  final String label;

  const DropdownOption(this.value, this.label);
}

class AppDropdownField<T> extends FormField<T> {
  AppDropdownField({
    super.key,
    required String label,
    required T? value,
    required List<DropdownOption<T>> options,
    required ValueChanged<T?>? onChanged,
    super.validator,
    String? helperText,
    String? hint,
  }) : super(
         initialValue: value,
         autovalidateMode: AutovalidateMode.onUserInteraction,
         builder: (state) {
           final selected = options
               .where((o) => o.value == state.value)
               .firstOrNull;
           return LabeledField(
             label: label,
             builder: (_) => LayoutBuilder(
               builder: (context, constraints) => PopupMenuButton<int>(
                 enabled: onChanged != null,
                 tooltip: label,
                 position: PopupMenuPosition.under,
                 constraints: BoxConstraints(
                   minWidth: constraints.maxWidth,
                   maxWidth: constraints.maxWidth,
                   maxHeight: AppMetrics.menuMaxHeight,
                 ),
                 color: AppColors.surface,
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
                 ),
                 onSelected: (i) {
                   state.didChange(options[i].value);
                   onChanged?.call(options[i].value);
                 },
                 itemBuilder: (context) => [
                   for (var i = 0; i < options.length; i++)
                     CheckedPopupMenuItem<int>(
                       value: i,
                       checked: options[i].value == state.value,
                       child: Text(options[i].label),
                     ),
                 ],
                 child: InputDecorator(
                   isEmpty: selected == null,
                   baseStyle: Theme.of(
                     context,
                   ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
                   decoration: InputDecoration(
                     hintText: hint,
                     helperText: helperText,
                     errorText: state.errorText,
                     suffixIcon: const Icon(
                       Icons.unfold_more_rounded,
                       color: AppColors.textSecondary,
                     ),
                   ),
                   child: Text(
                     selected?.label ?? '',
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                     style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                       color: AppColors.textPrimary,
                     ),
                   ),
                 ),
               ),
             ),
           );
         },
       );
}

class FormActions extends StatelessWidget {
  final VoidCallback onSecondary;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool loading;
  final bool busy;
  final Widget? destructive;

  const FormActions({
    super.key,
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
    this.loading = false,
    this.busy = false,
    this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: loading || busy ? null : onPrimary,
          child: loading
              ? const SizedBox(
                  height: AppSpacing.s20,
                  width: AppSpacing.s20,
                  child: CircularProgressIndicator(
                    color: AppColors.onDark,
                    strokeWidth: AppStroke.medium,
                  ),
                )
              : Text(primaryLabel, maxLines: 1),
        ),
        if (destructive != null) ...[
          const SizedBox(height: AppButtons.stackGap),
          destructive!,
        ],
        const SizedBox(height: AppButtons.stackGap),
        AppActionButton(
          label: 'Volver',
          kind: AppButtonKind.neutral,
          onPressed: onSecondary,
        ),
      ],
    );
  }
}

class AppToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.rowTitle(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                Text(subtitle, style: AppText.footnote(context)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.cyanDark,
            inactiveTrackColor: AppColors.border,
            inactiveThumbColor: AppColors.surface,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class AppPhotoSlot extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onTap;

  const AppPhotoSlot({super.key, required this.imagePath, required this.onTap});

  static const double size = AppExtent.e100;

  Widget _placeholder() => Container(
    width: size,
    height: size,
    color: imagePlaceholderColor,
    child: const Icon(
      Icons.add_a_photo_rounded,
      color: AppColors.cyanDark,
      size: AppIconSize.s32,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppFlat.tileRadius),
          child: imagePath != null
              ? Image.file(
                  File(imagePath!),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
    );
  }
}
