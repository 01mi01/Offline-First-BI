// Modelo de relación entre producto y material
class ProductMaterialModel {
  final int id;
  final int productId;
  final int materialId;
  final String materialName;
  final String materialUnitName;
  final String materialUnitType;
  final double quantityUsed;
  final double pricePerUnit;

  ProductMaterialModel({
    required this.id,
    required this.productId,
    required this.materialId,
    required this.materialName,
    required this.materialUnitName,
    required this.materialUnitType,
    required this.quantityUsed,
    required this.pricePerUnit,
  });
}