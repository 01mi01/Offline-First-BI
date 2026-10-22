import 'purchase_model.dart';

enum PurchaseKind {
  all,
  material,
  expense;

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
