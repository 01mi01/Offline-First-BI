// Modelo de cliente
class ClientModel {
  final int id;
  final String name;
  final String? contactInfo;
  final bool isActive;
  final DateTime createdAt;

  ClientModel({
    required this.id,
    required this.name,
    this.contactInfo,
    required this.isActive,
    required this.createdAt,
  });
}