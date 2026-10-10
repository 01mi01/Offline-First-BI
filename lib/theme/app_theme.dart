import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Barra de estado: del color de la página y con íconos oscuros.
const SystemUiOverlayStyle appSystemOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: AppColors.background,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
);

// Color del texto o ícono que va sobre un relleno de color.
Color onColorOf(Color fill) =>
    fill == AppColors.primary || fill == AppColors.accent
    ? AppColors.onPrimary
    : AppColors.textButtons;

// Colores principales de la aplicación
class AppColors {
  // Acento principal (cian).
  static const primary = Color(0xFF06B1B9);
  // Variante oscura del acento, para texto con acento y estados enfatizados.
  static const primaryDark = Color(0xFF05959C);
  // Cian al 12 % sobre blanco: círculo suave detrás de íconos y accesos.
  static const primarySoft = Color(0xFFE1F6F7);
  static const steelSoft = Color(0xFFE6EEF3);
  // Azul marino, color del texto principal y del texto sobre el acento.
  static const navy = Color(0xFF112444);
  // Verde lima, acento secundario solo para fondos y detalles.
  static const accent = Color(0xFFBEE355);
  // Texto sobre superficies con fondo cian o lima.
  static const onPrimary = navy;
  // Capa de estado presionado sobre botones cian (navy al 12 %).
  static const pressedOverlay = Color(0x1F112444);

  // Fondo de todas las pantallas y color de tarjetas, campos y hojas.
  static const background = Color(0xFFF3F2F7);
  static const surface = Color(0xFFFAFAFA);
  // Estilo plano: línea divisoria de 1 px entre filas, más suave que [border].
  static const hairline = Color(0xFFE8ECF1);
  // Estilo iOS: separador fino, pista de controles segmentados y buscador, y
  // flecha de las filas.
  static const iosSeparator = Color(0xFFDCE1E8);
  static const iosTrack = Color(0xFFE6E9EF);
  static const iosChevron = Color(0xFF9AA5B4);
  static const textPrimary = navy;
  static const textSecondaryDark = Color(0xFF10314F);
  static const textSecondary = Color(0xFF5B6B82);
  static const textButtons = Color(0xFFFFFFFF);
  static const neutralButton = Color(0xFFE6E9EF);
  static const textMuted = Color(0xFF9AA6B8);
  static const border = Color(0xFFE2EBEE);
  // Sombra suave de tarjetas elevadas (navy al 8 %).
  static const shadow = Color(0x14112444);
  // Rosa intenso casi rojo: errores de validación, cancelaciones, acciones
  // destructivas, gastos y valores a la baja.
  static const error = Color(0xFFC2305F);
  // Fondo suave para etiquetas y chips de error o de valores a la baja.
  static const errorSoft = Color(0xFFFDE8EF);
  // Verde lima oscurecido: valores al alza y estados correctos, usado en
  // íconos, flechas y rellenos de gráficos. No llega al contraste mínimo
  // para texto pequeño.
  static const success = Color(0xFF8FBF2A);
  // Variante más oscura del verde para TEXTO pequeño (etiquetas "Activo").
  static const successDark = Color(0xFF4F720C);
  // Fondo suave para etiquetas y chips de éxito.
  static const successSoft = Color(0xFFEEF6D6);

  // Paleta de los gráficos de Business Intelligence, derivada de los tres colores base.
  static const chartColor1 = Color(0xFF05959C);
  static const chartColor2 = Color(0xFF15305F);
  static const chartColor3 = Color(0xFF98C232);
  static const chartColor4 = Color(0xFF04787E);
  static const chartColor5 = Color(0xFF2C6E9B);
}

// Color de la serie [index] de un gráfico: recorre los cinco colores de la
// paleta en orden y vuelve al primero a partir de la sexta serie. Es la única
// vía para colorear gráficos (nunca colores sueltos ni la paleta por defecto
// de la librería).
Color chartColorAt(int index) => const [
  AppColors.chartColor1,
  AppColors.chartColor2,
  AppColors.chartColor3,
  AppColors.chartColor4,
  AppColors.chartColor5,
][index % 5];

// Sombras de la aplicación.
class AppShadows {
  // Sombra muy suave de una tarjeta blanca sobre el fondo claro.
  static const card = [
    BoxShadow(color: AppColors.shadow, blurRadius: 32, offset: Offset(0, 12)),
  ];
}

