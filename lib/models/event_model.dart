// Modelo de evento comercial
class EventModel {
  final int id;
  final String name;
  final int? locationId;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.name,
    this.locationId,
    required this.startDate,
    this.endDate,
    this.notes,
    required this.createdAt,
  });
}