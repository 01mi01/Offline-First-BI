import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_buttons.dart';
import 'app_sheet.dart';
import 'app_style.dart';

// Detalle de un registro (se abre al tocar una fila de cualquier lista): el
// contenido se desplaza y, fijos debajo, quedan "Editar" y "Cerrar". Sin
// [onEdit] (registro que no se puede editar) solo queda "Cerrar". Acciones como
// desactivar o cancelar viven únicamente en el formulario de edición.
//
// Se abre con [showAppSheet]; con [expand] ocupa todo el alto que le dé la hoja
// (úsese junto a `heightFactor`), y sin él mide lo que su contenido.
class RecordDetailSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback? onEdit;
  final bool expand;

  const RecordDetailSheet({
    super.key,
    required this.title,
    required this.children,
    this.onEdit,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      shrinkWrap: !expand,
      padding: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s16),
      children: children,
    );
    return AppSheetScaffold(
      title: title,
      expand: expand,
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (expand) Expanded(child: list) else Flexible(child: list),
          const Divider(height: 1, thickness: 1, color: AppColors.separator),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s16,
              AppSpacing.s16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
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
          ),
        ],
      ),
    );
  }
}

// Encabezado de un detalle: imagen (solo productos y categorías), nombre y la
// pastilla de estado, centrados.
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
            style: AppText.largeTitle(context).copyWith(fontSize: 24),
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
