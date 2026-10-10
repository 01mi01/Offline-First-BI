import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Colores
// ---------------------------------------------------------------------------

class AppColors {
  // Marca
  static const cyan = Color(0xFF06B1B9);
  static const cyanDark = Color(0xFF05959C);
  static const cyanSoft = Color(0xFFE1F6F7);
  static const navy = Color(0xFF112444);
  static const lime = Color(0xFFBEE355);
  static const blue = Color(0xFF2C6E9B);
  static const blueSoft = Color(0xFFE6EEF3);

  // Fondos
  static const background = Color(0xFFF3F2F7);
  static const surface = Color(0xFFFAFAFA);
  static const neutralButton = Color(0xFFE6E9EF);
  static const track = Color(0xFFE6E9EF);

  // Texto
  static const textPrimary = navy;
  static const textSecondary = Color(0xFF5B6B82);
  static const textSecondaryDark = Color(0xFF10314F);
  static const textMuted = Color(0xFF9AA6B8);

  // Texto e íconos sobre un relleno de color
  static const onCyan = navy;
  static const onLime = navy;
  static const onDark = Color(0xFFFFFFFF);

  // Líneas y detalles
  static const border = Color(0xFFE2EBEE);
  static const hairline = Color(0xFFE8ECF1);
  static const separator = Color(0xFFDCE1E8);
  static const chevron = Color(0xFF9AA5B4);

  // Efectos
  static const pressedOverlay = Color(0x1F112444);
  static const shadow = Color(0x14112444);
  static const shadowNeutral = Color(0x1F000000);
  static const scrim = Color(0xB3000000);

  // Estados
  static const error = Color(0xFFC2305F);
  static const errorSoft = Color(0xFFFDE8EF);
  static const success = Color(0xFF8FBF2A);
  static const successDark = Color(0xFF4F720C);
  static const successSoft = Color(0xFFEEF6D6);

  // Paleta de los gráficos de Business Intelligence.
  static const chartColor1 = Color(0xFF05959C);
  static const chartColor2 = Color(0xFF15305F);
  static const chartColor3 = Color(0xFF98C232);
  static const chartColor4 = Color(0xFF04787E);
  static const chartColor5 = Color(0xFF2C6E9B);
}

// Color de la serie [index] de un gráfico: recorre los cinco colores de la
// paleta en orden y vuelve al primero a partir de la sexta serie. Es la única
// vía para colorear gráficos.
Color chartColorAt(int index) => const [
  AppColors.chartColor1,
  AppColors.chartColor2,
  AppColors.chartColor3,
  AppColors.chartColor4,
  AppColors.chartColor5,
][index % 5];

// Color del texto o ícono que va sobre un relleno de color.
Color onColorOf(Color fill) {
  if (fill == AppColors.cyan) return AppColors.onCyan;
  if (fill == AppColors.lime) return AppColors.onLime;
  return AppColors.onDark;
}

// Barra de estado: del color de la página y con íconos oscuros.
const SystemUiOverlayStyle appSystemOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: AppColors.background,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
);

// ---------------------------------------------------------------------------
// Medidas
// ---------------------------------------------------------------------------

class AppSpacing {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  // Relleno de listas con botón flotante: 56 de alto más 16 de margen.
  static const EdgeInsets listWithFab = EdgeInsets.fromLTRB(
    s16,
    s16,
    s16,
    s16 + 56 + s16,
  );
}

class AppShadows {
  static const thumb = [
    BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const card = [
    BoxShadow(color: AppColors.shadow, blurRadius: 32, offset: Offset(0, 12)),
  ];
}

class AppCards {
  static const double radius = 24;
  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(radius),
  );
  static const BoxDecoration decoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: borderRadius,
    boxShadow: AppShadows.card,
  );
}

// Cabecera común de todas las pantallas.
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

