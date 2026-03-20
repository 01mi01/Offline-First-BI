// Modelo de producto
class ProductModel {
  final int id;
  final int? categoryId;
  final String name;
  final String? description;
  final String? image;
  final double salePrice;
  final double? productionCost;
  final int stock;
  final bool isActive;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    this.categoryId,
    required this.name,
    this.description,
    this.image,
    required this.salePrice,
    this.productionCost,
    required this.stock,
    required this.isActive,
    required this.createdAt,
  });
}