import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Idioma de la app: español fijo, sin importar el idioma del dispositivo, para
// que los textos propios de Material (selectores de fecha, "Cancelar"/
// "Aceptar", etc.) salgan en español.
const Locale appLocale = Locale('es');

const List<Locale> appSupportedLocales = [appLocale];

const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
