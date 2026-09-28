// Modelo de material
class MaterialModel {
  final int id;
  final String name;
  final String? description;
  final int unitId;
  final double stock;
  final double pricePerUnit;
  final bool isActive;
  final DateTime createdAt;

  MaterialModel({
    required this.id,
    required this.name,
    this.description,
    required this.unitId,
    required this.stock,
    required this.pricePerUnit,
    required this.isActive,
    required this.createdAt,
  });
}