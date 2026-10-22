
double? pricePerWholeUnit({required double totalPaid, required double quantity}) {
  if (quantity <= 0 || totalPaid <= 0 || totalPaid.isNaN || quantity.isNaN) {
    return null;
  }
  return totalPaid / quantity;
}

double totalForQuantity({required double pricePerUnit, required double quantity}) =>
    pricePerUnit * quantity;
