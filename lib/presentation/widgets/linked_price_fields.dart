import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../application/form_validation.dart';
import '../../application/material_pricing.dart';
import '../../config/rounding.dart';
import '../../theme/app_theme.dart';
import 'form_widgets.dart';

const String priceInfoMessage =
    'Puedes ingresar el precio por unidad o el total pagado, el otro se '
    'calculará automáticamente.';
const String measureUnitInfoMessage =
    'Este precio corresponde a una unidad completa de medida, por ejemplo un '
    'metro o un litro.';

enum PriceSource { perUnit, total }

String _display(double value) => fixed2(value);

class LinkedPriceController {
  final TextEditingController price;
  final TextEditingController total = TextEditingController();
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

  void priceTyped() {
    source = PriceSource.perUnit;
    _syncTotal();
  }

  void totalTyped() {
    source = PriceSource.total;
    _syncPrice();
  }

  void setQuantity(double value) {
    quantity = value;
    if (source == PriceSource.perUnit) {
      _syncTotal();
    } else {
      _syncPrice();
    }
  }

  void setPrice(double? value) {
    source = PriceSource.perUnit;
    price.text = value == null ? '' : fixed2(value);
    _syncTotal();
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d*'),
);

class LinkedPriceFields extends StatelessWidget {
  final LinkedPriceController controller;
  final VoidCallback onChanged;
  final String priceLabel;
  final String? extraInfo;

  const LinkedPriceFields({
    super.key,
    required this.controller,
    required this.onChanged,
    this.priceLabel = 'Precio por unidad',
    this.extraInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(
          label: priceLabel,
          builder: (labelText) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: controller.price,
            keyboardType: TextInputType.number,
            inputFormatters: [_decimalFormatter],
            decoration: InputDecoration(labelText: labelText, hintText: '0.00'),
            onChanged: (_) {
              controller.priceTyped();
              onChanged();
            },
            validator: (v) {
              if (controller.source != PriceSource.perUnit) return null;
              return validateAmountField(v);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        LabeledField(
          label: 'Total pagado (Bs.)',
          builder: (labelText) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: controller.total,
            keyboardType: TextInputType.number,
            inputFormatters: [_decimalFormatter],
            decoration: InputDecoration(labelText: labelText, hintText: '0.00'),
            onChanged: (_) {
              controller.totalTyped();
              onChanged();
            },
            validator: (v) {
              if (controller.source != PriceSource.total) return null;
              final error = validateAmountField(v);
              if (error != null) return error;
              if (controller.quantity <= 0) {
                return 'Indica la cantidad para calcular el precio';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}
