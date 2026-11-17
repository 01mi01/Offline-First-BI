import '../../theme/app_theme.dart';

const String logoLightAsset = 'assets/images/logo_light.svg';
const String logoDarkAsset = 'assets/images/logo_dark.svg';
const String splashLightAsset = 'assets/images/splashscreen_light.svg';
const String splashDarkAsset = 'assets/images/splashscreen_dark.svg';

String get logoAsset => AppColors.isDark ? logoDarkAsset : logoLightAsset;

String get splashAsset => AppColors.isDark ? splashDarkAsset : splashLightAsset;
