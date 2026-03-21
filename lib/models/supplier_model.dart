// Modelo de proveedor
class SupplierModel {
  final int id;
  final String name;
  final String? contactInfo;
  final bool isActive;
  final DateTime createdAt;

  SupplierModel({
    required this.id,
    required this.name,
    this.contactInfo,
    required this.isActive,
    required this.createdAt,
  });
}