import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLightColors {
  static const cyan = Color(0xFF06B1B9);
  static const cyanDark = Color(0xFF05959C);
  static const cyanSoft = Color(0xFFE1F6F7);
  static const navy = Color(0xFF112444);
  static const blue = Color(0xFF2C6E9B);

  static const background = Color(0xFFF3F2F7);
  static const surface = Color(0xFFFAFAFA);
  static const neutralButton = Color(0xFFE6E9EF);
  static const track = neutralButton;

  static const textPrimary = navy;
  static const textSecondary = Color(0xFF5B6B82);
  static const textSecondaryDark = Color(0xFF10314F);
  static const textMuted = Color(0xFF9AA6B8);

  static const onCyan = navy;
  static const onDark = Color(0xFFFFFFFF);

  static const border = Color(0xFFE2EBEE);
  static const separator = Color(0xFFDCE1E8);
  static const chevron = Color(0xFF9AA5B4);
  static const cyanDeep = Color(0xFF04787E);

  static const pressedOverlay = Color(0x1F112444);
  static const shadow = Color(0x14112444);
  static const shadowNeutral = Color(0x1F000000);

  static const error = Color(0xFFC2305F);
  static const errorSoft = Color(0xFFFDE8EF);
  static const success = Color(0xFF8FBF2A);
  static const successDark = Color(0xFF4F720C);
  static const successSoft = Color(0xFFEEF6D6);
  static const blueSoft = Color(0xFFE6EEF3);
  static const menuSurface = surface;
  static const switchThumbOff = surface;
  static const splashBackground = background;

  static const chartColor1 = cyanDark;
  static const chartColor2 = Color(0xFF15305F);
  static const chartColor3 = Color(0xFF98C232);
  static const chartColor4 = cyanDeep;
  static const chartColor5 = blue;
}

class AppDarkColors {
  static const cyan = Color(0xFFE3FF6B);
  static const cyanDark = Color(0xFFCFFF04);
  static const cyanSoft = Color(0xFF2B3512);
  static const navy = Color(0xFFEEF2EA);
  static const blue = Color(0xFF7DB9E8);

  static const background = Color(0xFF0F1210);
  static const surface = Color(0xFF1A1F1C);
  static const neutralButton = Color(0xFF2A302C);
  static const track = neutralButton;

  static const textPrimary = navy;
  static const textSecondary = Color(0xFFA6B0A9);
  static const textSecondaryDark = Color(0xFFD3DAD4);
  static const textMuted = Color(0xFF6F7A73);

  static const onCyan = Color(0xFF111511);
  static const onDark = Color(0xFF111511);

  static const border = Color(0xFF323A35);
  static const separator = Color(0xFF282E2A);
  static const chevron = Color(0xFF6F7A73);
  static const cyanDeep = Color(0xFFA9D600);

  static const pressedOverlay = Color(0x29000000);
  static const shadow = Color(0x40000000);
  static const shadowNeutral = Color(0x52000000);

  static const error = Color(0xFFFF6B8B);
  static const errorSoft = Color(0xFF3B1F27);
  static const success = Color(0xFF4FD68A);
  static const successDark = Color(0xFF7BE3A6);
  static const successSoft = Color(0xFF173022);
  static const blueSoft = Color(0xFF1D2A35);
  static const menuSurface = Color(0xFF272D29);
  static const switchThumbOff = Color(0xFF8C968F);
  static const splashBackground = background;

  static const chartColor1 = cyanDark;
  static const chartColor2 = Color(0xFF00E5FF);
  static const chartColor3 = Color(0xFFFF9F1C);
  static const chartColor4 = Color(0xFFE040FB);
  static const chartColor5 = Color(0xFF7C6CFF);
}

class AppColors {
  static bool _dark = false;

  static bool get isDark => _dark;

  static void useDark(bool dark) => _dark = dark;

