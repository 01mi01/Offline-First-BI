import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Colores principales de la aplicación
class AppColors {
  //Teal (original)
  //static const primary = Color(0xFF1A9E98);
  //static const primaryDark = Color(0xFF137A75);

  //Lime (nuevo logo)
  //static const primary = Color(0xFFAFC908);
  //static const primaryDark = Color(0xFF8FA506);

  //Lime (nuevo logo + Dark mode)
  //static const primary = Color(0xFFBCE704);
  //static const primaryDark = Color(0xFF97B803);

static const primary = Color(0xFF00C3CF); 
static const primaryDark = Color(0xFF008197);
static const background = Color(0xFFF2F2F7);
static const surface = Color(0xFFFFFFFF);
static const textPrimary = Color(0xFF000000);
static const textSecondary = Color(0xFF6B7280);
static const border = Color(0xFFE5E7EB);
static const error = Color(0xFFFF3B30);
static const success = Color(0xFF34C759);
}

// Tema claro de la aplicación
final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    surface: AppColors.surface,
    background: AppColors.background,
    error: AppColors.error,
  ),
  scaffoldBackgroundColor: AppColors.background,
  textTheme: GoogleFonts.interTextTheme(),
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
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      elevation: 0,
    ),
  ),
  cardColor: AppColors.surface,
);
