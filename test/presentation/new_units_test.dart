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
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'search_helpers.dart';

// Lista simplificada de unidades (12): contenedor, paquete, rollo y tira son
// contenedores (con fracciones); el resto son medidas, más el comodín "otro".
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
    test('a fresh database has exactly the 12 units, with the right types', () async {
      final units = await UnitRepository(db).getAll();
      final byName = {for (final u in units) u.name: u.type};

      expect(units, hasLength(12));
      expect(byName, {
        'contenedor': 'contenedor',
        'paquete': 'contenedor',
        'rollo': 'contenedor',
        'tira': 'contenedor',
        'unidad': 'medida',
        'metro': 'medida',
        'centímetro': 'medida',
        'kg': 'medida',
        'gramo': 'medida',
        'litro': 'medida',
        'mililitro': 'medida',
        'otro': 'otros',
      });
    });

    test('the retired units are no longer seeded', () async {
      final names = (await UnitRepository(db).getAll()).map((u) => u.name).toSet();

      for (final retired in [
        'botella',
        'frasco',
        'lata',
        'bolsa',
        'caja',
        'milímetro',
        'metro cuadrado',
      ]) {
        expect(names, isNot(contains(retired)), reason: retired);
      }
    });
  });

  group('behavior follows the unit type', () {
    test('every container unit is fraction-friendly and discrete', () {
      expect(isFractionFriendlyUnitType(unitTypeContenedor), isTrue);
      for (final name in ['contenedor', 'paquete', 'rollo', 'tira']) {
        expect(isDiscreteUnit(unitTypeContenedor, name), isTrue, reason: name);
      }
    });

    test('the measures take a plain number and allow decimals', () {
      for (final name in ['metro', 'centímetro', 'kg', 'gramo', 'litro', 'mililitro']) {
        expect(isFractionFriendlyUnitType(unitTypeMedida), isFalse, reason: name);
        expect(isDiscreteUnit(unitTypeMedida, name), isFalse, reason: name);
      }
    });

    test('unitLabel agrees the names with the quantity', () {
      expect(unitLabel('tira', 1), 'tira');
      expect(unitLabel('tira', 5), 'tiras');
      expect(unitLabel('tira', 0.5), 'tiras');
      expect(unitLabel('centímetro', 1), 'centímetro');
      expect(unitLabel('centímetro', 2), 'centímetros');
      expect(unitLabel('mililitro', 3), 'mililitros');
      expect(unitLabel('contenedor', 1), 'contenedor');
      expect(unitLabel('contenedor', 5), 'contenedores');
      expect(unitLabel('paquete', 5), 'paquetes');
      expect(unitLabel('rollo', 2), 'rollos');
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
      await pickFromSearch(tester, find.byType(SearchablePickerField<int>).first, 'Acuarela', 'Acuarela');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await pickFromSearch(tester, find.byType(SearchablePickerField<int>).last, materialName, materialName);
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

    testWidgets('metro is a plain decimal field, shown with its plural', (
      tester,
    ) async {
      await material('Tela', 'metro', 3);
      await openUsage(tester, 'Tela');

      expect(find.byType(FractionQuantityPicker), findsNothing);
      expect(find.byType(WholeNumberQuantityField), findsNothing);
      expect(find.text('Stock disponible: 3 metros'), findsOneWidget);

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
