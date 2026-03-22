// Modelo de compra
class PurchaseModel {
  final int id;
  final int? supplierId;
  final int? locationId;
  final bool isMaterial;
  final String? description;
  final double totalAmount;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  PurchaseModel({
    required this.id,
    this.supplierId,
    this.locationId,
    required this.isMaterial,
    this.description,
    required this.totalAmount,
    required this.date,
    this.notes,
    required this.createdAt,
  });
}