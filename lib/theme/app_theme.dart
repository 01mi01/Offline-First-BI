import 'package:flutter/material.dart';

// Colores principales de la aplicación
class AppColors {
  static const primary = Color(0xFF13A09A);
  // Variante más oscura del acento, para estados presionados/enfatizados.
  static const primaryDark = Color(0xFF0D7A75);
  static const background = Color(0xFFF2F2F7);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF000000);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  // El único rojo de la aplicación: errores de validación, cancelaciones,
  // acciones destructivas, gastos... Oscuro a propósito: cumple el contraste
  // mínimo de 4.5:1 sobre fondo claro, también como texto pequeño.
  static const error = Color(0xFFB71C1C);
  static const success = Color(0xFF34C759);
  // Variante más oscura del verde para TEXTO pequeño (etiquetas "Activo"): el
  // verde base no llega al contraste mínimo de 4.5:1 sobre fondo claro. Mismo
  // tono, más oscuro (igual que primaryDark respecto de primary).
  static const successDark = Color(0xFF176B31);

  // Paleta de los gráficos de Business Intelligence. Las cinco se derivan del
  // acento (primary = HSL 177°, 79 %, 35 %) rotando el tono dentro de la
  // familia verde / verde azulado / cian (146°–189°) y ajustando la
  // luminosidad; no hay colores arbitrarios. Los gráficos las toman en orden y,
  // si tienen más de cinco series, vuelven a empezar (ver chartColorAt).
  // 1: el propio acento (tono 177°, L 35 %).
  static const chartColor1 = Color(0xFF13A09A);
  // 2: mismo tono, L 26.5 %: es primaryDark.
  static const chartColor2 = Color(0xFF0D7A75);
  // 3: tono −3° (174°), S 62 %, L 45 %: variante clara del acento. La L 56 %
  // sugerida (#4FD1C5) daba solo 1.9:1 contra blanco; con L 45 % sube a 2.4:1
  // sin acercarse al acento.
  static const chartColor3 = Color(0xFF2CBAAD);
  // 4: tono −31° (146°, verde mar), S 50 %, L 36 %: 4.3:1 contra blanco.
  static const chartColor4 = Color(0xFF2E8B57);
  // 5: tono +11° (188°, cian), S 95 %, L 38 %. La L 43 % sugerida (#06B6D4)
  // daba 2.4:1 contra blanco; con L 38 % llega a 3:1.
  static const chartColor5 = Color(0xFF05A3BD);
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
    primary: AppColors.primary,
    surface: AppColors.surface,
    background: AppColors.background,
    error: AppColors.error,
  ),
  scaffoldBackgroundColor: AppColors.background,
  canvasColor: AppColors.background,

  // Tipografía.
  // headlineMedium, headlineSmall, titleLarge, titleMedium, titleSmall,
  // bodyLarge, bodyMedium y bodySmall ya se usan en algunas pantallas con su
  // tamaño por defecto de Material 3 y no se sobreescriben aquí para no
  // alterarlas. displayLarge/Medium/Small y headlineLarge no se usaban antes
  // y se reutilizan para los tamaños adicionales que necesita el resto de la
  // app; labelLarge/Medium/Small ya cubren 14/12/11 con su valor por defecto.
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
    displayMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
    displaySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
    headlineLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
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
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.error),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      // Estado presionado/enfocado con la variante oscura del acento.
      overlayColor: AppColors.primaryDark,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      elevation: 0,
    ),
  ),
  cardColor: AppColors.surface,
);
