import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/product_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/bi_models.dart';
import 'package:offline_first_bi/presentation/dialogs/event_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/material_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/product_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/categories_page.dart';
import 'package:offline_first_bi/presentation/widgets/app_controls.dart';
import 'package:offline_first_bi/presentation/widgets/bi_insight_widgets.dart';
import 'package:offline_first_bi/presentation/widgets/chart_metrics.dart';
import 'package:offline_first_bi/presentation/widgets/form_style.dart';
import 'package:offline_first_bi/presentation/widgets/unit_quantity_input.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'form_finders.dart';
import 'search_helpers.dart';

Future<void> _openSheet(
  WidgetTester tester,
  AppDatabase db,
  Widget Function() builder,
) async {
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
                builder: (_) => builder(),
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

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('form placeholders use the muted token, lighter than a typed value', (
    tester,
  ) async {
    late InputDecorationTheme decoration;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Builder(
          builder: (context) {
            decoration = appInputDecorationTheme(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(decoration.hintStyle?.color, AppColors.textMuted);
  });

  testWidgets('the Precio A / Precio B toggle is at least 48dp high', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: AppMiniToggle<String>(
            segments: const [
              AppSegment('A', 'Precio A'),
              AppSegment('B', 'Precio B'),
            ],
            selected: 'A',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppMiniToggle<String>)).height, 48);
  });

  testWidgets('an invalid discount shows no discount and the undiscounted total', (
    tester,
  ) async {
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Libro',
        priceA: 20.0,
        priceB: 20.0,
        stock: const Value(50),
      ),
    );
    await _openSheet(tester, db, () => const SaleDialog());
    await searchProducts(tester, 'Libro');
    await tester.tap(find.byIcon(Icons.add_circle_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '0.00'), '5');
    await tester.pumpAndSettle();
    expect(find.text('- Bs. 5.00'), findsOneWidget);
    expect(find.text('Bs. 15.00'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '5'), '5.555');
    await tester.pumpAndSettle();
    expect(find.text('Máximo 2 decimales'), findsOneWidget);
    expect(find.textContaining('- Bs.'), findsNothing);
    expect(find.text('Bs. 20.00'), findsWidgets);
  });

  testWidgets('the sale form offers "Nuevo cliente"', (tester) async {
    await _openSheet(tester, db, () => const SaleDialog());
    expect(find.text('Nuevo cliente'), findsOneWidget);
    expect(find.text('Agregar'), findsNothing);
  });

  testWidgets('the purchase form offers "Nuevo proveedor"', (tester) async {
    await _openSheet(tester, db, () => const PurchaseDialog());
    expect(find.text('Nuevo proveedor'), findsOneWidget);
  });

  testWidgets('the event form offers "Nueva ubicación"', (tester) async {
    await _openSheet(tester, db, () => const EventDialog());
    expect(find.text('Nueva ubicación'), findsOneWidget);
  });

  testWidgets('form sheets dismiss with "Volver", never "Cancelar"', (tester) async {
    await _openSheet(tester, db, () => const ProductDialog());
    expect(find.text('Volver'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('the unit selector of a new material is not empty', (tester) async {
    await _openSheet(tester, db, () => const MaterialDialog());
    expect(find.text('Seleccionar unidad'), findsOneWidget);
  });

  testWidgets('a duplicate product name is refused by the form', (tester) async {
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Estuches',
        priceA: 10,
        priceB: 10,
      ),
    );
    await _openSheet(tester, db, () => const ProductDialog());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProductDialog)),
    );
    await container.read(productProvider.notifier).load();
    await tester.enterText(fieldLabeled('Nombre'), '  estuches ');
    await tester.pumpAndSettle();
    expect(find.text('Ya existe un producto con ese nombre'), findsOneWidget);
  });

  testWidgets('the catalog view of categories follows the status filter', (
    tester,
  ) async {
    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        name: 'Libros',
        isActive: const Value(false),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: lightTheme,
          home: const Scaffold(body: CategoriesPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vista de catálogo'));
    await tester.pumpAndSettle();
    expect(find.text('Libros'), findsOneWidget);
    expect(find.text('Inactiva'), findsOneWidget);
  });

  testWidgets('BI summary shows Gastos and Balance as not applicable for one product', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: const Scaffold(
          body: BiSummaryCards(
            summary: BiSummary(ingresos: 100, gastos: 500),
            showExpenses: false,
          ),
        ),
      ),
    );
    expect(find.text('No aplica'), findsNWidgets(2));
    expect(find.textContaining('500'), findsNothing);
    expect(find.textContaining('-400'), findsNothing);
  });

  testWidgets('the whole-units label comes from the unit', (tester) async {
    for (final (unit, label) in [
      ('paquete', 'Paquetes completos'),
      ('contenedor', 'Contenedores completos'),
      ('tira', 'Tiras completas'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: FractionQuantityPicker(
              unit: unit,
              value: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text(label), findsOneWidget, reason: unit);
      expect(find.text('Envases completos'), findsNothing);
    }
  });

  testWidgets('chart axis height follows the text scale', (tester) async {
    late double normal;
    late double large;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            normal = scaledAxisSize(context, 24);
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: Builder(
                builder: (context) {
                  large = scaledAxisSize(context, 24);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(normal, 24);
    expect(large, 48);
  });
}
