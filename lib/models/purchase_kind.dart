import 'purchase_model.dart';

// Tipo de compra para filtrar: de materiales, gasto general, o ambos.
enum PurchaseKind {
  all,
  material,
  expense;

  // Nombre en plural para menús y chips.
  String get label => switch (this) {
    PurchaseKind.all => 'Todas',
    PurchaseKind.material => 'Materiales',
    PurchaseKind.expense => 'Gastos',
  };

  bool includes(PurchaseModel purchase) => switch (this) {
    PurchaseKind.all => true,
    PurchaseKind.material => purchase.isMaterial,
    PurchaseKind.expense => !purchase.isMaterial,
  };
}
