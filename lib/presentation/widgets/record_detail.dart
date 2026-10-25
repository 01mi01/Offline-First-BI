import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_buttons.dart';
import 'app_sheet.dart';
import 'app_style.dart';

class RecordDetailSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback? onEdit;

  const RecordDetailSheet({
    super.key,
    required this.title,
    required this.children,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: title,
      expand: false,
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onEdit != null) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onEdit!();
              },
              child: const Text('Editar'),
            ),
            const SizedBox(height: AppButtons.stackGap),
          ],
          AppActionButton(
            label: 'Cerrar',
            kind: AppButtonKind.neutral,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(
          top: AppSpacing.s8,
          bottom: AppSpacing.s16,
        ),
        children: children,
      ),
    );
  }
}

class RecordHeadline extends StatelessWidget {
  final String title;
  final Widget? thumb;
  final Widget? pill;
  final String? note;

  const RecordHeadline({
    super.key,
    required this.title,
    this.thumb,
    this.pill,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s24,
      ),
      child: Column(
        children: [
          if (thumb != null) ...[thumb!, const SizedBox(height: AppSpacing.s12)],
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.largeTitle(context).copyWith(fontSize: AppMetrics.titleMediumSize),
          ),
          if (pill != null) ...[
            const SizedBox(height: AppSpacing.s8),
            pill!,
          ],
          if (note != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              note!,
              textAlign: TextAlign.center,
              style: AppText.rowSubtitle(context),
            ),
          ],
        ],
      ),
    );
  }
}
