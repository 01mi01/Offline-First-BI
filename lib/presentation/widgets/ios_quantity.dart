import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../config/rounding.dart';
import 'ios_controls.dart';
import 'ios_group.dart';
import 'ios_style.dart';
import 'linked_price_fields.dart';
import 'unit_quantity_input.dart';

// Cantidad de un envase con fracciones simples y envases completos, con el
// estilo iOS. Misma lógica que FractionQuantityPicker.
class IosFractionPicker extends StatelessWidget {
  final String unit;
  final double value;
  final ValueChanged<double> onChanged;
  final String label;

  const IosFractionPicker({
    super.key,
    required this.unit,
    required this.value,
    required this.onChanged,
    this.label = 'Cantidad',
  });

  static const _presets = [
    (0.25, 'Un cuarto'),
    (0.5, 'La mitad'),
    (0.75, 'Tres cuartos'),
    (1.0, 'Entera'),
  ];

  void _selectPreset(double fraction, int whole) {
    if (fraction >= 1) {
      onChanged(combineContainerQuantity(whole < 1 ? 1 : whole, 0));
    } else {
      onChanged(combineContainerQuantity(whole, fraction));
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = splitContainerQuantity(value);
    final whole = parts.whole;
    final fractionPart = parts.fraction;
    double? selectedPreset;
    for (final (fraction, _) in _presets) {
      final selected = fraction >= 1
          ? whole >= 1 && fractionPart == 0
          : fractionPart == fraction;
      if (selected) selectedPreset = fraction;
    }

    return IosSection(
      header: '$label ($unit)',
      footer: value > 0
          ? 'Total: ${formatNumber(cleanFloat(value))} ${unitLabel(unit, value)}'
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          child: IosSegmented<double>(
            segments: [
              for (final (fraction, text) in _presets) IosSegment(fraction, text),
            ],
            selected: selectedPreset,
            onChanged: (fraction) {
              if (fraction != null) _selectPreset(fraction, whole);
            },
          ),
        ),
        IosRow(
          title: 'Envases completos',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$whole',
                key: const ValueKey('container-whole-count'),
                style: IosText.rowTitle(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              IosStepper(
                onMinus: whole > 0
                    ? () => onChanged(
                        combineContainerQuantity(whole - 1, fractionPart),
                      )
                    : null,
                onPlus: () =>
                    onChanged(combineContainerQuantity(whole + 1, fractionPart)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Fila de cantidad para unidades por pieza: solo enteros, con el aviso de
// siempre al intentar escribir un decimal.
class IosWholeNumberRow extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helper;
  final bool allowZero;
  final String? Function(int quantity)? extraValidator;

  const IosWholeNumberRow({
    super.key,
    required this.controller,
    required this.label,
    this.hint = '0',
    this.helper,
    this.allowZero = false,
    this.extraValidator,
  });

  @override
  State<IosWholeNumberRow> createState() => _IosWholeNumberRowState();
}

class _IosWholeNumberRowState extends State<IosWholeNumberRow> {
  bool _rejectedDecimal = false;

  void _onRejected() {
    HapticFeedback.lightImpact();
    if (!_rejectedDecimal) setState(() => _rejectedDecimal = true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s16),
            child: Text(widget.label, style: IosText.rowTitle(context)),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: widget.controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
                signed: false,
              ),
              inputFormatters: [
                WholeNumberInputFormatter(onRejected: _onRejected),
              ],
              textAlign: TextAlign.end,
              style: IosText.rowTitle(context),
              onChanged: (_) {
                if (_rejectedDecimal) setState(() => _rejectedDecimal = false);
              },
              decoration: iosFieldDecoration(
                context,
                hint: widget.hint,
                helper: widget.helper,
              ).copyWith(
                errorText: _rejectedDecimal ? wholeNumberOnlyMessage : null,
              ),
              validator: (v) {
                final error = validateWholeNumberQuantity(
                  v,
                  allowZero: widget.allowZero,
                );
                if (error != null) return error;
                return widget.extraValidator?.call(int.parse(v!));
              },
            ),
          ),
        ],
      ),
    );
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d*'),
);

// Precio por unidad y total pagado enlazados (misma lógica que
// LinkedPriceFields), en dos filas iOS.
class IosLinkedPriceRows extends StatelessWidget {
  final LinkedPriceController controller;
  final VoidCallback onChanged;
  final String priceLabel;
  final String totalLabel;

  const IosLinkedPriceRows({
    super.key,
    required this.controller,
    required this.onChanged,
    this.priceLabel = 'Precio por unidad',
    this.totalLabel = 'Total pagado (Bs.)',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IosTextFieldRow(
          label: priceLabel,
          controller: controller.price,
          hint: '0',
          keyboardType: TextInputType.number,
          inputFormatters: [_decimalFormatter],
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
        const Divider(
          height: 1,
          thickness: 1,
          indent: AppIos.dividerIndent,
          color: AppColors.iosSeparator,
        ),
        IosTextFieldRow(
          label: totalLabel,
          controller: controller.total,
          hint: '0',
          keyboardType: TextInputType.number,
          inputFormatters: [_decimalFormatter],
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
