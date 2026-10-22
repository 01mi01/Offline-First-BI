import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

OutlineInputBorder appInputBorder(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
      borderSide: BorderSide(color: color, width: width),
    );

InputDecorationTheme appInputDecorationTheme(BuildContext context) {
  final enabled = appInputBorder(AppColors.border);
  final focused = appInputBorder(AppColors.cyanDark, 2);
  final textTheme = Theme.of(context).textTheme;
  return InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.s16,
      vertical: AppSpacing.s14,
    ),
    border: enabled,
    enabledBorder: enabled,
    disabledBorder: enabled,
    errorBorder: enabled,
    hintStyle: const TextStyle(color: AppColors.textMuted),
    focusedBorder: focused,
    focusedErrorBorder: focused,
    errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.error),
    errorMaxLines: 3,
    helperMaxLines: 3,
    helperStyle: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
  );
}

class AppFormTheme extends StatelessWidget {
  final Widget child;

  const AppFormTheme({super.key, required this.child});

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FormScope>() != null;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return _FormScope(
      child: Theme(
        data: base.copyWith(
          inputDecorationTheme: appInputDecorationTheme(context),
          textTheme: base.textTheme.copyWith(
            bodyLarge: base.textTheme.bodyLarge?.copyWith(
              fontSize: AppMetrics.formTextSize,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _FormScope extends InheritedWidget {
  const _FormScope({required super.child});

  @override
  bool updateShouldNotify(_FormScope oldWidget) => false;
}

class FormErrorText extends StatelessWidget {
  final String message;

  const FormErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.s20,
        right: AppSpacing.s16,
        top: AppSpacing.s6,
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}
