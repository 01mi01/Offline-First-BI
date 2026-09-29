// Modelo de venta
class SaleModel {
  final int id;
  final int? clientId;
  final int? locationId;
  final int? eventId;
  final double totalAmount;
  final double discount;
  final double finalAmount;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  // Una venta cancelada se conserva como historial (su stock ya se devolvió).
  final bool isCanceled;
  final DateTime? canceledAt;

  SaleModel({
    required this.id,
    this.clientId,
    this.locationId,
    this.eventId,
    required this.totalAmount,
    required this.discount,
    required this.finalAmount,
    required this.date,
    this.notes,
    required this.createdAt,
    this.isCanceled = false,
    this.canceledAt,
  });
}
