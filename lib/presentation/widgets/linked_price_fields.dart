import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../application/material_pricing.dart';
import '../../config/rounding.dart';
import '../../theme/app_theme.dart';

// Precio de un material, para TODOS los tipos de unidad (contenedor, medida y
// otros): dos campos siempre visibles y enlazados, "Precio por unidad" y
// "Total pagado" (por la cantidad que se está registrando). Al escribir en uno
// se calcula el otro; el último en escribirse es el que manda al guardar el
// precio por unidad. Sirve igual para media botella que para medio litro: se
// compra una cantidad rara a un precio que no se conoce por unidad.
const String priceInfoTitle = 'Precio por unidad o total pagado';
const String priceInfoMessage =
    'Puedes ingresar el precio por unidad o el total pagado, el otro se '
    'calculará automáticamente.';
// Aclaración extra para unidades de medida (metro, litro...), en el mismo
// icono: qué es "una unidad".
const String measureUnitInfoMessage =
    'Este precio corresponde a una unidad completa de medida, por ejemplo un '
    'metro o un litro.';

enum PriceSource { perUnit, total }

// El campo calculado se muestra a centavos con dos decimales (13.333... ->
// "13.33", 70 -> "70.00"). Lo que la persona escribió es la fuente: ese valor
// nunca se toca; el campo calculado es solo una vista de él.
String _display(double value) => fixed2(value);

class LinkedPriceController {
  final TextEditingController price;
  final TextEditingController total = TextEditingController();
  // Cantidad a la que corresponde el total (el stock al crear, la cantidad
  // comprada en una compra, o la cantidad indicada al editar).
  double quantity = 0;
  PriceSource source = PriceSource.perUnit;

  LinkedPriceController({TextEditingController? price})
    : price = price ?? TextEditingController();

  void dispose() {
    total.dispose();
  }

  double? _parse(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    return v != null && v > 0 ? v : null;
  }

  // Precio por unidad entera que se guardaría, o null si falta algo.
  // Siempre a centavos (dos decimales) al devolverlo para guardarlo.
  double? get resolvedPrice {
    final raw = source == PriceSource.perUnit
        ? _parse(price)
        : pricePerWholeUnit(totalPaid: _parse(total) ?? 0, quantity: quantity);
    return raw == null ? null : round2(raw);
  }

  void _syncTotal() {
    final p = _parse(price);
    total.text = p != null && quantity > 0
        ? _display(totalForQuantity(pricePerUnit: p, quantity: quantity))
        : '';
  }

  void _syncPrice() {
    final p = pricePerWholeUnit(
      totalPaid: _parse(total) ?? 0,
      quantity: quantity,
    );
    price.text = p != null ? _display(p) : '';
  }

  // La persona escribió el precio por unidad: se calcula el total.
  void priceTyped() {
    source = PriceSource.perUnit;
    _syncTotal();
  }

  // La persona escribió el total pagado: se calcula el precio por unidad.
  void totalTyped() {
    source = PriceSource.total;
    _syncPrice();
  }

  // Cambió la cantidad: se recalcula el campo que NO se escribió último.
  void setQuantity(double value) {
    quantity = value;
    if (source == PriceSource.perUnit) {
      _syncTotal();
    } else {
      _syncPrice();
    }
  }

  // Deja el precio por unidad indicado (de un material existente) y calcula
  // el total para la cantidad actual.
  void setPrice(double? value) {
    source = PriceSource.perUnit;
    price.text = value == null ? '' : fixed2(value);
    _syncTotal();
  }

  void clear() {
    source = PriceSource.perUnit;
    price.clear();
    total.clear();
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d*'),
);

class LinkedPriceFields extends StatelessWidget {
  final LinkedPriceController controller;
  // Se llama tras cada cambio para que quien lo contiene se redibuje.
  final VoidCallback onChanged;
  final String priceLabel;
  final String totalLabel;
  // Aclaración que se suma a la explicación del icono (p. ej. para medidas).
  final String? extraInfo;

  const LinkedPriceFields({
    super.key,
    required this.controller,
    required this.onChanged,
    this.priceLabel = 'Precio por unidad',
    this.totalLabel = 'Total pagado (Bs.)',
    this.extraInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          controller: controller.price,
          keyboardType: TextInputType.number,
          inputFormatters: [_decimalFormatter],
          decoration: InputDecoration(labelText: priceLabel, hintText: '0'),
          onChanged: (_) {
            controller.priceTyped();
            onChanged();
          },
          validator: (v) {
            if (controller.source != PriceSource.perUnit) return null;
            if (v == null || v.isEmpty) return 'Campo requerido';
            if ((double.tryParse(v) ?? 0) <= 0) return 'Precio inválido';
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.s16),
        TextFormField(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          controller: controller.total,
          keyboardType: TextInputType.number,
          inputFormatters: [_decimalFormatter],
          decoration: InputDecoration(labelText: totalLabel, hintText: '0'),
          onChanged: (_) {
            controller.totalTyped();
            onChanged();
          },
          validator: (v) {
            if (controller.source != PriceSource.total) return null;
            if (v == null || v.isEmpty) return 'Campo requerido';
            if ((double.tryParse(v) ?? 0) <= 0) return 'Ingresa lo que pagaste';
            if (controller.quantity <= 0) {
              return 'Indica la cantidad para calcular el precio';
            }
            return null;
          },
        ),
      ],
    );
  }
}
