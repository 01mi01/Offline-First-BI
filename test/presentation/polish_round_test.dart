import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/unit_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/pages/materials_page.dart';
import 'package:offline_first_bi/presentation/pages/products_page.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

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

      await material('Tela', 'metro');
      await material('Botones', 'unidad');
    }

    Future<void> openPurchase(WidgetTester tester, {Size size = const Size(412, 915)}) async {
      setScreen(tester, size);
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
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SearchablePickerField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(material).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '0').first, quantity);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
    }

    testWidgets('2. each line shows its quantity with the unit name, agreed with the amount', (
      tester,
    ) async {
      await seedMaterials();
      await openPurchase(tester);

      await addLine(tester, 'Tela', '2');
      expect(find.text('2 metros'), findsOneWidget);

      await addLine(tester, 'Botones', '1');
      expect(find.text('1 unidad'), findsOneWidget);

      // El botón "+" sube la cantidad y la unidad concuerda con el nuevo número.
      final plus = find.descendant(
        of: find.ancestor(of: find.text('1 unidad'), matching: find.byType(Wrap)),
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(find.text('2 unidades'), findsOneWidget);
    });

    testWidgets('4. "Registrar compra" fits on a single line', (tester) async {
      await openPurchase(tester);

      final label = find.text('Registrar compra');
      final fontSize = tester
          .widget<Text>(label)
          .style!
          .fontSize!;
      expect(tester.getSize(label).height, lessThan(fontSize * 1.8));
      // Y sigue dentro del botón.
      final button = tester.getRect(find.widgetWithText(ElevatedButton, 'Registrar compra'));
      expect(button.contains(tester.getRect(label).topLeft), isTrue);
      expect(button.contains(tester.getRect(label).bottomRight), isTrue);
    });

    testWidgets('5. with the keyboard open the scrollable area is roomier, title and buttons stay pinned', (
      tester,
    ) async {
      await openPurchase(tester);
      final scroll = find.descendant(
        of: find.byType(PurchaseDialog),
        matching: find.byType(SingleChildScrollView),
      );
      final titleBefore = tester.getTopLeft(find.text('Nueva compra'));

      tester.view.viewInsets = const FakeViewPadding(bottom: 350);
      await tester.pumpAndSettle();

      final height = tester.getSize(scroll.first).height;
      // Margen razonable de desplazamiento con el teclado abierto en 412x915.
      expect(height, greaterThan(280));
      // El título no se mueve por abrir el teclado y los botones siguen a la vista.
      expect(tester.getTopLeft(find.text('Nueva compra')).dx, titleBefore.dx);
      final buttons = tester.getRect(find.widgetWithText(ElevatedButton, 'Registrar compra'));
      expect(buttons.bottom, lessThanOrEqualTo(915 - 350));
      expect(buttons.top, greaterThan(tester.getRect(scroll.first).bottom));
    });
  });

  group('3. botón flotante en las listas', () {
    testWidgets('the last product is fully above the floating button at the end of the list', (
      tester,
    ) async {
      setScreen(tester, const Size(412, 915));
      for (var i = 1; i <= 8; i++) {
        await db.into(db.products).insert(
          ProductsCompanion.insert(
            categoryId: 1,
            name: 'Producto $i',
            priceA: 10,
            priceB: 8,
            stock: const Value(5),
          ),
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(theme: lightTheme, home: const ProductsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -10000));
      await tester.pumpAndSettle();

      final fab = tester.getRect(find.byType(FloatingActionButton));
      final lastCardBadge = tester.getRect(find.text('Activo').last);
      expect(lastCardBadge.bottom, lessThan(fab.top));
    });

    test('the shared list padding leaves room for the button plus its margin', () {
      expect(AppSpacing.listWithFab.bottom, greaterThanOrEqualTo(56 + 16));
    });
  });

  group('6. registro de uso', () {
    testWidgets('quantity and price are separate pieces; a price never breaks in the middle', (
      tester,
    ) async {
      setScreen(tester, const Size(412, 915));
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals('contenedor'))).getSingle();
      final productId = await db.into(db.products).insert(
        ProductsCompanion.insert(categoryId: 1, name: 'Acuarela', priceA: 55, priceB: 40),
      );
      final materialId = await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Pintura',
          unitId: unit.id,
          pricePerUnit: 12,
          stock: const Value(10),
        ),
      );
      await db.into(db.productMaterials).insert(
        ProductMaterialsCompanion.insert(
          productId: productId,
          materialId: materialId,
          quantityUsed: 2,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: lightTheme,
            home: const Scaffold(body: MaterialsUsageTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selecciona un producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acuarela').last);
      await tester.pumpAndSettle();

      final quantity = find.text('Cantidad: 2 contenedores');
      final price = find.text('Bs. 12.00 / contenedor');
      expect(quantity, findsOneWidget);
      expect(price, findsOneWidget);
      // El precio completo ocupa una sola línea.
      final fontSize = tester.widget<Text>(price).style!.fontSize!;
      expect(tester.getSize(price).height, lessThan(fontSize * 1.8));
    });
  });

  group('7. un solo rojo', () {
    test('the theme error color is the single app red', () {
      expect(lightTheme.colorScheme.error, AppColors.error);
    });

    test('that red is dark enough for small text on the light surfaces (WCAG AA 4.5:1)', () {
      double lum(Color c) => c.computeLuminance();
      double contrast(Color a, Color b) {
        final l1 = lum(a), l2 = lum(b);
        final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(contrast(AppColors.error, AppColors.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.error, AppColors.background), greaterThanOrEqualTo(4.5));
    });

    test('the code has no other red: no bright red literals and no Colors.red*', () {
      final offenders = <String>[];
      final literal = RegExp(r'0x[Ff][Ff][Ff][Ff]3[Bb]30|Colors\.red|Colors\.deepOrange');
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.g.dart')) continue;
        if (literal.hasMatch(entity.readAsStringSync())) offenders.add(entity.path);
      }
      expect(offenders, isEmpty);
    });

    testWidgets('validation error text uses that red', (tester) async {
      setScreen(tester, const Size(412, 915));
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
      await tester.tap(find.text('Gasto general'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();

      final error = tester.widget<Text>(find.text('Campo requerido').first);
      final color = error.style?.color ?? lightTheme.colorScheme.error;
      expect(color, AppColors.error);
    });
  });
}
