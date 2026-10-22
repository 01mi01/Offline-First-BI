import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_style.dart';
import 'form_sheet_route.dart';
import 'form_style.dart';

WidgetBuilder _sheetBuilder(
  MediaQueryData media,
  double maxHeight,
  WidgetBuilder builder,
  double? heightFactor,
) {
  return (ctx) {
    final inset = MediaQuery.of(ctx).viewInsets.bottom;
    final child = AppFormTheme(child: builder(ctx));
    if (heightFactor == null) {
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: child,
      );
    }
    final height = math.min(
      media.size.height * heightFactor,
      maxHeight - inset,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(height: height, child: child),
    );
  };
}

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(
    top: Radius.circular(AppMetrics.sheetRadius),
  ),
);

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
}) {
  final media = MediaQuery.of(context);
  final maxHeight = media.size.height - media.padding.top - AppMetrics.sheetTopGap;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: AppColors.background,
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(maxHeight: maxHeight),
    shape: _sheetShape,
    builder: _sheetBuilder(media, maxHeight, builder, heightFactor),
  );
}

Future<T?> showFormSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
}) {
  final media = MediaQuery.of(context);
  final maxHeight = media.size.height - media.padding.top - AppMetrics.sheetTopGap;
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push(
    FormSheetRoute<T>(
      builder: _sheetBuilder(media, maxHeight, builder, heightFactor),
      capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(localizations.bottomSheetLabel),
      backgroundColor: AppColors.background,
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(maxHeight: maxHeight),
      shape: _sheetShape,
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      isScrollControlled: true,
      useSafeArea: true,
    ),
  );
}

class AppSheetScaffold extends StatelessWidget {
  final String title;
  final Key? titleKey;
  final Widget child;
  final Widget? actions;
  final bool expand;

  const AppSheetScaffold({
    super.key,
    required this.title,
    this.titleKey,
    required this.child,
    this.actions,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = expand ? Expanded(child: child) : Flexible(child: child);
    return Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        SizedBox(
          height: AppMetrics.minTap + AppSpacing.s8,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.s8,
              left: AppSpacing.s16,
              right: AppSpacing.s16,
            ),
            child: Center(
              child: Text(
                title,
                key: titleKey,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.navTitle(context),
              ),
            ),
          ),
        ),
        body,
        if (actions != null) SheetActionBar(child: actions!),
      ],
    );
  }
}

class SheetActionBar extends StatelessWidget {
  final Widget child;

  const SheetActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.separator)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s16,
          AppSpacing.s16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: child,
      ),
    );
  }
}

class FormSheet extends StatelessWidget {
  final String title;
  final GlobalKey<FormState>? formKey;
  final List<Widget> children;
  final Widget? actions;

  const FormSheet({
    super.key,
    required this.title,
    required this.children,
    this.formKey,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: title,
      expand: false,
      child: Form(
        key: formKey,
        child: FormScroll(
          children: [
            ...children,
            if (actions != null) ...[
              const SizedBox(height: AppSpacing.s24),
              actions!,
            ],
          ],
        ),
      ),
    );
  }
}

class FormScroll extends StatelessWidget {
  final List<Widget> children;

  const FormScroll({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s32 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