// Listas agrupadas, hojas, controles y títulos.
class AppMetrics {
  static const double groupRadius = 14;
  static const double sheetRadius = 14;
  static const double controlRadius = groupRadius;
  static const double thumbRadius = controlRadius - AppSpacing.s2;
  static const double rowMinHeight = 52;
  static const double minTap = 48;
  static const double tileSize = 30;
  static const double tileRadius = 8;
  static const double dividerIndent = AppSpacing.s16;
  static const double dividerIndentWithTile =
      AppSpacing.s16 + tileSize + AppSpacing.s12;
  static const double largeTitleSize = 34;
  static const double navTitleSize = 17;
  static const double rowTitleSize = 17;
  static const double rowSubtitleSize = 15;
  static const double headerSize = 13;
  static const double bigNumberSize = 40;
  static const double navBarHeight = 44;
  static const double grabberWidth = 36;
  static const double grabberHeight = 5;
  static const double segmentedHeight = 40;
  static const double controlHeight = 48;
  static const double controlTextSize = 15;
  static const double filterTextSize = 13;
  static const double filterLabelSize = 12;
  static const double menuMaxHeight = 280;
  static const double presetHeight = 36;
}

// Inventario: filas sin tarjeta, campos y filtros totalmente redondeados.
class AppFlat {
  static const double fieldRadius = 50;
  static const double thumbSize = 56;
  static const double thumbRadius = 16;
  static const double tileRadius = 20;
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s16,
    vertical: AppSpacing.s12,
  );
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

// ---------------------------------------------------------------------------
// Texto y formato
// ---------------------------------------------------------------------------

const String appFontFamily = 'Roboto';

String formatNumber(double value) {
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

// ---------------------------------------------------------------------------
// Temas
// ---------------------------------------------------------------------------

final ButtonStyle destructiveButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.error,
  foregroundColor: AppColors.onDark,
);

final ButtonStyle neutralButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.neutralButton,
  foregroundColor: AppColors.textPrimary,
);

// Tema de las pantallas de Inventario: campos sin borde (con aro al enfocar),
// botones secundarios redondeados y líneas divisorias finas.
ThemeData flatThemeOf(ThemeData base) {
  OutlineInputBorder border([BorderSide side = BorderSide.none]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppFlat.fieldRadius),
        borderSide: side,
      );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: AppColors.background,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s14,
      ),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      helperStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,
      border: border(),
      enabledBorder: border(),
      disabledBorder: border(),
      focusedBorder: border(
        const BorderSide(color: AppColors.cyanDark, width: 2),
      ),
      errorBorder: border(const BorderSide(color: AppColors.error)),
      focusedErrorBorder: border(
        const BorderSide(color: AppColors.error, width: 2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(double.infinity, AppMetrics.minTap),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.cyanDark,
        minimumSize: const Size(AppFlat.minTap, AppFlat.minTap),
        shape: const StadiumBorder(),
      ),
    ),
  );
}

final lightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: appFontFamily,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.cyan,
    brightness: Brightness.light,
    primary: AppColors.cyanDark,
    surface: AppColors.surface,
    background: AppColors.background,
    error: AppColors.error,
  ),
  scaffoldBackgroundColor: AppColors.background,
  canvasColor: AppColors.surface,
  cardColor: AppColors.surface,

  // headlineSmall es el título de pantalla (saludo de Inicio, Iniciar sesión).
  textTheme: const TextTheme(
    headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.normal),
    displayLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
    displayMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
    displaySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
    headlineLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: appSystemOverlayStyle,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.cyanDark, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.error),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.cyanDark,
      foregroundColor: AppColors.onDark,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      overlayColor: AppColors.pressedOverlay,
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
    backgroundColor: AppColors.cyanDark,
    foregroundColor: AppColors.onDark,
  ),
  cardTheme: const CardThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: const TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  dropdownMenuTheme: const DropdownMenuThemeData(
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(AppColors.surface),
      surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
    ),
  ),
  datePickerTheme: const DatePickerThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
);
