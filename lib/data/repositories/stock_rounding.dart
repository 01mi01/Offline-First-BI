import '../../config/rounding.dart';
import '../db/app_database.dart';

// Redondea una cantidad de material según el tipo de su unidad (ver
// roundQuantity): dos decimales, o solo limpieza de ruido para las unidades
// por fracciones. Sirve para el stock, los usos y las cantidades compradas.
Future<double> roundForUnit(AppDatabase db, int unitId, double value) async {
  final unit = await (db.select(
    db.units,
  )..where((u) => u.id.equals(unitId))).getSingleOrNull();
  return roundQuantity(value, unitType: unit?.type ?? 'medida');
}

// Igual, partiendo del id del material.
Future<double> roundForMaterial(
  AppDatabase db,
  int materialId,
  double value,
) async {
  final material = await (db.select(
    db.materials,
  )..where((m) => m.id.equals(materialId))).getSingleOrNull();
  if (material == null) return round2(value);
  return roundForUnit(db, material.unitId, value);
}
