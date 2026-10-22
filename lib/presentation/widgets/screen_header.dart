import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_sheet.dart' show SheetActionBar;
import 'app_style.dart';

TextStyle? screenTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.bold,
      height: AppHeader.titleLineHeight,
      color: AppColors.textPrimary,
    );

class ScreenTopBar extends StatelessWidget {
  final bool? showBack;
  final List<Widget> actions;
  final VoidCallback? onBack;

  const ScreenTopBar({
    super.key,
    this.showBack,
    this.actions = const [],
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final back = showBack ?? Navigator.canPop(context);

    return Container(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppHeader.rowHeight,
          child: Row(
            children: [
              if (back) _BackButton(onTap: onBack),
              const Spacer(),
              IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    iconSize: AppHeader.iconSize,
                    minimumSize: const Size(48, 48),
                  ),
                ),
                child: Row(children: actions),
              ),
              const SizedBox(width: AppHeader.actionsEndPadding),
            ],
          ),
        ),
      ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  final String title;
  final double horizontal;

  const ScreenTitle(
    this.title, {
    super.key,
    this.horizontal = AppHeader.sidePadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        AppHeader.titleTopPadding,
        horizontal,
        AppHeader.titleBottomPadding,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: screenTitleStyle(context),
        ),
      ),
    );
  }
}

class ScreenScaffold extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final bool? showBack;
  final Widget? body;
  final List<Widget>? slivers;
  final Widget? bottom;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final VoidCallback? onBack;

  const ScreenScaffold({
    super.key,
    required this.title,
    required Widget this.body,
    this.actions = const [],
    this.showBack,
    this.bottom,
    this.bottomBar,
    this.onBack,
  }) : slivers = null,
       floatingActionButton = null;

  const ScreenScaffold.slivers({
    super.key,
    required this.title,
    required List<Widget> this.slivers,
    this.actions = const [],
    this.floatingActionButton,
  }) : body = null,
       bottom = null,
       showBack = null,
       bottomBar = null,
       onBack = null;

  @override
  Widget build(BuildContext context) {
    final content = slivers != null
        ? CustomScrollView(
            slivers: [SliverToBoxAdapter(child: ScreenTitle(title)), ...slivers!],
          )
        : NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [ScreenTitle(title), ?bottom],
                ),
              ),
            ],
            body: body!,
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          ScreenTopBar(showBack: showBack, actions: actions, onBack: onBack),
          Expanded(child: content),
          if (bottomBar != null && MediaQuery.viewInsetsOf(context).bottom == 0)
            SheetActionBar(child: bottomBar!),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _BackButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => Navigator.maybePop(context),
      child: SizedBox(
        height: AppHeader.rowHeight,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppHeader.backStartPadding,
            right: AppSpacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chevron_left_rounded,
                size: AppHeader.backIconSize,
                color: AppColors.cyanDark,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppHeader.backLabelMaxWidth,
                ),
                child: Text(
                  'Atrás',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.link(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