  static Color get cyan =>
      _dark ? AppDarkColors.cyan : AppLightColors.cyan;
  static Color get cyanDark =>
      _dark ? AppDarkColors.cyanDark : AppLightColors.cyanDark;
  static Color get cyanSoft =>
      _dark ? AppDarkColors.cyanSoft : AppLightColors.cyanSoft;
  static Color get navy =>
      _dark ? AppDarkColors.navy : AppLightColors.navy;
  static Color get blue =>
      _dark ? AppDarkColors.blue : AppLightColors.blue;
  static Color get background =>
      _dark ? AppDarkColors.background : AppLightColors.background;
  static Color get surface =>
      _dark ? AppDarkColors.surface : AppLightColors.surface;
  static Color get neutralButton =>
      _dark ? AppDarkColors.neutralButton : AppLightColors.neutralButton;
  static Color get track =>
      _dark ? AppDarkColors.track : AppLightColors.track;
  static Color get textPrimary =>
      _dark ? AppDarkColors.textPrimary : AppLightColors.textPrimary;
  static Color get textSecondary =>
      _dark ? AppDarkColors.textSecondary : AppLightColors.textSecondary;
  static Color get textSecondaryDark =>
      _dark ? AppDarkColors.textSecondaryDark : AppLightColors.textSecondaryDark;
  static Color get textMuted =>
      _dark ? AppDarkColors.textMuted : AppLightColors.textMuted;
  static Color get onCyan =>
      _dark ? AppDarkColors.onCyan : AppLightColors.onCyan;
  static Color get onDark =>
      _dark ? AppDarkColors.onDark : AppLightColors.onDark;
  static Color get border =>
      _dark ? AppDarkColors.border : AppLightColors.border;
  static Color get separator =>
      _dark ? AppDarkColors.separator : AppLightColors.separator;
  static Color get chevron =>
      _dark ? AppDarkColors.chevron : AppLightColors.chevron;
  static Color get cyanDeep =>
      _dark ? AppDarkColors.cyanDeep : AppLightColors.cyanDeep;
  static Color get pressedOverlay =>
      _dark ? AppDarkColors.pressedOverlay : AppLightColors.pressedOverlay;
  static Color get shadow =>
      _dark ? AppDarkColors.shadow : AppLightColors.shadow;
  static Color get shadowNeutral =>
      _dark ? AppDarkColors.shadowNeutral : AppLightColors.shadowNeutral;
  static Color get error =>
      _dark ? AppDarkColors.error : AppLightColors.error;
  static Color get errorSoft =>
      _dark ? AppDarkColors.errorSoft : AppLightColors.errorSoft;
  static Color get success =>
      _dark ? AppDarkColors.success : AppLightColors.success;
  static Color get successDark =>
      _dark ? AppDarkColors.successDark : AppLightColors.successDark;
  static Color get successSoft =>
      _dark ? AppDarkColors.successSoft : AppLightColors.successSoft;
  static Color get blueSoft =>
      _dark ? AppDarkColors.blueSoft : AppLightColors.blueSoft;
  static Color get menuSurface =>
      _dark ? AppDarkColors.menuSurface : AppLightColors.menuSurface;
  static Color get switchThumbOff =>
      _dark ? AppDarkColors.switchThumbOff : AppLightColors.switchThumbOff;
  static Color get splashBackground =>
      _dark ? AppDarkColors.splashBackground : AppLightColors.splashBackground;
  static Color get chartColor1 =>
      _dark ? AppDarkColors.chartColor1 : AppLightColors.chartColor1;
  static Color get chartColor2 =>
      _dark ? AppDarkColors.chartColor2 : AppLightColors.chartColor2;
  static Color get chartColor3 =>
      _dark ? AppDarkColors.chartColor3 : AppLightColors.chartColor3;
  static Color get chartColor4 =>
      _dark ? AppDarkColors.chartColor4 : AppLightColors.chartColor4;
  static Color get chartColor5 =>
      _dark ? AppDarkColors.chartColor5 : AppLightColors.chartColor5;
}

Color chartColorAt(int index) => [
  AppColors.chartColor1,
  AppColors.chartColor2,
  AppColors.chartColor3,
  AppColors.chartColor4,
  AppColors.chartColor5,
][index % 5];

Color onColorOf(Color fill) {
  if (fill == AppColors.cyan) return AppColors.onCyan;
  return AppColors.onDark;
}

TextStyle get chartAxisStyle => TextStyle(
  fontSize: 10,
  color: AppColors.textSecondary,
);

const SystemUiOverlayStyle appSystemOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: AppLightColors.background,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
);

const SystemUiOverlayStyle appDarkSystemOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: AppDarkColors.background,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,
);

SystemUiOverlayStyle get activeSystemOverlayStyle =>
    AppColors.isDark ? appDarkSystemOverlayStyle : appSystemOverlayStyle;

class AppSpacing {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s48 = 48;
}

class AppIconSize {
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s52 = 52;
  static const double s60 = 60;
  static const double s120 = 120;
}

class AppStroke {
  static const double hairline = 1;
  static const double thin = 1.5;
  static const double medium = 2;
  static const double thick = 3;
  static const double accent = 4;
}

