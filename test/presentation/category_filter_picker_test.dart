import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/category_provider.dart';
import 'package:offline_first_bi/application/client_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/event_provider.dart';
import 'package:offline_first_bi/application/location_provider.dart';
import 'package:offline_first_bi/application/product_provider.dart';
import 'package:offline_first_bi/application/supplier_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/widgets/report_filters_widget.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'form_finders.dart';

class _Harness extends StatefulWidget {
  final bool combined;
  final ValueChanged<ReportFilters> onChanged;

  const _Harness({required this.combined, required this.onChanged});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  ReportFilters filters = const ReportFilters();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ReportFiltersWidget(
        filters: filters,
        activeTab: 0,
        combined: widget.combined,
        alwaysOpen: true,
        onChanged: (f) {
          setState(() => filters = f);
          widget.onChanged(f);
        },
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  final categoryIds = <String, int>{};
  final productIds = <String, int>{};
  final clientIds = <String, int>{};
  final eventIds = <String, int>{};
  const categoryNames = [
    'Bolsas',
    'Miniaturas',
    'Papelería',
    'Pines',
    'Sin categoría',
  ];

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final name in categoryNames.where((n) => n != 'Sin categoría')) {
      categoryIds[name] = await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(name: name));
    }
    final defaultCategory = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Sin categoría'))).getSingle();
    categoryIds['Sin categoría'] = defaultCategory.id;
    for (var i = 0; i < 25; i++) {
      final name = 'Producto ${i + 1}';
      productIds[name] = await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              categoryId: categoryIds['Bolsas']!,
              name: name,
              priceA: 10,
              priceB: 8,
            ),
          );
    }
    for (final name in [
      'John Smith',
      'Emily Johnson',
      'Ana Martínez',
      'Jessica Taylor',
      'Daniel Anderson',
      'Laura Thompson',
      'Robert Clark',
      'Michael Brown',
    ]) {
      clientIds[name] = await db
          .into(db.clients)
          .insert(ClientsCompanion.insert(name: name));
    }
    for (final name in [
      'Feria de Arte',
      'Feria del Libro La Paz',
      'Feria del Libro Cochabamba',
      'Feria del Libro Santa Cruz',
      'Exposición de Arte',
      'Feria de Lima',
      'Feria de Octubre',
      'Larga Noche de Museos La Paz',
    ]) {
      eventIds[name] = await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(name: name, startDate: DateTime(2026, 1, 1)),
          );
    }
    for (var i = 0; i < 20; i++) {
      await db
          .into(db.locations)
          .insert(
            LocationsCompanion.insert(city: 'Zona $i', country: 'Bolivia'),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool combined,
    required ValueChanged<ReportFilters> onChanged,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => Future.wait([
        container.read(categoryProvider.notifier).load(),
        container.read(productProvider.notifier).load(),
        container.read(eventProvider.notifier).load(),
        container.read(locationProvider.notifier).load(),
        container.read(clientProvider.notifier).load(),
        container.read(supplierProvider.notifier).load(),
      ]),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: _Harness(combined: combined, onChanged: onChanged),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder picker(String label) => find.byKey(ValueKey('filter-search-$label'));

  Future<void> search(WidgetTester tester, String label, String text) async {
    final field = find.descendant(of: picker(label), matching: find.byType(TextField));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  for (final combined in [false, true]) {
    final where = combined ? 'Business Intelligence' : 'Reportes';

    group('$where: filtro de categoría como desplegable', () {
      testWidgets('picking one filters, and "Todas las categorías" clears it', (
        tester,
      ) async {
        ReportFilters? last;
        await pump(tester, combined: combined, onChanged: (f) => last = f);
        await chooseOption(tester, 'Categoría', 'Pines');
        expect(last!.categoryId, categoryIds['Pines']);

        await chooseOption(tester, 'Categoría', 'Todas las categorías');
        expect(last!.categoryId, isNull);
      });
    });
  }

  final searchSpecs = [
    (
      label: 'Producto',
      onlyReportes: false,
      all: 'Todos los productos',
      query: 'producto 25',
      result: 'Producto 25',
      other: 'Producto 4',
      read: (ReportFilters f) => f.productId,
      expected: () => productIds['Producto 25'],
    ),
    (
      label: 'Cliente',
      onlyReportes: true,
      all: 'Todos los clientes',
      query: 'martinez',
      result: 'Ana Martínez',
      other: 'Michael Brown',
      read: (ReportFilters f) => f.clientId,
      expected: () => clientIds['Ana Martínez'],
    ),
    (
      label: 'Evento',
      onlyReportes: false,
      all: 'Todos los eventos',
      query: 'exposicion',
      result: 'Exposición de Arte',
      other: 'Feria de Lima',
      read: (ReportFilters f) => f.eventId,
      expected: () => eventIds['Exposición de Arte'],
    ),
  ];

  for (final combined in [false, true]) {
    final where = combined ? 'Business Intelligence' : 'Reportes';
    for (final spec in searchSpecs) {
      if (combined && spec.onlyReportes) continue;
      group('$where: filtro ${spec.label} con buscador', () {
        testWidgets('search (accent/case-insensitive) narrows the list and selecting filters', (
          tester,
        ) async {
          ReportFilters? last;
          await pump(tester, combined: combined, onChanged: (f) => last = f);
          await search(tester, spec.label, spec.query);
          expect(find.text(spec.result), findsOneWidget);
          expect(find.text(spec.other), findsNothing);
          await tester.tap(find.text(spec.result));
          await tester.pumpAndSettle();
          expect(spec.read(last!), spec.expected());
        });

        testWidgets('the "all" option clears it, and a no-match says so', (
          tester,
        ) async {
          ReportFilters? last;
          await pump(tester, combined: combined, onChanged: (f) => last = f);

          await search(tester, spec.label, 'zzzz');
          expect(find.text('No se encontraron resultados.'), findsOneWidget);

          await search(tester, spec.label, spec.query);
          await tester.tap(find.text(spec.result));
          await tester.pumpAndSettle();
          expect(spec.read(last!), isNotNull);

          final field = find.descendant(of: picker(spec.label), matching: find.byType(TextField));
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(spec.all));
          await tester.tap(find.text(spec.all));
          await tester.pumpAndSettle();
          expect(spec.read(last!), isNull);
        });
      });
    }
  }

  group('Producto acotado por la categoría elegida', () {
    testWidgets('only the products of that category can be found', (
      tester,
    ) async {
      final otro = await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(name: 'Libros'));
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              categoryId: otro,
              name: 'Libro',
              priceA: 1,
              priceB: 1,
            ),
          );
      ReportFilters? last;
      await pump(tester, combined: false, onChanged: (f) => last = f);

      await chooseOption(tester, 'Categoría', 'Libros');
      await search(tester, 'Producto', 'producto 1');
      expect(find.text('No se encontraron resultados.'), findsOneWidget);
      await search(tester, 'Producto', 'libro');
      await tester.tap(find.text('Libro'));
      await tester.pumpAndSettle();
      expect(last!.categoryId, isNotNull);
      expect(last!.productId, isNotNull);
    });

    testWidgets('a product is also found by its category name', (tester) async {
      await pump(tester, combined: false, onChanged: (_) {});
      await search(tester, 'Producto', 'bolsas 25');
      expect(find.text('Producto 25'), findsOneWidget);
    });
  });

  for (final combined in [false, true]) {
    final where = combined ? 'Business Intelligence' : 'Reportes';
    group('$where: filtros País y Ciudad', () {
      testWidgets('are dropdowns; the cities narrow to the chosen country', (
        tester,
      ) async {
        await db.into(db.locations).insert(
          LocationsCompanion.insert(city: 'Lima', country: 'Perú'),
        );
        ReportFilters? last;
        await pump(tester, combined: combined, onChanged: (f) => last = f);

        await chooseOption(tester, 'País', 'Perú');
        expect(last!.country, 'Perú');

        await tester.tap(find.byTooltip('Ciudad'));
        await tester.pumpAndSettle();
        expect(find.text('Lima'), findsOneWidget);
        expect(find.text('Zona 0'), findsNothing);
        await tester.tap(find.text('Lima'));
        await tester.pumpAndSettle();
        expect(last!.city, 'Lima');

        await chooseOption(tester, 'País', 'Bolivia');
        expect(last!.country, 'Bolivia');
        expect(last!.city, isNull);
      });
    });
  }

  group('Ubicación y Evento se buscan en línea', () {
    testWidgets('narrows a long list of locations and selects one', (
      tester,
    ) async {
      ReportFilters? last;
      await pump(tester, combined: false, onChanged: (f) => last = f);
      await search(tester, 'Ubicación', 'zona 19');
      expect(find.text('Zona 0, Bolivia'), findsNothing);
      await tester.tap(find.text('Zona 19, Bolivia'));
      await tester.pumpAndSettle();
      expect(last!.locationId, isNotNull);
    });

    testWidgets('an event is also found by its location', (tester) async {
      final lpz = await db.into(db.locations).insert(
        LocationsCompanion.insert(
          city: 'La Paz',
          country: 'Bolivia',
          description: const Value('Calacoto'),
        ),
      );
      await db.into(db.events).insert(
        EventsCompanion.insert(
          name: 'Feria de Mayo',
          startDate: DateTime(2026, 5, 1),
          locationId: Value(lpz),
        ),
      );
      await pump(tester, combined: false, onChanged: (_) {});
      await search(tester, 'Evento', 'calacoto');
      expect(find.text('Feria de Mayo'), findsOneWidget);
    });
  });
}
