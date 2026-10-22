import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const Locale appLocale = Locale('es');

const List<Locale> appSupportedLocales = [appLocale];

const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