class AppExtent {
  static const double e40 = 40;
  static const double e44 = 44;
  static const double e50 = 50;
  static const double e56 = 56;
  static const double e64 = 64;
  static const double e80 = 80;
  static const double e96 = 96;
  static const double e100 = 100;
  static const double e140 = 140;
  static const double e180 = 180;
  static const double e196 = 196;
  static const double e200 = 200;
  static const double e220 = 220;
  static const double e240 = 240;
  static const double e260 = 260;
  static const double e420 = 420;
  static const double e720 = 720;
}

class AppSmallRadius {
  static const double r3 = 3;
  static const double r5 = 5;
  static const double r9 = 9;
}

class AppOpacity {
  static const double a14 = 0.14;
  static const double a20 = 0.2;
  static const double a40 = 0.4;
  static const double a50 = 0.5;
  static const double a70 = 0.7;
  static const double a92 = 0.92;
}

class AppLineHeight {
  static const double tight = 1;
  static const double normal = 1.25;
  static const double relaxed = 1.5;
}

class AppShadows {
  static List<BoxShadow> get card => [
    BoxShadow(color: AppColors.shadow, blurRadius: 32, offset: const Offset(0, 12)),
  ];
}

class AppCards {
  static const double radius = 24;
  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(radius),
  );
  static BoxDecoration get decoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: borderRadius,
    boxShadow: AppShadows.card,
  );
}

class AppHeader {
  static const double rowHeight = 48;
  static const double sidePadding = AppSpacing.s16;
  static const double backStartPadding = AppSpacing.s8;
  static const double actionsEndPadding = AppSpacing.s4;
  static const double titleTopPadding = 0;
  static const double titleBottomPadding = AppSpacing.s14;
  static const double titleLineHeight = 1.2;
  static const double iconSize = 26;
  static const double backIconSize = 32;
  static const double backLabelMaxWidth = 120;
}

class AppButtons {
  static const double radius = AppMetrics.groupRadius;
  static const double height = AppMetrics.minTap;
  static const double stackGap = AppSpacing.s12;
  static const EdgeInsets formPadding = EdgeInsets.fromLTRB(
    AppSpacing.s16,
    0,
    AppSpacing.s16,
    AppSpacing.s24,
  );
}

class AppMetrics {
  static const double groupRadius = 14;
  static const double sheetRadius = 28;
  static const double sheetTopGap = 24;
  static const double controlRadius = groupRadius;
  static const double thumbRadius = controlRadius - AppSpacing.s2;
  static const double rowMinHeight = 52;
  static const double minTap = 48;
  static const double tileSize = 30;
  static const double tileRadius = 8;
  static const double dividerIndent = AppSpacing.s16;
  static const double dividerIndentWithTile =
      AppSpacing.s16 + tileSize + AppSpacing.s12;
  static const double dividerIndentWithThumb =
      AppSpacing.s16 + AppFlat.thumbSize + AppSpacing.s12;
  static const double largeTitleSize = 32;
  static const double navTitleSize = 17;
  static const double rowTitleSize = 17;
  static const double rowSubtitleSize = 15;
  static const double headerSize = 13;
  static const double formLabelSize = 14;
  static const double formTextSize = 17;
  static const double bigNumberSize = 40;
  static const double segmentedHeight = 40;
  static const double controlHeight = 48;
  static const double controlTextSize = 15;
  static const double filterTextSize = 13;
  static const double filterLabelSize = 12;
  static const double navLabelSize = 11;
  static const double tinyTextSize = 9;
  static const double buttonTextSize = 16;
  static const double titleMediumSize = 24;
  static const double menuMaxHeight = 280;
  static const double presetHeight = 36;
}

class AppFlat {
  static const double fieldRadius = 50;
  static const double thumbSize = 56;
  static const double thumbRadius = 16;
  static const double tileRadius = 20;
  static const double minTap = 48;
  static const EdgeInsets listWithFab = EdgeInsets.only(
    bottom: AppSpacing.s16 + 56 + AppSpacing.s16,
  );
  static const EdgeInsets gridWithFab = EdgeInsets.fromLTRB(
    AppSpacing.s16,
    AppSpacing.s8,
    AppSpacing.s16,
    AppSpacing.s16 + 56 + AppSpacing.s16,
  );
}

class AppSplash {
  static const double imageWidth = 160;
}

const String appFontFamily = 'Roboto';

