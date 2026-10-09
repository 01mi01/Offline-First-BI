import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// Estilo plano y minimalista (hoy solo en Inventario): fondo blanco liso, casi
// sin tarjetas, filas separadas por una línea fina, campos con relleno neutro y
// botones totalmente redondeados.
//
// Se activa envolviendo una pantalla en [FlatStyle]. Dentro:
//  - el tema cambia (ver flatThemeOf en app_theme.dart): campos, botones
//    secundarios y divisores;
//  - los widgets compartidos que tienen variante plana (filtros, selector con
//    búsqueda, campos con etiqueta, botones de formulario...) la usan.
// Fuera de [FlatStyle] nada cambia, así el resto de la app se ve igual hasta
// que se decida extender el estilo.
//
// Piezas del estilo (todas en lib/presentation/widgets/):
//  - flat_style.dart    FlatStyle (este archivo)
//  - flat_list.dart     FlatListRow, FlatThumb, FlatStatusPill, FlatSectionHeader,
//                       FlatEmptyState, FlatTile, FlatFab
//  - flat_controls.dart FlatViewToggle, FlatTabBar
//  - flat_form.dart     LabeledField, FlatFormActions, FlatToggleRow,
//                       FormErrorBox, FlatPhotoSlot
class FlatStyle extends StatelessWidget {
  final Widget child;

  const FlatStyle({super.key, required this.child});

  // ¿Se está dentro de una pantalla con estilo plano?
  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FlatScope>() != null;

  @override
  Widget build(BuildContext context) {
    if (isActive(context)) return child;
    return _FlatScope(
      child: Theme(data: flatThemeOf(Theme.of(context)), child: child),
    );
  }
}

// Marca que el subárbol usa el estilo plano. Es un InheritedTheme para que las
// hojas inferiores y los diálogos abiertos desde una pantalla plana (que
// copian los temas del contexto que los abre) también lo conserven.
class _FlatScope extends InheritedTheme {
  const _FlatScope({required super.child});

  @override
  bool updateShouldNotify(_FlatScope oldWidget) => false;

  @override
  Widget wrap(BuildContext context, Widget child) => _FlatScope(child: child);
}
