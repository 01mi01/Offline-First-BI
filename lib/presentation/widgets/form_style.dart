import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Aspecto común de los campos de texto: el mismo del inicio de sesión (esquinas
// de [AppMetrics.groupRadius], borde fino, aro cian al enfocar). Un error se ve
// solo como texto rojo pequeño bajo el campo, sin cambiar el borde.
OutlineInputBorder appInputBorder(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppMetrics.groupRadius),
      borderSide: BorderSide(color: color, width: width),
    );

InputDecorationTheme appInputDecorationTheme(BuildContext context) {
  final enabled = appInputBorder(AppColors.border);
  final focused = appInputBorder(AppColors.cyanDark, 2);
  final textTheme = Theme.of(context).textTheme;
  return InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: enabled,
    enabledBorder: enabled,
    disabledBorder: enabled,
    errorBorder: enabled,
    focusedBorder: focused,
    focusedErrorBorder: focused,
    errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.error),
    errorMaxLines: 3,
    helperMaxLines: 3,
    helperStyle: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
  );
}

// Aplica el aspecto común a todos los campos de su subárbol.
class AppFormTheme extends StatelessWidget {
  final Widget child;

  const AppFormTheme({super.key, required this.child});

  // ¿Está este contexto dentro de un formulario con el aspecto común? Los
  // selectores compartidos con otras pantallas (p. ej. los filtros de Reportes)
  // conservan su aspecto fuera de los formularios.
  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FormScope>() != null;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return _FormScope(
      child: Theme(
        data: base.copyWith(
          inputDecorationTheme: appInputDecorationTheme(context),
        ),
        child: child,
      ),
    );
  }
}

class _FormScope extends InheritedWidget {
  const _FormScope({required super.child});

  @override
  bool updateShouldNotify(_FormScope oldWidget) => false;
}

// Error de un formulario que no pertenece a un solo campo (p. ej. "Agrega al
// menos un producto"): el mismo texto rojo pequeño que el error de un campo,
// alineado con el texto de los campos.
class FormErrorText extends StatelessWidget {
  final String message;

  const FormErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.s20,
        right: AppSpacing.s16,
        top: AppSpacing.s6,
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}
