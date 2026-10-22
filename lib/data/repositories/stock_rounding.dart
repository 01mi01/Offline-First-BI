import '../../config/rounding.dart';
import '../db/app_database.dart';

Future<double> roundForUnit(AppDatabase db, int unitId, double value) async {
  final unit = await (db.select(
    db.units,
  )..where((u) => u.id.equals(unitId))).getSingleOrNull();
  return roundQuantity(value, unitType: unit?.type ?? 'medida');
}

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
