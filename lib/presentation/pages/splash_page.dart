import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';
import '../widgets/brand_assets.dart';

const Duration splashMinimumDuration = Duration(seconds: 2);

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: Center(
        child: SvgPicture.asset(
          splashAsset,
          width: AppSplash.imageWidth,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class SplashGate extends StatefulWidget {
  final bool loading;
  final Widget child;

  const SplashGate({super.key, required this.loading, required this.child});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _minimum = AnimationController(
    vsync: this,
    duration: splashMinimumDuration,
  );
  bool _firstFrameDeferred = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _minimum.addStatusListener((status) {
      if (status == AnimationStatus.completed && !widget.loading && !_done) {
        setState(() => _done = true);
      }
    });
    if (widget.loading) {
      WidgetsBinding.instance.deferFirstFrame();
      _firstFrameDeferred = true;
    } else {
      _minimum.forward();
    }
  }

  @override
  void didUpdateWidget(SplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_done || widget.loading) return;
    if (_firstFrameDeferred) {
      _allowFirstFrame();
      _minimum.forward();
    } else if (_minimum.isCompleted) {
      _done = true;
    }
  }

  void _allowFirstFrame() {
    if (!_firstFrameDeferred) return;
    _firstFrameDeferred = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  @override
  void dispose() {
    _allowFirstFrame();
    _minimum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _done ? widget.child : const SplashPage();
}
