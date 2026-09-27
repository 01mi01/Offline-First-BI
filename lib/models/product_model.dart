// Modelo de producto
class ProductModel {
  final int id;
  final int categoryId;
  final String name;
  final String? description;
  final String? image;
  final double priceA;
  final double priceB;
  final double? productionCost;
  final int stock;
  final bool isActive;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    this.image,
    required this.priceA,
    required this.priceB,
    this.productionCost,
    required this.stock,
    required this.isActive,
    required this.createdAt,
  });
}