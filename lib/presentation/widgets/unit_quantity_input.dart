import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../application/form_validation.dart';
import '../../config/quantity_format.dart';
import '../../config/rounding.dart';
import '../../theme/app_theme.dart';
import 'app_controls.dart';
import 'filter_panel.dart' show PresetPill;
import 'form_widgets.dart';
import 'app_style.dart';

const String unitTypeContenedor = 'contenedor';
const String unitTypeMedida = 'medida';

bool isFractionFriendlyUnitType(String type) => type == unitTypeContenedor;

const Set<String> _wholeNumberMedidaUnitNames = wholeNumberUnitNames;

bool isDiscreteUnit(String type, String name) =>
    type == unitTypeContenedor ||
    _wholeNumberMedidaUnitNames.contains(name.trim().toLowerCase());

double combineContainerQuantity(int whole, double fraction) => whole + fraction;

({int whole, double fraction}) splitContainerQuantity(double value) {
  final whole = value.floor();
  return (whole: whole, fraction: value - whole);
}

class FractionQuantityPicker extends StatelessWidget {
  final String unit;
  final double value;
  final ValueChanged<double> onChanged;
  final String label;

  const FractionQuantityPicker({
    super.key,
    required this.unit,
    required this.value,
    required this.onChanged,
    this.label = 'Cantidad',
  });

  static String _wholeUnitsLabel(String unit) {
    final plural = unitLabel(unit, 2);
    if (plural.isEmpty) return 'Unidades completas';
    final name = '${plural[0].toUpperCase()}${plural.substring(1)}';
    return unit.trim().toLowerCase().endsWith('a')
        ? '$name completas'
        : '$name completos';
  }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s6),
          child: Text('$label ($unit)', style: filterLabelStyle(context)),
        ),
        Wrap(
          spacing: AppSpacing.s6,
          children: _presets.map((preset) {
            final (fraction, presetLabel) = preset;
            final selected = fraction >= 1
                ? whole >= 1 && fractionPart == 0
                : fractionPart == fraction;
            return PresetPill(
              label: presetLabel,
              selected: selected,
              onTap: () => _selectPreset(fraction, whole),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: FormSectionLabel(_wholeUnitsLabel(unit)),
            ),
            Text(
              '$whole',
              key: const ValueKey('container-whole-count'),
              style: AppText.rowTitle(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AppSpacing.s8),
            AppStepper(
              minusKey: const ValueKey('container-whole-minus'),
              plusKey: const ValueKey('container-whole-plus'),
              onMinus: whole > 0
                  ? () => onChanged(combineContainerQuantity(whole - 1, fractionPart))
                  : null,
              onPlus: () =>
                  onChanged(combineContainerQuantity(whole + 1, fractionPart)),
            ),
          ],
        ),
        if (value > 0) ...[
          const SizedBox(height: AppSpacing.s6),
          Text(
            'Total: ${quantityWithUnit(value, unit)}',
            key: const ValueKey('container-total'),
            style: AppText.formLabel(context).copyWith(color: AppColors.cyanDark),
          ),
        ],
      ],
    );
  }
}

const String wholeNumberOnlyMessage = 'Solo se admiten números enteros';

final RegExp _digitsOnlyPattern = RegExp(r'^\d*$');

class WholeNumberInputFormatter extends TextInputFormatter {
  final VoidCallback? onRejected;

  const WholeNumberInputFormatter({this.onRejected});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_digitsOnlyPattern.hasMatch(newValue.text)) return newValue;
    onRejected?.call();
    return oldValue;
  }
}

class WholeNumberQuantityField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? helperText;

  final bool allowZero;

  final String? Function(int quantity)? extraValidator;

  const WholeNumberQuantityField({
    super.key,
    required this.controller,
    required this.labelText,
    this.helperText,
    this.allowZero = false,
    this.extraValidator,
  });

  @override
  State<WholeNumberQuantityField> createState() =>
      _WholeNumberQuantityFieldState();
}

class _WholeNumberQuantityFieldState extends State<WholeNumberQuantityField> {
  bool _rejectedDecimal = false;

  void _onRejected() {
    HapticFeedback.lightImpact();
    if (!_rejectedDecimal) setState(() => _rejectedDecimal = true);
  }

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.labelText,
      builder: (labelText) => TextFormField(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        controller: widget.controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: false,
          signed: false,
        ),
        inputFormatters: [WholeNumberInputFormatter(onRejected: _onRejected)],
        onChanged: (_) {
          if (_rejectedDecimal) setState(() => _rejectedDecimal = false);
        },
        decoration: InputDecoration(
          labelText: labelText,
          hintText: '0',
          helperText: widget.helperText,
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
    );
  }
}

String? validateWholeNumberQuantity(String? value, {bool allowZero = false}) {
  if (value == null || value.isEmpty) return requiredMessage;
  if (!_digitsOnlyPattern.hasMatch(value)) return wholeNumberOnlyMessage;
  final qty = int.tryParse(value);
  if (qty == null || qty < (allowZero ? 0 : 1)) return 'Cantidad inválida';
  return null;
}
