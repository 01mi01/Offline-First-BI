import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'ios_style.dart';

// Pantalla con título grande que se encoge a un título pequeño centrado al
// desplazarse. [backLabel] muestra la flecha de volver con el nombre de la
// pantalla anterior; sin él no hay botón de volver.
class IosLargeTitleScaffold extends StatelessWidget {
  final String title;
  final String? backLabel;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? floatingActionButton;

  const IosLargeTitleScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.backLabel,
    this.actions = const [],
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _LargeTitleDelegate(
              title: title,
              backLabel: backLabel,
              actions: actions,
              topPadding: MediaQuery.paddingOf(context).top,
            ),
          ),
          ...slivers,
        ],
      ),
    );
  }
}

class _LargeTitleDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final String? backLabel;
  final List<Widget> actions;
  final double topPadding;

  _LargeTitleDelegate({
    required this.title,
    required this.backLabel,
    required this.actions,
    required this.topPadding,
  });

  @override
  double get minExtent => topPadding + AppIos.navBarHeight;

  @override
  double get maxExtent =>
      topPadding + AppIos.navBarHeight + AppIos.largeTitleExtent;

  @override
  bool shouldRebuild(_LargeTitleDelegate old) =>
      old.title != title ||
      old.backLabel != backLabel ||
      old.topPadding != topPadding ||
      old.actions != actions;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / AppIos.largeTitleExtent).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
    final canPop = backLabel != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.iosSeparator.withValues(alpha: collapsedTitleOpacity),
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: topPadding,
            height: AppIos.navBarHeight,
            child: Row(
              children: [
                if (canPop)
                  _BackButton(label: backLabel!)
                else
                  const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Opacity(
                    opacity: collapsedTitleOpacity,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IosText.navTitle(context),
                    ),
                  ),
                ),
                ...actions,
                if (actions.isEmpty) const SizedBox(width: AppSpacing.s16),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.s16,
            right: AppSpacing.s16,
            bottom: AppSpacing.s8,
            child: Opacity(
              opacity: 1 - t,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IosText.largeTitle(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final String label;

  const _BackButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.maybePop(context),
      child: SizedBox(
        height: AppIos.navBarHeight,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.s8,
            right: AppSpacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chevron_left_rounded,
                size: 32,
                color: AppColors.primaryDark,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  label,
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
