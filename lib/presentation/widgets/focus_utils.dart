import 'package:flutter/widgets.dart';

// Quita el foco del campo de texto activo (y con él el teclado) antes de abrir
// un diálogo, un selector de fecha o una hoja inferior.
//
// Si no se hace, Flutter le devuelve el foco al campo que lo tenía cuando esa
// ruta se cierra, y el teclado reaparece sin que la persona haya tocado ningún
// campo. Así, el teclado solo se muestra cuando la persona enfoca un campo.
void dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}
