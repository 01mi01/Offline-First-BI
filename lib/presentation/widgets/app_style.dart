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

  // Etiqueta de un campo o de una sección de un formulario o de un detalle.
  static TextStyle formLabel(BuildContext context) => _base(context).copyWith(
    fontSize: AppMetrics.formLabelSize,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

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

class AppSectionTitle extends StatelessWidget {
  final String title;

  const AppSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}
