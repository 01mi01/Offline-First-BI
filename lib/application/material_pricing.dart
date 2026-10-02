// Precio de los materiales tipo contenedor (botella, tira, paquete...).
//
// El precio guardado de un material (price_per_unit) es siempre el de UNA
// unidad entera. Pero quien compra media botella sabe cuánto PAGÓ, no cuánto
// costaría la botella entera: por eso, para materiales tipo contenedor, se
// pide el total pagado por la cantidad que se registra y de ahí se calcula el
// precio de la unidad entera (35 pagados por 0.5 botellas = 70 por botella).

// Precio de una unidad entera a partir del total pagado por [quantity].
// Devuelve null si no se puede calcular (cantidad o total no positivos).
double? pricePerWholeUnit({required double totalPaid, required double quantity}) {
  if (quantity <= 0 || totalPaid <= 0 || totalPaid.isNaN || quantity.isNaN) {
    return null;
  }
  return totalPaid / quantity;
}

// Total correspondiente a [quantity] unidades al precio por unidad entera.
double totalForQuantity({required double pricePerUnit, required double quantity}) =>
    pricePerUnit * quantity;
