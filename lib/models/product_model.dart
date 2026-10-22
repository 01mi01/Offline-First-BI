const int lowStockThreshold = 3;

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

({double priceA, double priceB}) resolveProductPrices(
  double? priceA,
  double? priceB,
) {
  final a = priceA ?? priceB;
  final b = priceB ?? priceA;
  if (a == null || b == null) {
    throw ArgumentError('Indica al menos un precio de venta');
  }
  return (priceA: a, priceB: b);
}
