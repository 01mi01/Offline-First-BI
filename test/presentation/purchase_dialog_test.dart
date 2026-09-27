import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
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

void main() {
  late AppDatabase db;

  setUpAll(() {
    // Evita que GoogleFonts intente descargar la fuente por red durante las
    // pruebas (bloqueado por el entorno de pruebas de Flutter).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.materials).insert(
      MaterialsCompanion.insert(
        name: 'Tela',
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

      // Selecciona el proveedor por defecto ("Sin nombre")
      await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin nombre').last);
      await tester.pumpAndSettle();

      // Abre la hoja para agregar un material
      await tester.ensureVisible(find.text('Agregar'));
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      expect(find.text('Agregar material'), findsOneWidget);

      // Selecciona el material existente. La hoja anidada se apila sobre el
      // diálogo de compra, cuyos propios dropdowns (Proveedor/Ubicación/
      // Evento) siguen montados debajo, así que el dropdown de esta hoja es
      // el último en el árbol, no el primero.
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
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

      await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin nombre').last);
      await tester.pumpAndSettle();

      // Cambia el switch a "gasto general"
      await tester.tap(find.byType(Switch));
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

      final material = await (db.select(
        db.materials,
      )..where((m) => m.id.equals(1))).getSingle();
      expect(material.stock, 100); // sin cambios
    },
  );
}
