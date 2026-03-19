// Modelo de categoría de productos
class CategoryModel {
  final int id;
  final String name;
  final String? description;
  final String? image;
  final bool isActive;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.image,
    required this.isActive,
    required this.createdAt,
  });
}