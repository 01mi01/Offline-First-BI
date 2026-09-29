import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/unit_repository.dart';
import 'package:offline_first_bi/presentation/pages/materials_page.dart';
import 'package:offline_first_bi/presentation/widgets/unit_quantity_input.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// Unidades nuevas: centímetro, milímetro, mililitro, metro cuadrado (medidas)
// y tira (contenedor, con fracciones como botella o bolsa).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Acuarela',
        priceA: 55,
        priceB: 40,
        stock: const Value(10),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('seeding', () {
    test('a fresh database has the five new units with the right types', () async {
      final units = await UnitRepository(db).getAll();
      final byName = {for (final u in units) u.name: u.type};

      expect(byName['centímetro'], 'medida');
      expect(byName['milímetro'], 'medida');
      expect(byName['mililitro'], 'medida');
      expect(byName['metro cuadrado'], 'medida');
      expect(byName['tira'], 'contenedor');
    });

    test('the previous units are still there: 18 in total, each name once', () async {
      final units = await UnitRepository(db).getAll();

      expect(units, hasLength(18));
      expect(units.map((u) => u.name).toSet(), hasLength(18));
      for (final name in ['botella', 'bolsa', 'metro', 'litro', 'kg', 'gramo', 'otro']) {
        expect(units.any((u) => u.name == name), isTrue, reason: name);
      }
    });
  });

  group('behavior follows the unit type', () {
    test('tira is fraction-friendly and discrete, like botella', () {
      expect(isFractionFriendlyUnitType(unitTypeContenedor), isTrue);
      expect(isDiscreteUnit(unitTypeContenedor, 'tira'), isTrue);
    });

    test('the new measures take a plain number and allow decimals', () {
      for (final name in ['centímetro', 'milímetro', 'mililitro', 'metro cuadrado']) {
        expect(isFractionFriendlyUnitType(unitTypeMedida), isFalse, reason: name);
        expect(isDiscreteUnit(unitTypeMedida, name), isFalse, reason: name);
      }
    });

    test('unitLabel agrees the new names with the quantity', () {
      expect(unitLabel('tira', 1), 'tira');
      expect(unitLabel('tira', 5), 'tiras');
      expect(unitLabel('tira', 0.5), 'tiras');
      expect(unitLabel('centímetro', 1), 'centímetro');
      expect(unitLabel('centímetro', 2), 'centímetros');
      expect(unitLabel('milímetro', 3), 'milímetros');
      expect(unitLabel('mililitro', 3), 'mililitros');
      // Nombre de dos palabras: concuerdan las dos.
      expect(unitLabel('metro cuadrado', 1), 'metro cuadrado');
      expect(unitLabel('metro cuadrado', 3), 'metros cuadrados');
      // Sin cambios para las de siempre.
      expect(unitLabel('botella', 5), 'botellas');
      expect(unitLabel('kg', 5), 'kg');
    });
  });

  group('in the "Registro de uso" form', () {
    Future<void> material(String name, String unit, double stock) async {
      final u = await (db.select(
        db.units,
      )..where((x) => x.name.equals(unit))).getSingle();
      await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: name,
          unitId: u.id,
          pricePerUnit: 2,
          stock: Value(stock),
        ),
      );
    }

    Future<void> openUsage(WidgetTester tester, String materialName) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(materialName).last);
      await tester.pumpAndSettle();
    }

    testWidgets('tira uses the fraction picker (un cuarto / la mitad / tres cuartos / entera)', (
      tester,
    ) async {
      await material('Cuentas', 'tira', 5);
      await openUsage(tester, 'Cuentas');

      expect(find.byType(FractionQuantityPicker), findsOneWidget);
      for (final preset in ['Un cuarto', 'La mitad', 'Tres cuartos', 'Entera']) {
        expect(find.text(preset), findsOneWidget, reason: preset);
      }
      expect(find.text('Cantidad utilizada (tira)'), findsOneWidget);
      expect(find.text('Stock disponible: 5 tiras'), findsOneWidget);
      // Sin campo de número libre.
      expect(find.byType(WholeNumberQuantityField), findsNothing);
    });

    testWidgets('registering "La mitad" of a tira takes 0.5 from the stock', (
      tester,
    ) async {
      await material('Cuentas', 'tira', 5);
      await openUsage(tester, 'Cuentas');

      await tester.tap(find.text('La mitad'));
      await tester.pump();
      await tester.tap(find.text('Registrar').last);
      await tester.pumpAndSettle();

      final stock = (await db.select(db.materials).getSingle()).stock;
      expect(stock, 4.5);
      expect(find.textContaining('0.5 tiras'), findsOneWidget);
    });

    testWidgets('metro cuadrado is a plain decimal field, shown with its plural', (
      tester,
    ) async {
      await material('Tela', 'metro cuadrado', 3);
      await openUsage(tester, 'Tela');

      expect(find.byType(FractionQuantityPicker), findsNothing);
      expect(find.byType(WholeNumberQuantityField), findsNothing);
      expect(find.text('Stock disponible: 3 metros cuadrados'), findsOneWidget);

      final field = find.widgetWithText(TextFormField, '0');
      await tester.enterText(field, '1.5');
      await tester.pump();
      expect(tester.widget<TextFormField>(field).controller!.text, '1.5');
    });

    testWidgets('centímetro is also a plain decimal field', (tester) async {
      await material('Cinta', 'centímetro', 40);
      await openUsage(tester, 'Cinta');

      expect(find.byType(FractionQuantityPicker), findsNothing);
      expect(find.text('Stock disponible: 40 centímetros'), findsOneWidget);
    });
  });
}
