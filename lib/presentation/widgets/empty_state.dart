import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const AppEmptyState._({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  const AppEmptyState.hint({
    Key? key,
    required IconData icon,
    required String text,
    bool compact = false,
  }) : this._(key: key, icon: icon, text: text, compact: compact);

  factory AppEmptyState.list({
    Key? key,
    required String plural,
    required IconData icon,
    String adjective = 'registrados',
    String? actionLabel,
    VoidCallback? onAction,
    bool compact = false,
  }) => AppEmptyState._(
    key: key,
    icon: icon,
    text: 'No hay $plural $adjective.',
    actionLabel: actionLabel,
    onAction: onAction,
    compact: compact,
  );

  const AppEmptyState.noMatch({Key? key, bool compact = false})
    : this._(
        key: key,
        icon: Icons.search_off_rounded,
        text: 'No se encontraron resultados.',
        compact: compact,
      );

  factory AppEmptyState.noData({
    Key? key,
    required String what,
    required String period,
    bool compact = false,
  }) => AppEmptyState._(
    key: key,
    icon: Icons.bar_chart_rounded,
    text: 'No se registraron $what $period.',
    compact: compact,
  );

  @override
  Widget build(BuildContext context) {
    final padding = compact ? AppSpacing.s12 : AppSpacing.s32;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? AppIconSize.s32 : AppIconSize.s52, color: AppColors.chevron),
              SizedBox(height: compact ? AppSpacing.s8 : AppSpacing.s12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: AppText.rowSubtitle(context),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.s20),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(AppExtent.e200, AppMetrics.minTap),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
