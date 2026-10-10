import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../config/rounding.dart';
import 'app_controls.dart';
import 'app_group.dart';
import 'app_style.dart';
import 'linked_price_fields.dart';
import 'unit_quantity_input.dart';

// Cantidad de un envase con fracciones simples y envases completos. Misma
// lógica que FractionQuantityPicker.
class AppFractionPicker extends StatelessWidget {
  final String unit;
  final double value;
  final ValueChanged<double> onChanged;
  final String label;

  const AppFractionPicker({
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

    return AppSection(
      header: '$label ($unit)',
      footer: value > 0
          ? 'Total: ${formatNumber(cleanFloat(value))} ${unitLabel(unit, value)}'
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          child: AppSegmented<double>(
            segments: [
              for (final (fraction, text) in _presets) AppSegment(fraction, text),
            ],
            selected: selectedPreset,
            onChanged: (fraction) {
              if (fraction != null) _selectPreset(fraction, whole);
            },
          ),
        ),
        AppRow(
          title: 'Envases completos',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$whole',
                key: const ValueKey('container-whole-count'),
                style: AppText.rowTitle(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              AppStepper(
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
class AppWholeNumberRow extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helper;
  final bool allowZero;
  final String? Function(int quantity)? extraValidator;

  const AppWholeNumberRow({
    super.key,
    required this.controller,
    required this.label,
    this.hint = '0',
    this.helper,
    this.allowZero = false,
    this.extraValidator,
  });

  @override
  State<AppWholeNumberRow> createState() => _AppWholeNumberRowState();
}

class _AppWholeNumberRowState extends State<AppWholeNumberRow> {
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
            child: Text(widget.label, style: AppText.rowTitle(context)),
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
              style: AppText.rowTitle(context),
              onChanged: (_) {
                if (_rejectedDecimal) setState(() => _rejectedDecimal = false);
              },
              decoration: appFieldDecoration(
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
// LinkedPriceFields), en dos filas.
class AppLinkedPriceRows extends StatelessWidget {
  final LinkedPriceController controller;
  final VoidCallback onChanged;
  final String priceLabel;
  final String totalLabel;

  const AppLinkedPriceRows({
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
        AppTextFieldRow(
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
          indent: AppMetrics.dividerIndent,
          color: AppColors.separator,
        ),
        AppTextFieldRow(
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
