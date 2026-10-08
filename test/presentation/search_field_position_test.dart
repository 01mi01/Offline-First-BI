import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/materials_page.dart';
import 'package:offline_first_bi/presentation/pages/reports_page.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// Con el teclado abierto, un buscador con resultados debajo no se mueve al
// escribir ni al aparecer los resultados: lo escrito siempre queda a la vista
// por encima del teclado y los resultados se abren debajo del campo.
void main() {
  const screen = Size(360, 640);
  const keyboard = 300.0;
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (var i = 0; i < 30; i++) {
      await db.into(db.locations).insert(
        LocationsCompanion.insert(city: 'Zona $i', country: 'Bolivia'),
      );
      await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Cliente $i'));
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Producto $i',
          priceA: 1,
          priceB: 1,
          stock: const Value(5),
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: lightTheme, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  void openKeyboard(WidgetTester tester) {
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);
  }

  // Deja pasar el instante que el buscador espera (tras enfocar o cambiar el
  // teclado) antes de llevarse a la vista, y la animación que sigue.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  // Escribe en el campo y comprueba que no se movió, que sigue sobre el
  // teclado y que los resultados están debajo, también sobre el teclado.
  Future<void> typeAndCheck(
    WidgetTester tester,
    Finder field, {
    required String first,
    required String second,
    required Finder results,
  }) async {
    // El campo se toca estando a la vista (como lo haría quien lo usa).
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await settle(tester);
    final atFocus = tester.getRect(field);
    await tester.enterText(field, first);
    await settle(tester);
    final before = tester.getRect(field);
    // Empezar a escribir (y que aparezcan los resultados) no lo mueve.
    expect(before, atFocus);
    expect(before.top, greaterThanOrEqualTo(0));
    expect(before.bottom, lessThanOrEqualTo(screen.height - keyboard));
    expect(results, findsWidgets);
    expect(tester.getRect(results.first).top, greaterThanOrEqualTo(before.bottom));
    expect(tester.getRect(results.first).bottom, lessThanOrEqualTo(screen.height - keyboard));

    // Seguir escribiendo (cambia la lista de resultados) no mueve el campo.
    await tester.enterText(field, second);
    await settle(tester);
    expect(tester.getRect(field), before);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Reportes: typing in the Ubicación search keeps the field in place, above the keyboard', (
    tester,
  ) async {
    await pump(tester, const ReportsPage());
    // Tocar el chip abre el buscador en línea (que toma el foco), y entonces
    // sube el teclado.
    // (en una pantalla chica el panel de filtros se desplaza por dentro)
    await tester.ensureVisible(find.text('Ubicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubicación'));
    await tester.pumpAndSettle();
    openKeyboard(tester);
    await settle(tester);

    await typeAndCheck(
      tester,
      find.descendant(
        of: find.byType(SearchablePickerField<int>),
        matching: find.byType(TextField),
      ),
      first: 'zona 1',
      second: 'zona 2',
      results: find.text('Zona 1, Bolivia'),
    );
  });

  testWidgets('Sale form: Cliente search keeps its place and the results open below it', (
    tester,
  ) async {
    await pump(tester, const Scaffold(body: SaleDialog()));
    openKeyboard(tester);
    await tester.pumpAndSettle();
    final picker = find.byType(SearchablePickerField<int>).first;
    await typeAndCheck(
      tester,
      find.descendant(of: picker, matching: find.byType(TextField)),
      first: 'cliente 1',
      second: 'cliente 2',
      results: find.descendant(of: picker, matching: find.text('Cliente 1')),
    );
  });

  testWidgets('Sale form: the product search keeps its place and its results are above the keyboard', (
    tester,
  ) async {
    await pump(tester, const Scaffold(body: SaleDialog()));
    openKeyboard(tester);
    await tester.pumpAndSettle();
    await typeAndCheck(
      tester,
      find.widgetWithText(TextField, 'Buscar producto'),
      first: 'producto 1',
      second: 'producto 2',
      results: find.text('Producto 1'),
    );
  });

  testWidgets('Materiales > Registro de uso: the Producto search keeps its place', (
    tester,
  ) async {
    await pump(tester, const Scaffold(body: MaterialsUsageTab()));
    openKeyboard(tester);
    await tester.pumpAndSettle();
    await typeAndCheck(
      tester,
      find.byType(TextField),
      first: 'producto 1',
      second: 'producto 2',
      results: find.text('Producto 1'),
    );
  });

  // Al llevar el campo al borde de arriba del área que se desplaza, su etiqueta
  // (que flota sobre el borde y sobresale de la caja) queda entera, con margen.
  testWidgets('a search field scrolled to the top keeps its whole label visible, with a margin', (
    tester,
  ) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final listKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          appBar: AppBar(title: const Text('Encabezado')),
          body: SingleChildScrollView(
            key: listKey,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              for (var i = 0; i < 12; i++) SizedBox(height: 80, child: Text('Fila $i')),
              SearchablePickerField<int>(
                label: 'Ubicación',
                searchHint: 'Buscar ubicación',
                value: null,
                options: [
                  const PickerOption<int>(null, 'Sin ubicación'),
                  for (var i = 0; i < 6; i++)
                    PickerOption<int>(i, 'La Paz, Bolivia', subtitle: 'Calacoto $i'),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(SearchablePickerField<int>),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await settle(tester);
    openKeyboard(tester);
    await settle(tester);
    await tester.enterText(field, 'calacoto');
    await settle(tester);

    final viewportTop = tester.getTopLeft(find.byKey(listKey)).dy;
    final labelTop = tester.getTopLeft(find.text('Ubicación')).dy;
    // La etiqueta entera, con margen, bajo el encabezado.
    expect(labelTop, greaterThanOrEqualTo(viewportTop + 4));
    // Lo escrito sigue sobre el teclado y los resultados debajo del campo.
    final fieldRect = tester.getRect(field);
    expect(fieldRect.bottom, lessThanOrEqualTo(screen.height - keyboard));
    expect(tester.getTopLeft(find.text('Calacoto 0')).dy, greaterThan(fieldRect.bottom - 1));
    expect(tester.takeException(), isNull);
  });
}
