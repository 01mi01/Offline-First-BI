// Reloj de la app. Todo lo que depende de "hoy" (filtros por fecha, periodos
// de Business Intelligence, totales del mes, fechas por defecto...) lee la hora
// de aquí en vez de llamar a DateTime.now() directamente, así las pruebas
// pueden fijar una fecha (ver test/flutter_test_config.dart).
DateTime Function() _now = DateTime.now;

DateTime appNow() => _now();

// Solo para pruebas: fija el reloj; sin argumento vuelve al reloj real.
void setAppClockForTesting([DateTime Function()? now]) {
  _now = now ?? DateTime.now;
}
