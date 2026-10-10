import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Estilos de texto de las listas agrupadas y las hojas.
class AppText {
  static TextStyle _base(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge ?? const TextStyle();

  static TextStyle rowTitle(BuildContext context, {Color? color}) =>
      _base(context).copyWith(
        fontSize: AppMetrics.rowTitleSize,
        color: color ?? AppColors.textPrimary,
        height: 1.25,
      );

  static TextStyle rowSubtitle(BuildContext context, {Color? color}) =>
      _base(context).copyWith(
        fontSize: AppMetrics.rowSubtitleSize,
        color: color ?? AppColors.textSecondary,
        height: 1.25,
      );

  static TextStyle header(BuildContext context) => _base(context).copyWith(
    fontSize: AppMetrics.headerSize,
    color: AppColors.textSecondary,
  );

  static TextStyle footnote(BuildContext context) => header(context);

  static TextStyle link(BuildContext context) => _base(context).copyWith(
    fontSize: AppMetrics.rowTitleSize,
    color: AppColors.cyanDark,
  );

  static TextStyle navTitle(BuildContext context) => _base(context).copyWith(
    fontSize: AppMetrics.navTitleSize,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle largeTitle(BuildContext context) => _base(context).copyWith(
    fontSize: AppMetrics.largeTitleSize,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle error(BuildContext context) => _base(context).copyWith(
    fontSize: AppMetrics.headerSize,
    color: AppColors.error,
  );
}

// Campo de texto sin borde ni relleno, para dentro de una fila de formulario.
InputDecoration appFieldDecoration(
  BuildContext context, {
  String? hint,
  String? helper,
  Widget? suffix,
}) {
  const none = InputBorder.none;
  return InputDecoration(
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    errorMaxLines: 3,
    isDense: true,
    filled: false,
    fillColor: Colors.transparent,
    border: none,
    enabledBorder: none,
    focusedBorder: none,
    errorBorder: none,
    focusedErrorBorder: none,
    disabledBorder: none,
    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
    hintStyle: AppText.rowTitle(context, color: AppColors.textSecondary),
    helperStyle: AppText.footnote(context),
    errorStyle: AppText.error(context),
    suffixIcon: suffix,
  );
}

class AppChevron extends StatelessWidget {
  const AppChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.chevron_right_rounded,
      size: 22,
      color: AppColors.chevron,
    );
  }
}
