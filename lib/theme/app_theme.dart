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
  static const error = Color(0xFFFF3B30);
  static const success = Color(0xFF34C759);
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
