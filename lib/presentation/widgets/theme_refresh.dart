import 'package:flutter/widgets.dart';
import '../../theme/app_theme.dart';

void applyActivePalette(BuildContext context, {required bool dark}) {
  if (AppColors.isDark == dark) return;
  AppColors.useDark(dark);
  void markForRebuild(Element element) {
    element.markNeedsBuild();
    element.visitChildren(markForRebuild);
  }

  (context as Element).visitChildren(markForRebuild);
}
