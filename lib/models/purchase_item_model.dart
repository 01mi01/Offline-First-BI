// Modelo de ítem de compra de material
class PurchaseItemModel {
  final int id;
  final int purchaseId;
  final int materialId;
  final String materialName;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  PurchaseItemModel({
    required this.id,
    required this.purchaseId,
    required this.materialId,
    required this.materialName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });
}