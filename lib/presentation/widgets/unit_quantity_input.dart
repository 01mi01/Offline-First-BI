import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

// Clasificación del comportamiento de entrada de cantidad según el tipo de
// unidad (Units.type, ver app_database.dart): "contenedor" (botella, bolsa...)
// admite fracciones simples porque pensar en decimales no es natural para
// alguien sin formación técnica; "medida" (metro, kg...) y "otros" (comodín)
// usan un número plano.
const String unitTypeContenedor = 'contenedor';
const String unitTypeMedida = 'medida';
const String unitTypeOtros = 'otros';

bool isFractionFriendlyUnitType(String type) => type == unitTypeContenedor;

// Unidades tipo "medida" que, a pesar de admitir un campo numérico plano
// (no fracciones tipo envase), siguen siendo intrínsecamente contables: no
// tiene sentido "2.5 unidades", a diferencia de metro/litro/kg/gramo que sí
// son cantidades continuas reales. Lista chica y explícita a propósito: es
// la única excepción conocida dentro de "medida".
const Set<String> _wholeNumberMedidaUnitNames = {'unidad'};

// Al comprar o consumir materiales en unidades "por pieza" (contenedores, o
// la unidad genérica "unidad") las cantidades son números enteros: no tiene
// sentido comprar "media caja" a un proveedor ni usar "2.5 unidades" en una
// receta. Unidades "medida" continuas (metro, litro, kg, gramo) sí admiten
// decimales.
bool isDiscreteUnit(String type, String name) =>
    type == unitTypeContenedor ||
    _wholeNumberMedidaUnitNames.contains(name.trim().toLowerCase());

// Nombre de la unidad concordado con la cantidad para mostrarlo junto a un
// stock o una cantidad ("1 botella", "5 botellas", "2 unidades"). El símbolo
// "kg" es invariable.
String unitLabel(String name, double quantity) {
  final unit = name.trim();
  if (quantity == 1 || unit.isEmpty) return unit;
  final lower = unit.toLowerCase();
  if (lower == 'kg') return unit;
  return 'aeiou'.contains(lower[lower.length - 1]) ? '${unit}s' : '${unit}es';
}

// Selector de fracciones de un envase (un cuarto / la mitad / tres cuartos /
// entera), para unidades como "botella" donde pensar en decimales no es
// natural para alguien sin formación técnica.
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

  static const _presets = [
    (0.25, 'Un cuarto'),
    (0.5, 'La mitad'),
    (0.75, 'Tres cuartos'),
    (1.0, 'Entera'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ($unit)',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: _presets.map((preset) {
            final (fraction, presetLabel) = preset;
            final selected = value == fraction;
            return GestureDetector(
              onTap: () => onChanged(fraction),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s14,
                  vertical: AppSpacing.s10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  presetLabel,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// Mensaje que se muestra cuando se intenta escribir un decimal en un campo
// que solo admite cantidades enteras.
const String wholeNumberOnlyMessage = 'Solo se admiten números enteros';

final RegExp _digitsOnlyPattern = RegExp(r'^\d*$');

// Formatter para campos de cantidad "por pieza" (unidad, botella...): en vez
// de descartar en silencio los caracteres no numéricos (lo que convertía
// "2.5" en "25" sin avisar), rechaza por completo la edición que los
// introduce —el campo conserva su valor anterior— y avisa mediante
// [onRejected] para que la UI muestre por qué no se registró la tecla.
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

// Campo de cantidad para unidades "por pieza". Rechaza el "." (o ",") con
// feedback visible —mensaje de error bajo el campo y vibración corta— que
// desaparece en cuanto se acepta la siguiente edición. También valida al
// enviar el formulario, por si un valor decimal llegara por otra vía.
class WholeNumberQuantityField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final String? helperText;

  // Si es true el 0 es un valor válido (p. ej. stock inicial); por defecto una
  // cantidad debe ser mayor a 0.
  final bool allowZero;

  // Validación adicional (p. ej. tope de stock) que corre solo cuando el
  // valor ya es un entero positivo válido.
  final String? Function(int quantity)? extraValidator;

  const WholeNumberQuantityField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText = '0',
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
    return TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: widget.controller,
      // Sin la opción decimal el teclado numérico estándar no ofrece el
      // punto; algunos teclados (p. ej. Samsung) lo muestran igual, por eso
      // el formatter es quien realmente lo impide.
      keyboardType: const TextInputType.numberWithOptions(
        decimal: false,
        signed: false,
      ),
      inputFormatters: [WholeNumberInputFormatter(onRejected: _onRejected)],
      onChanged: (_) {
        if (_rejectedDecimal) setState(() => _rejectedDecimal = false);
      },
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
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
    );
  }
}

// Validación de una cantidad entera (usada al enviar el formulario): positiva,
// o con 0 permitido si [allowZero].
String? validateWholeNumberQuantity(String? value, {bool allowZero = false}) {
  if (value == null || value.isEmpty) return 'Campo requerido';
  if (!_digitsOnlyPattern.hasMatch(value)) return wholeNumberOnlyMessage;
  final qty = int.tryParse(value);
  if (qty == null || qty < (allowZero ? 0 : 1)) return 'Cantidad inválida';
  return null;
}