// Tarjetas de las pantallas tipo panel (Inicio).
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

// Medidas de la cabecera común de todas las pantallas.
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

// Medidas comunes de todos los botones.
class AppButtons {
  static const double radius = AppIos.groupRadius;
  static const double height = AppIos.minTap;
  static const double stackGap = AppSpacing.s12;
  static const EdgeInsets formPadding = EdgeInsets.fromLTRB(
    AppSpacing.s16,
    0,
    AppSpacing.s16,
    AppSpacing.s24,
  );
}

// Medidas del estilo iOS (módulo de Ventas y Compras).
class AppIos {
  static const double groupRadius = 14;
  static const double sheetRadius = 14;
  static const double controlRadius = 10;
  static const double thumbRadius = 8;
  static const double rowMinHeight = 52;
  static const double minTap = 48;
  static const double tileSize = 30;
  static const double tileRadius = 8;
  // Sangría del separador: relleno lateral, o relleno + icono + espacio.
  static const double dividerIndent = AppSpacing.s16;
  static const double dividerIndentWithTile = AppSpacing.s16 + tileSize + AppSpacing.s12;
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
  static const double searchHeight = 48;
}

// Medidas del estilo plano (Inventario): filas sin tarjeta separadas por una
// línea fina, campos y filtros totalmente redondeados.
class AppFlat {
  // Campos de texto, buscador, filtros y botones: totalmente redondeados.
  static const double fieldRadius = 50;
  // Imagen o icono a la izquierda de una fila, y su radio.
  static const double thumbSize = 56;
  static const double thumbRadius = 16;
  // Baldosa del catálogo (imagen con nombre y precio debajo).
  static const double tileRadius = 20;
  // Relleno de una fila de lista.
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s16,
    vertical: AppSpacing.s12,
  );
  // Alto mínimo de un toque (filas, chips, botones de icono).
  static const double minTap = 48;
  // Relleno al final de las listas y del catálogo, para que el botón flotante
  // (56 de alto, a 16 del borde) no tape la última fila.
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

// Tema del estilo plano: campos sin borde (con aro cian al enfocar), botones
// secundarios como píldoras y líneas divisorias finas. Se aplica solo a las
// pantallas que lo piden (ver FlatStyle).
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
        const BorderSide(color: AppColors.primaryDark, width: 2),
      ),
      errorBorder: border(const BorderSide(color: AppColors.error)),
      focusedErrorBorder: border(
        const BorderSide(color: AppColors.error, width: 2),
      ),
    ),
    // Acción secundaria: píldora neutra, sin borde.
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.primaryDark,
    foregroundColor: AppColors.textButtons,
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(double.infinity, AppIos.minTap),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppIos.groupRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        minimumSize: const Size(AppFlat.minTap, AppFlat.minTap),
        shape: const StadiumBorder(),
      ),
    ),
  );
}

// Escala de espaciado de la aplicación (padding, gaps entre elementos)
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

  // Relleno para listas con botón flotante (+): el botón mide 56 y flota a 16
  // del borde, así que la última fila necesita ese espacio más el margen para
  // no quedar tapada al llegar al final del desplazamiento.
  static const EdgeInsets listWithFab = EdgeInsets.fromLTRB(
    s16,
    s16,
    s16,
    s16 + 56 + s16,
  );
}

// Formatea un número eliminando decimales innecesarios
String formatNumber(double value) {
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

// Familia tipográfica de la app, empaquetada como asset (ver pubspec.yaml).
// Es la única fuente: no se descarga nada por red en tiempo de ejecución.
const String appFontFamily = 'Roboto';

// Tema claro de la aplicación
final lightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: appFontFamily,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primaryDark,
    surface: AppColors.surface,
    background: AppColors.background,
    error: AppColors.error,
  ),
  scaffoldBackgroundColor: AppColors.background,
  canvasColor: AppColors.surface,

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
      borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.error),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: AppColors.textButtons,
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
      minimumSize: const Size(64, AppIos.minTap),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppIos.groupRadius),
      ),
    ),
  ),
  cardColor: AppColors.surface,
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
      borderRadius: BorderRadius.circular(AppIos.groupRadius),
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

final ButtonStyle destructiveButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.error,
  foregroundColor: AppColors.textButtons,
);

final ButtonStyle neutralButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.neutralButton,
  foregroundColor: AppColors.textPrimary,
);
