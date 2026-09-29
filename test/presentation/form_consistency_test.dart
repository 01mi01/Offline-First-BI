import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/event_repository.dart';
import 'package:offline_first_bi/models/client_model.dart';
import 'package:offline_first_bi/models/event_model.dart';
import 'package:offline_first_bi/presentation/dialogs/client_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/event_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/material_dialog.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// Formularios: un mismo comportamiento en toda la app.
//  - El botón de guardar nunca queda desactivado en silencio: si falta algo,
//    el error aparece en el campo ("Campo requerido").
//  - Un error desaparece en cuanto el campo pasa a ser válido, sin reenviar.
//  - El teclado no reaparece solo al cerrar un selector o un diálogo.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openSheet(WidgetTester tester, Widget sheet) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => sheet,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  ElevatedButton submitButton(WidgetTester tester, String label) =>
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, label));

  group('validation style: the submit button is never silently disabled', () {
    testWidgets('client form: "Crear" is enabled from the start', (tester) async {
      await openSheet(tester, const ClientDialog());

      expect(submitButton(tester, 'Crear').onPressed, isNotNull);
    });

    testWidgets('client form: editing an untouched record can still be saved', (
      tester,
    ) async {
      await openSheet(
        tester,
        ClientDialog(
          client: ClientModel(
            id: 99,
            name: 'Maria',
            isActive: true,
            createdAt: DateTime(2024, 1, 1),
          ),
        ),
      );

      expect(submitButton(tester, 'Guardar').onPressed, isNotNull);
    });

    testWidgets('material form: "Crear" is enabled from the start', (tester) async {
      await openSheet(tester, const MaterialDialog());

      expect(submitButton(tester, 'Crear').onPressed, isNotNull);
    });

    testWidgets('event form: "Crear" is enabled from the start', (tester) async {
      await openSheet(tester, const EventDialog());

      expect(submitButton(tester, 'Crear').onPressed, isNotNull);
    });
  });

  group('errors explain themselves and clear as soon as the field is valid', () {
    testWidgets(
      'client form: submitting empty shows "Campo requerido" on the name, '
      'and typing a name removes it without submitting again',
      (tester) async {
        await openSheet(tester, const ClientDialog());
        expect(find.text('Campo requerido'), findsNothing);

        await tester.tap(find.text('Crear'));
        await tester.pumpAndSettle();
        expect(find.text('Campo requerido'), findsOneWidget);

        await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Maria');
        await tester.pump();

        expect(find.text('Campo requerido'), findsNothing);
      },
    );

    testWidgets(
      'typing in one field does not flag the OTHER untouched required fields',
      (tester) async {
        await openSheet(tester, const MaterialDialog());

        await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Hilo');
        await tester.pump();

        expect(find.text('Campo requerido'), findsNothing);
        expect(find.text('Selecciona una unidad'), findsNothing);
      },
    );

    testWidgets(
      'material form: one wording ("Campo requerido", never "Requerido"), and '
      'each error clears when its own field becomes valid',
      (tester) async {
        await openSheet(tester, const MaterialDialog());

        await tester.tap(find.text('Crear'));
        await tester.pumpAndSettle();

        // Nombre, Stock y Precio: todos con el mismo texto.
        expect(find.text('Campo requerido'), findsNWidgets(3));
        expect(find.text('Requerido'), findsNothing);
        expect(find.text('Selecciona una unidad'), findsOneWidget);

        // Unidad: elegir una quita SU error, los demás siguen.
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('metro').last);
        await tester.pumpAndSettle();
        expect(find.text('Selecciona una unidad'), findsNothing);
        expect(find.text('Campo requerido'), findsNWidgets(3));

        // Stock y precio: escribir un valor quita el suyo (caso que dejaba el
        // aviso "Requerido" pegado aunque el campo ya tuviera valor).
        await tester.enterText(find.widgetWithText(TextFormField, 'Stock'), '10');
        await tester.pump();
        expect(find.text('Campo requerido'), findsNWidgets(2));
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Precio por unidad'),
          '1.5',
        );
        await tester.pump();
        expect(find.text('Campo requerido'), findsOneWidget); // solo el nombre
      },
    );

    testWidgets(
      'event form: the "Selecciona la fecha de inicio" notice disappears when '
      'the date is picked',
      (tester) async {
        await openSheet(tester, const EventDialog());

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre del evento'),
          'Feria',
        );
        await tester.tap(find.text('Crear'));
        await tester.pumpAndSettle();
        expect(find.text('Selecciona la fecha de inicio'), findsOneWidget);

        await tester.tap(find.text('Fecha de inicio'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.text('Selecciona la fecha de inicio'), findsNothing);
      },
    );
  });

  group('the keyboard only shows when a field is focused by the person', () {
    testWidgets(
      'closing the date picker does not bring the keyboard back',
      (tester) async {
        await openSheet(tester, const EventDialog());

        // La persona escribe el nombre: el teclado está visible.
        await tester.tap(find.widgetWithText(TextFormField, 'Nombre del evento'));
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);

        // Abre y cancela el selector de fecha.
        await tester.tap(find.text('Fecha de inicio'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(tester.testTextInput.isVisible, isFalse);
        expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<EditableText>()));
      },
    );

    testWidgets(
      'closing the "Desactivar" confirmation does not bring the keyboard back',
      (tester) async {
        final event = await _seedEvent(db);
        await openSheet(tester, EventDialog(event: event));

        await tester.tap(find.widgetWithText(TextFormField, 'Nombre del evento'));
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(find.text('¿Desactivar evento?'), findsOneWidget);
        await tester.tap(find.text('Cancelar').last);
        await tester.pumpAndSettle();

        expect(tester.testTextInput.isVisible, isFalse);
      },
    );

    testWidgets(
      'a field the person taps afterwards still gets the keyboard normally',
      (tester) async {
        await openSheet(tester, const EventDialog());
        await tester.tap(find.widgetWithText(TextFormField, 'Nombre del evento'));
        await tester.pump();
        await tester.tap(find.text('Fecha de inicio'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);

        await tester.tap(find.widgetWithText(TextFormField, 'Notas'));
        await tester.pump();

        expect(tester.testTextInput.isVisible, isTrue);
      },
    );
  });
}

Future<EventModel> _seedEvent(AppDatabase db) async {
  final repository = EventRepository(db);
  await repository.save(name: 'Feria', startDate: DateTime(2024, 3, 5));
  return (await repository.getAll()).single;
}
