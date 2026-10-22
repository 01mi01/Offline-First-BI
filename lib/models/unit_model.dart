class UnitModel {
  final int id;
  final String name;
  final String type;

  UnitModel({required this.id, required this.name, required this.type});
}

const String unitTypeChangeMessage =
    'Solo se puede cambiar a una unidad del mismo tipo';

List<UnitModel> selectableUnitsFor(
  List<UnitModel> units, {
  UnitModel? current,
}) {
  if (current == null) return units;
  return units.where((u) => u.type == current.type).toList();
}

