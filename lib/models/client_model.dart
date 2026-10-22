import 'default_records.dart';

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

  bool get isDefault => DefaultRecords.isClient(name);
}