// Modelo de compra
class PurchaseModel {
  final int id;
  final int? supplierId;
  final int? locationId;
  final int? eventId;
  final bool isMaterial;
  final String? description;
  final double totalAmount;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  // Una compra cancelada se conserva como historial (el stock de sus materiales
  // ya se restó) y no cuenta como gasto.
  final bool isCanceled;
  final DateTime? canceledAt;

  PurchaseModel({
    required this.id,
    this.supplierId,
    this.locationId,
    this.eventId,
    required this.isMaterial,
    this.description,
    required this.totalAmount,
    required this.date,
    this.notes,
    required this.createdAt,
    this.isCanceled = false,
    this.canceledAt,
  });
}