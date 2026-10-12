import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_buttons.dart';

// Piezas comunes de los formularios (crear y editar): campo con su etiqueta,
// selector de fecha, desplegable con alto limitado, interruptor de estado,
// foto y botones de abajo. Los campos toman su aspecto de [AppFormTheme].

// Campo con su etiqueta: un texto pequeño y tenue ENCIMA del campo. [builder]
// recibe siempre `null` como `labelText` (el campo no lleva etiqueta flotante).
//
//   LabeledField(
//     label: 'Nombre',
//     builder: (_) => TextFormField(
//       decoration: const InputDecoration(hintText: '...'),
//     ),
//   )
class LabeledField extends StatelessWidget {
  final String label;
  final Widget Function(String? labelText) builder;
  final double inset;
  final bool hidden;

  const LabeledField({
    super.key,
    required this.label,
    required this.builder,
    this.inset = AppSpacing.s4,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    if (hidden) return builder(null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: math.max(0.0, inset - AppSpacing.s4)),
          child: FormSectionLabel(label),
        ),
        const SizedBox(height: AppSpacing.s6),
        builder(null),
      ],
    );
  }
}

// Título de una sección de un formulario (p. ej. "Carrito"): el mismo texto
// pequeño y tenue que la etiqueta de un campo.
class FormSectionLabel extends StatelessWidget {
  final String text;

  const FormSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Campo que muestra una fecha y abre un selector al tocarlo. Sin fecha muestra
// [hint]; con [onClear] se puede quitar la fecha elegida.
class AppDateField extends StatelessWidget {
  final String label;
  final String? valueText;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? errorText;

  const AppDateField({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.hint = 'Seleccionar',
    this.onClear,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final text = valueText;
    return LabeledField(
      label: label,
      builder: (_) => InkWell(
        borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
        onTap: onTap,
        child: InputDecorator(
          isEmpty: text == null,
          baseStyle: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.cyanDark,
              size: 20,
            ),
            suffixIcon: text != null && onClear != null
                ? IconButton(
                    tooltip: 'Quitar fecha',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    onPressed: onClear,
                  )
                : null,
          ),
          child: Text(text ?? ''),
        ),
      ),
    );
  }
}

// Opción de un [AppDropdownField]. [value] puede ser null (p. ej. "Sin
// categoría").
class DropdownOption<T> {
  final T? value;
  final String label;

  const DropdownOption(this.value, this.label);
}

// Desplegable de un formulario, con el aspecto de los demás campos. La lista
// abierta mide lo mismo que el campo y tiene un alto máximo: con muchas
// opciones se desplaza dentro de ese alto en vez de salirse de la pantalla.
class AppDropdownField<T> extends FormField<T> {
  AppDropdownField({
    super.key,
    required String label,
    required T? value,
    required List<DropdownOption<T>> options,
    required ValueChanged<T?>? onChanged,
    super.validator,
    String? hint,
    String? helperText,
  }) : super(
         initialValue: value,
         autovalidateMode: AutovalidateMode.onUserInteraction,
         builder: (state) {
           final selected = options
               .where((o) => o.value == state.value)
               .firstOrNull;
           return LabeledField(
             label: label,
             builder: (_) => LayoutBuilder(
               builder: (context, constraints) => PopupMenuButton<int>(
                 enabled: onChanged != null,
                 tooltip: label,
                 position: PopupMenuPosition.under,
                 constraints: BoxConstraints(
                   minWidth: constraints.maxWidth,
                   maxWidth: constraints.maxWidth,
                   maxHeight: AppMetrics.menuMaxHeight,
                 ),
                 color: AppColors.surface,
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
                 ),
                 onSelected: (i) {
                   state.didChange(options[i].value);
                   onChanged?.call(options[i].value);
                 },
                 itemBuilder: (context) => [
                   for (var i = 0; i < options.length; i++)
                     CheckedPopupMenuItem<int>(
                       value: i,
                       checked: options[i].value == state.value,
                       child: Text(options[i].label),
                     ),
                 ],
                 child: InputDecorator(
                   isEmpty: selected == null,
                   baseStyle: Theme.of(
                     context,
                   ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
                   decoration: InputDecoration(
                     hintText: hint,
                     helperText: helperText,
                     errorText: state.errorText,
                     suffixIcon: const Icon(
                       Icons.unfold_more_rounded,
                       color: AppColors.textSecondary,
                     ),
                   ),
                   child: Text(
                     selected?.label ?? '',
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                 ),
               ),
             ),
           );
         },
       );
}

// Botón cuadrado junto a un campo (p. ej. "agregar ubicación nueva").
class AppFieldAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const AppFieldAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.cyanSoft,
        borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
          onTap: onPressed,
          child: SizedBox(
            width: AppMetrics.minTap + AppSpacing.s8,
            height: AppMetrics.minTap + AppSpacing.s8,
            child: Icon(icon, color: AppColors.cyanDark, size: 22),
          ),
        ),
      ),
    );
  }
}

// Botones de abajo de un formulario: la acción principal (crear, guardar,
// registrar) arriba y, debajo, salir sin cambiar nada.
class FormActions extends StatelessWidget {
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  const FormActions({
    super.key,
    this.secondaryLabel = 'Cancelar',
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(onPressed: onPrimary, child: Text(primaryLabel)),
        const SizedBox(height: AppButtons.stackGap),
        AppActionButton(
          label: secondaryLabel,
          kind: AppButtonKind.neutral,
          onPressed: onSecondary,
        ),
      ],
    );
  }
}

// Fila con título, aclaración y un interruptor (p. ej. "Producto activo"), con
// el mismo aspecto de caja que los campos.
class AppToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
        border: Border.all(color: AppColors.border),
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
            activeThumbColor: AppColors.cyanDark,
            inactiveTrackColor: AppColors.border,
            inactiveThumbColor: AppColors.surface,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

// Marcador para elegir la foto de un producto o una categoría: la imagen
// elegida, o un cuadro neutro con el icono de cámara (también si el archivo de
// la imagen ya no existe).
class AppPhotoSlot extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onTap;

  const AppPhotoSlot({super.key, required this.imagePath, required this.onTap});

  static const double size = 100;

  Widget _placeholder() => Container(
    width: size,
    height: size,
    color: AppColors.surface,
    child: const Icon(
      Icons.add_a_photo_rounded,
      color: AppColors.cyanDark,
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
