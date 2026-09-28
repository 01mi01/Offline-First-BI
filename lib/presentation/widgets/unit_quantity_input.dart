import 'package:flutter/material.dart';
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