String formatNumber(double value) {
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

ButtonStyle get destructiveButtonStyle => ElevatedButton.styleFrom(
  backgroundColor: AppColors.error,
  foregroundColor: AppColors.onDark,
);

ButtonStyle get neutralButtonStyle => ElevatedButton.styleFrom(
  backgroundColor: AppColors.neutralButton,
  foregroundColor: AppColors.textPrimary,
);

final lightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: appFontFamily,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppLightColors.cyan,
    brightness: Brightness.light,
    primary: AppLightColors.cyanDark,
    surface: AppLightColors.surface,
    background: AppLightColors.background,
    error: AppLightColors.error,
  ),
  scaffoldBackgroundColor: AppLightColors.background,
  canvasColor: AppLightColors.surface,
  cardColor: AppLightColors.surface,

  textTheme: const TextTheme(
    headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.normal),
    displayLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
    displayMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
    displaySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
    headlineLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppLightColors.background,
    foregroundColor: AppLightColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: appSystemOverlayStyle,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppLightColors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.s16,
      vertical: AppSpacing.s14,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      borderSide: const BorderSide(color: AppLightColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      borderSide: const BorderSide(color: AppLightColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      borderSide: const BorderSide(color: AppLightColors.cyanDark, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      borderSide: const BorderSide(color: AppLightColors.error),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppLightColors.cyanDark,
      foregroundColor: AppLightColors.onDark,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      overlayColor: AppLightColors.pressedOverlay,
      minimumSize: const Size(double.infinity, AppButtons.height),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppButtons.radius),
      ),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(64, AppMetrics.minTap),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
      ),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppLightColors.cyanDark,
    foregroundColor: AppLightColors.onDark,
  ),
  cardTheme: const CardThemeData(
    color: AppLightColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppLightColors.surface,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: const TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
      color: AppLightColors.textPrimary,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppLightColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: AppLightColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  dropdownMenuTheme: const DropdownMenuThemeData(
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(AppLightColors.surface),
      surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
    ),
  ),
  datePickerTheme: const DatePickerThemeData(
    backgroundColor: AppLightColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  fontFamily: appFontFamily,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppDarkColors.cyan,
    brightness: Brightness.dark,
    primary: AppDarkColors.cyanDark,
    surface: AppDarkColors.surface,
    error: AppDarkColors.error,
    onPrimary: AppDarkColors.onDark,
    onError: AppDarkColors.onDark,
    onSurface: AppDarkColors.textPrimary,
    onSurfaceVariant: AppDarkColors.textSecondary,
    outline: AppDarkColors.border,
    outlineVariant: AppDarkColors.separator,
    surfaceContainerLowest: AppDarkColors.background,
    surfaceContainerLow: AppDarkColors.surface,
    surfaceContainer: AppDarkColors.surface,
    surfaceContainerHigh: AppDarkColors.neutralButton,
    surfaceContainerHighest: AppDarkColors.neutralButton,
  ),
  scaffoldBackgroundColor: AppDarkColors.background,
  canvasColor: AppDarkColors.surface,
  cardColor: AppDarkColors.surface,

  textTheme: const TextTheme(
    headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.normal),
    displayLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
    displayMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
    displaySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
    headlineLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppDarkColors.background,
    foregroundColor: AppDarkColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: appDarkSystemOverlayStyle,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppDarkColors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.s16,
      vertical: AppSpacing.s14,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      borderSide: const BorderSide(color: AppDarkColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      borderSide: const BorderSide(color: AppDarkColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      borderSide: const BorderSide(color: AppDarkColors.cyanDark, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
      borderSide: const BorderSide(color: AppDarkColors.error),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppDarkColors.cyanDark,
      foregroundColor: AppDarkColors.onDark,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      overlayColor: AppDarkColors.pressedOverlay,
      minimumSize: const Size(double.infinity, AppButtons.height),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppButtons.radius),
      ),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(64, AppMetrics.minTap),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
      ),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppDarkColors.cyanDark,
    foregroundColor: AppDarkColors.onDark,
  ),
  cardTheme: const CardThemeData(
    color: AppDarkColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppDarkColors.surface,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: const TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
      color: AppDarkColors.textPrimary,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppDarkColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: AppDarkColors.menuSurface,
    surfaceTintColor: Colors.transparent,
  ),
  dropdownMenuTheme: const DropdownMenuThemeData(
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(AppDarkColors.menuSurface),
      surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
    ),
  ),
  datePickerTheme: const DatePickerThemeData(
    backgroundColor: AppDarkColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
);
