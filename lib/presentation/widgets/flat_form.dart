import 'dart:io';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'flat_style.dart';

// Piezas de los formularios con estilo plano. Fuera de [FlatStyle] cada una se
// ve como antes, para poder usarlas también en formularios que todavía no
// cambian.

// Campo con su etiqueta. Con estilo plano la etiqueta es un texto pequeño y
// tenue ENCIMA del campo; sin él, es la etiqueta flotante de siempre.
//
// [builder] recibe el `labelText` que debe llevar el campo (null cuando la
// etiqueta va encima):
//
//   LabeledField(
//     label: 'Nombre',
//     builder: (labelText) => TextFormField(
//       decoration: InputDecoration(labelText: labelText, hintText: '...'),
//     ),
//   )
class LabeledField extends StatelessWidget {
  final String label;
  final Widget Function(String? labelText) builder;

  const LabeledField({super.key, required this.label, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (!FlatStyle.isActive(context)) return builder(label);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        builder(null),
      ],
    );
  }
}

// Botones de abajo de un formulario: la acción secundaria (cancelar) a la
// izquierda y la principal (crear, guardar, registrar) a la derecha.
// Principal: cian con texto navy. Secundaria: píldora neutra con estilo plano.
class FlatFormActions extends StatelessWidget {
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String primaryLabel;
  final VoidCallback onPrimary;

  const FlatFormActions({
    super.key,
    this.secondaryLabel = 'Cancelar',
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final flat = FlatStyle.isActive(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onSecondary,
            style: flat
                ? null
                : OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppIos.groupRadius),
                    ),
                    side: const BorderSide(color: AppColors.border),
                  ),
            child: Text(
              secondaryLabel,
              style: TextStyle(
                color: flat ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: ElevatedButton(
            onPressed: onPrimary,
            child: Text(
              primaryLabel,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textButtons,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Fila con título, aclaración y un interruptor (p. ej. "Producto activo").
class FlatToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const FlatToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final flat = FlatStyle.isActive(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: flat ? 0 : AppSpacing.s16,
        vertical: flat ? AppSpacing.s8 : AppSpacing.s12,
      ),
      decoration: flat
          ? const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.hairline),
                bottom: BorderSide(color: AppColors.hairline),
              ),
            )
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryDark,
            inactiveTrackColor: AppColors.border,
            inactiveThumbColor: AppColors.surface,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

// Aviso de error de un formulario: caja suave rosa con el icono rosa y el
// texto navy (nunca texto rosa sobre rosa).
class FormErrorBox extends StatelessWidget {
  final String message;

  const FormErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(AppSpacing.s16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// Marcador para elegir la foto de un producto o una categoría: la imagen
// elegida, o un cuadro neutro con el icono de cámara (también si el archivo de
// la imagen ya no existe).
class FlatPhotoSlot extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onTap;

  const FlatPhotoSlot({super.key, required this.imagePath, required this.onTap});

  static const double size = 100;

  Widget _placeholder() => Container(
    width: size,
    height: size,
    color: AppColors.surface,
    child: const Icon(
      Icons.add_a_photo_outlined,
      color: AppColors.primaryDark,
      size: 32,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppFlat.tileRadius),
          child: imagePath != null
              ? Image.file(
                  File(imagePath!),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
    );
  }
}
