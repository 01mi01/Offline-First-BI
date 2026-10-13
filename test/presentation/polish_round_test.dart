
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/unit_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/widgets/app_sheet.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'search_helpers.dart';
import 'form_finders.dart';

// Pulido tras la revisión en el dispositivo: orden de las unidades, unidad en
// las líneas de Compras, botón flotante, botón de registrar, espacio con el
// teclado abierto, etiquetas de precio y un único rojo.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  void setScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  const seedOrder = [
    'contenedor',
    'paquete',
    'rollo',
    'tira',
    'unidad',
    'metro',
    'centímetro',
    'kg',
    'gramo',
    'litro',
    'mililitro',
    'otro',
  ];

  group('1. orden de las unidades', () {
    test('a fresh install lists the units in seed order, not alphabetically', () async {
      final names = (await UnitRepository(db).getAll()).map((u) => u.name).toList();

      expect(names, seedOrder);
      expect(names, isNot(orderedEquals([...names]..sort())));
    });

    test('a migrated install (old ids, new unit appended last) is still shown in seed order', () async {
      // Ids como los que deja la migración: el orden antiguo y "contenedor" al final.
      await db.customStatement('DELETE FROM units');
      const migrated = [
        'paquete',
        'rollo',
        'unidad',
        'metro',
        'litro',
        'kg',
        'gramo',
        'centímetro',
        'mililitro',
        'tira',
        'otro',
        'contenedor',
      ];
      for (final name in migrated) {
        await db.into(db.units).insert(UnitsCompanion.insert(name: name, type: 'medida'));
      }

      final names = (await UnitRepository(db).getAll()).map((u) => u.name).toList();

      expect(names, seedOrder);
    });

    test('a unit outside the seed goes last, by id', () async {
      await db.into(db.units).insert(UnitsCompanion.insert(name: 'zzz', type: 'otros'));
      await db.into(db.units).insert(UnitsCompanion.insert(name: 'aaa', type: 'otros'));

      final names = (await UnitRepository(db).getAll()).map((u) => u.name).toList();

      expect(names.take(12), seedOrder);
      expect(names.skip(12), ['zzz', 'aaa']);
    });
  });

  group('purchase form', () {
    Future<void> seedMaterials() async {
      Future<void> material(String name, String unit) async {
        final u = await (db.select(
          db.units,
        )..where((x) => x.name.equals(unit))).getSingle();
        await db.into(db.materials).insert(
          MaterialsCompanion.insert(
            name: name,
            unitId: u.id,
            pricePerUnit: 4,
            stock: const Value(100),
          ),
        );
      }

      await material('Tela negra', 'metro');
      await material('Base metálica grande para pines', 'unidad');
    }

    // Con [inAppSheet] la hoja se abre como en la app (showAppSheet), que deja
    // sitio al teclado; si no, una hoja simple.
    Future<void> openPurchase(
      WidgetTester tester, {
      Size size = const Size(412, 915),
      bool inAppSheet = false,
    }) async {
      setScreen(tester, size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => inAppSheet
                      ? showAppSheet<void>(
                          context,
                          builder: (_) => const PurchaseDialog(),
                        )
                      : showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const PurchaseDialog(),
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

    Future<void> addLine(WidgetTester tester, String material, String quantity) async {
      await tester.ensureVisible(materialsAddButton());
      await tester.tap(materialsAddButton());
      await tester.pumpAndSettle();
      await pickFromSearch(tester, find.byType(SearchablePickerField<int>).last, material, material);
      await tester.enterText(find.widgetWithText(TextFormField, '0').first, quantity);
      await tester.pumpAndSettle();
      // Los botones van al final del contenido que se desplaza.
      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
    }

    testWidgets('2. each line shows its quantity with the unit name, agreed with the amount', (
      tester,
    ) async {
      await seedMaterials();
      await openPurchase(tester);

      // La línea lleva la cantidad con su unidad y, a su lado, el importe.
      await addLine(tester, 'Tela negra', '2');
      expect(find.textContaining('2.00 metros'), findsOneWidget);

      await addLine(tester, 'Base metálica grande para pines', '1');
      expect(find.textContaining('1 unidad  ·'), findsOneWidget);

      // El botón "+" de la segunda línea sube la cantidad y la unidad concuerda
      // con el nuevo número.
      await tester.tap(find.byTooltip('Agregar uno').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('2 unidades'), findsOneWidget);
    });

  });

}
