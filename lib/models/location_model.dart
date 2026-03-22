// Modelo de ubicación
class LocationModel {
  final int id;
  final String city;
  final String country;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  LocationModel({
    required this.id,
    required this.city,
    required this.country,
    this.description,
    required this.isActive,
    required this.createdAt,
  });
}