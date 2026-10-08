// Modelo de ítem de compra de material
class PurchaseItemModel {
  final int id;
  final int purchaseId;
  final int materialId;
  final String materialName;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  // Unidad del material (para mostrar la cantidad con el formato que le toca).
  final String unitName;
  final String unitType;

  PurchaseItemModel({
    required this.id,
    required this.purchaseId,
    required this.materialId,
    required this.materialName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.unitName = '',
    this.unitType = 'medida',
  });
}