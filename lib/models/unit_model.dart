// Modelo de unidad de medida para materiales
class UnitModel {
  final int id;
  final String name;
  final String type;

  UnitModel({required this.id, required this.name, required this.type});
}


// Mensaje cuando se intenta cambiar la unidad de un material a una de otro tipo.
const String unitTypeChangeMessage =
    'Solo se puede cambiar a una unidad del mismo tipo';

// Unidades que se pueden elegir para un material. Al crear, todas. Al editar,
// solo las del mismo tipo que la unidad actual (contenedor con contenedor,
// medida con medida...): así una tira puede pasar a rollo, pero no a litro.
// Solo limita cambios a futuro: los registros de uso acumulan cantidades y no
// guardan la unidad de cada registro, por lo que nada del pasado cambia.
List<UnitModel> selectableUnitsFor(
  List<UnitModel> units, {
  UnitModel? current,
}) {
  if (current == null) return units;
  return units.where((u) => u.type == current.type).toList();
}

// true si pasar de [from] a [to] es un cambio permitido (mismo tipo).
bool isUnitChangeAllowed(UnitModel from, UnitModel to) => from.type == to.type;
