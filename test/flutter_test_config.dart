import 'dart:async';
import 'dart:io';

import 'package:offline_first_bi/config/app_clock.dart';

// Configuración común de toda la suite. Con la variable de entorno FAKE_NOW
// (p. ej. FAKE_NOW=2026-10-31T15:00:00) toda la app y las pruebas ven esa
// fecha como "hoy": sirve para comprobar que ninguna prueba depende del día en
// que se corre (fin y principio de mes, de año, lunes, etc.).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final fake = Platform.environment['FAKE_NOW'];
  if (fake != null && fake.isNotEmpty) {
    final fixed = DateTime.parse(fake);
    setAppClockForTesting(() => fixed);
  }
  await testMain();
}
