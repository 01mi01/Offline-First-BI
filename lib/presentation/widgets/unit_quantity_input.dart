import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Unidades comunes ofrecidas al crear/editar un material. La lista es solo
// una sugerencia: el campo sigue siendo de texto libre para no bloquear
// unidades no contempladas aquí.
const List<String> commonMaterialUnits = [
  'unidad',
  'botella',
  'bolsa',
  'paquete',
  'caja',
  'frasco',
  'lata',
  'rollo',
  'metro',
  'litro',
  'kg',
  'gramo',
];

// Unidades tipo "envase": tiene más sentido para alguien sin formación
// técnica pensar en fracciones del envase completo (un cuarto, la mitad...)
// que teclear un decimal exacto. El resto de unidades (metro, litro, kg,
// unidad genérica, etc.) se quedan con un número simple.
const Set<String> _fractionFriendlyUnits = {
  'botella',
  'bolsa',
  'paquete',
  'caja',
  'frasco',
  'lata',
  'rollo',
};

// Unidades "por pieza": al comprar materiales se adquieren en cantidades
// enteras (no tiene sentido comprar "media caja" a un proveedor), así que la
// cantidad de compra se restringe a números enteros para estas unidades.
const Set<String> _discreteUnits = {
  'unidad',
  'botella',
  'bolsa',
  'paquete',
  'caja',
  'frasco',
  'lata',
  'rollo',
};

bool isFractionFriendlyUnit(String unit) =>
    _fractionFriendlyUnits.contains(unit.trim().toLowerCase());

bool isDiscreteUnit(String unit) =>
    _discreteUnits.contains(unit.trim().toLowerCase());

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
