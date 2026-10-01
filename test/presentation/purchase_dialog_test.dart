import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/widgets/unit_quantity_input.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

Future<void> _openPurchaseDialog(WidgetTester tester, AppDatabase db) async {
  // Usa un tamaño de pantalla realista (tipo teléfono) en vez del lienzo de
  // prueba por defecto (800x600), que dispara el ancho máximo de 640 que
  // Flutter aplica a los bottom sheets en pantallas anchas y no representa
  // ningún teléfono real.
  tester.view.physicalSize = const Size(412, 915);
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

Future<int> _defaultSupplierId(AppDatabase db) async {
  final row = await (db.select(
    db.suppliers,
  )..where((s) => s.name.equals(AppDatabase.defaultSupplierName))).getSingle();
  return row.id;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final unit = await (db.select(
      db.units,
    )..where((u) => u.name.equals('unidad'))).getSingle();
    await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Tela',
        unitId: unit.id,
        pricePerUnit: 4.0,
        stock: const Value(100.0),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'registering a material purchase computes the total via '
    'PurchaseRepository.calculateMaterialsTotal, not the dialog, and updates stock',
    (tester) async {
      await _openPurchaseDialog(tester, db);

      expect(find.text('Nueva compra'), findsOneWidget);

      // No se elige proveedor: la compra no debe quedar bloqueada y se asigna
      // al proveedor por defecto "Sin proveedor".

      // Abre la hoja para agregar un material
      await tester.ensureVisible(find.text('Agregar'));
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      expect(find.text('Agregar material'), findsOneWidget);

      // Selecciona el material existente. La hoja anidada se apila sobre el
      // diálogo de compra, cuyos propios dropdowns (Proveedor/Ubicación/
      // Evento) siguen montados debajo, así que el dropdown de esta hoja es
      // el último en el árbol, no el primero.
      await tester.tap(find.byType(SearchablePickerField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tela').last);
      await tester.pumpAndSettle();

      // Cantidad
      await tester.enterText(find.widgetWithText(TextFormField, '0').first, '3');
      await tester.pumpAndSettle();

      // Confirma el material (segundo botón "Agregar", dentro de la hoja)
      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();

      // De regreso en el diálogo principal: el total se calculó automáticamente
      // (3 * 4.0 = 12), sin que el diálogo haga el cálculo por su cuenta.
      expect(find.text('12'), findsOneWidget);

      // Registra la compra
      await tester.ensureVisible(find.text('Registrar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();

      expect(find.byType(PurchaseDialog), findsNothing);

      final repository = PurchaseRepository(db);
      final purchases = await repository.getAll();
      expect(purchases, hasLength(1));
      expect(purchases.first.isMaterial, isTrue);
      expect(purchases.first.totalAmount, 12.0);
      expect(
        purchases.first.supplierId,
        await _defaultSupplierId(db),
        reason: 'sin proveedor elegido se asigna "Sin proveedor"',
      );

      final material = await (db.select(
        db.materials,
      )..where((m) => m.id.equals(1))).getSingle();
      expect(material.stock, 103); // 100 + 3
    },
  );

  testWidgets(
    'registering a general expense purchase does not touch material stock',
    (tester) async {
      await _openPurchaseDialog(tester, db);

      // Cambia a "Gasto general"
      await tester.tap(find.text('Gasto general'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ej: transporte, entradas a eventos, etc.'),
        'Transporte',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '0'), '50');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Registrar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();

      expect(find.byType(PurchaseDialog), findsNothing);

      final repository = PurchaseRepository(db);
      final purchases = await repository.getAll();
      expect(purchases, hasLength(1));
      expect(purchases.first.isMaterial, isFalse);
      expect(purchases.first.totalAmount, 50.0);
      expect(purchases.first.supplierId, await _defaultSupplierId(db));

      final material = await (db.select(
        db.materials,
      )..where((m) => m.id.equals(1))).getSingle();
      expect(material.stock, 100); // sin cambios
    },
  );

  testWidgets(
    'the form does not require a supplier: no "Selecciona un proveedor" '
    'error is shown when submitting without one',
    (tester) async {
      await _openPurchaseDialog(tester, db);

      await tester.tap(find.text('Gasto general'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ej: transporte, entradas a eventos, etc.'),
        'Pasajes',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '0'), '20');
      await tester.ensureVisible(find.text('Registrar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();

      expect(find.text('Selecciona un proveedor'), findsNothing);
      expect(find.byType(PurchaseDialog), findsNothing);
    },
  );

  testWidgets(
    'an explicitly picked supplier is kept, not replaced by "Sin proveedor"',
    (tester) async {
      final chosenId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'Prov Uno'));

      await _openPurchaseDialog(tester, db);

      await tester.tap(find.byType(SearchablePickerField<int>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prov Uno').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gasto general'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ej: transporte, entradas a eventos, etc.'),
        'Pasajes',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '0'), '20');
      await tester.ensureVisible(find.text('Registrar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar compra'));
      await tester.pumpAndSettle();

      final purchases = await PurchaseRepository(db).getAll();
      expect(purchases, hasLength(1));
      expect(purchases.first.supplierId, chosenId);
    },
  );

  group('purchase quantity field: decimals per unit type', () {
    Future<void> addMaterial(String name, String unitName) async {
      final unit = await (db.select(
        db.units,
      )..where((u) => u.name.equals(unitName))).getSingle();
      await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: name,
          unitId: unit.id,
          pricePerUnit: 4.0,
          stock: const Value(10.0),
        ),
      );
    }

    // Abre la hoja "Agregar material" y elige el material indicado.
    Future<Finder> openAddSheetWith(WidgetTester tester, String material) async {
      await _openPurchaseDialog(tester, db);
      await tester.ensureVisible(find.text('Agregar'));
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SearchablePickerField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(material).last);
      await tester.pumpAndSettle();

      // Primer TextFormField de la hoja con hint "0" = cantidad.
      return find.widgetWithText(TextFormField, '0').first;
    }

    Future<void> expectDecimalRejected(
      WidgetTester tester,
      Finder quantity,
    ) async {
      // El usuario escribe "2" y luego intenta el punto de "2.5".
      await tester.enterText(quantity, '2');
      await tester.pump();
      await tester.enterText(quantity, '2.');
      await tester.pump();

      final text = tester.widget<TextFormField>(quantity).controller!.text;
      expect(text, '2', reason: 'el "." no debe registrarse ni fundirse en "25"');
      expect(find.text(wholeNumberOnlyMessage), findsOneWidget);
    }

    testWidgets('unidad rejects a decimal with visible feedback', (tester) async {
      // "Tela" (unidad) ya existe en el setUp.
      final quantity = await openAddSheetWith(tester, 'Tela');
      expect(find.text('Cantidad (unidad)'), findsOneWidget);
      await expectDecimalRejected(tester, quantity);
    });

    testWidgets('contenedor rejects a decimal with visible feedback', (
      tester,
    ) async {
      await addMaterial('Pintura', 'contenedor');
      final quantity = await openAddSheetWith(tester, 'Pintura');
      expect(find.text('Cantidad (contenedor)'), findsOneWidget);
      await expectDecimalRejected(tester, quantity);
    });

    testWidgets('metro (medida continua) still accepts a plain decimal', (
      tester,
    ) async {
      await addMaterial('Cinta', 'metro');
      final quantity = await openAddSheetWith(tester, 'Cinta');
      expect(find.text('Cantidad (metro)'), findsOneWidget);

      await tester.enterText(quantity, '3.5');
      await tester.pump();

      expect(tester.widget<TextFormField>(quantity).controller!.text, '3.5');
      expect(find.text(wholeNumberOnlyMessage), findsNothing);
    });
  });
}
