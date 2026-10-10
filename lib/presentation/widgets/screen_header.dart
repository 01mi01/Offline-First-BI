import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'ios_style.dart';

TextStyle? screenTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.bold,
      height: AppHeader.titleLineHeight,
      color: AppColors.textPrimary,
    );

// Fila fija de arriba: volver a la izquierda y acciones a la derecha.
class ScreenTopBar extends StatelessWidget {
  final bool? showBack;
  final List<Widget> actions;

  const ScreenTopBar({super.key, this.showBack, this.actions = const []});

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
              if (back) const _BackButton(),
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

// Pantalla con la cabecera común. [body] conserva su propio desplazamiento y el
// título sale con él; con [ScreenScaffold.slivers] el título va dentro de la lista.
class ScreenScaffold extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final bool? showBack;
  final Widget? body;
  final List<Widget>? slivers;
  final Widget? bottom;
  final Widget? floatingActionButton;

  const ScreenScaffold({
    super.key,
    required this.title,
    required Widget this.body,
    this.actions = const [],
    this.showBack,
    this.bottom,
    this.floatingActionButton,
  }) : slivers = null;

  const ScreenScaffold.slivers({
    super.key,
    required this.title,
    required List<Widget> this.slivers,
    this.actions = const [],
    this.showBack,
    this.floatingActionButton,
  }) : body = null,
       bottom = null;

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
          ScreenTopBar(showBack: showBack, actions: actions),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.maybePop(context),
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
                color: AppColors.primaryDark,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppHeader.backLabelMaxWidth,
                ),
                child: Text(
                  'Atrás',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IosText.link(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
