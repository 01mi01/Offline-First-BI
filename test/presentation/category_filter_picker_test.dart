import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/widgets/report_filters_widget.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// El filtro de categoría de Reportes y de Business Intelligence (mismo widget)
// se elige con el buscador, y las hojas de los demás filtros se desplazan en
// vez de desbordar cuando hay muchas opciones. Se prueba en una pantalla
// pequeña, donde antes la hoja de 7 categorías desbordaba por 29 px.
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
    // "Sin categoría" ya existe como predeterminada.
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
    // Teléfono pequeño: 360 x 640.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
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

  for (final combined in [false, true]) {
    final where = combined ? 'Business Intelligence' : 'Reportes';

    group('$where: filtro de categoría con buscador', () {
      testWidgets('opens a search sheet, not a fixed list, with no overflow', (
        tester,
      ) async {
        await pump(tester, combined: combined, onChanged: (_) {});
        await tester.tap(find.text('Categoría'));
        await tester.pumpAndSettle();

        expect(find.text('Filtrar por Categoría'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Buscar categoría'), findsOneWidget);
        expect(find.byKey(const ValueKey('picker-type-to-search')), findsOneWidget);
        // Las categorías no se listan hasta buscar (ya no hay nada que desborde).
        expect(find.text('Pines'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('typing filters, tapping selects, and the chip shows the name', (
        tester,
      ) async {
        ReportFilters? last;
        await pump(tester, combined: combined, onChanged: (f) => last = f);
        await tester.tap(find.text('Categoría'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'bol');
        await tester.pumpAndSettle();
        expect(find.text('Bolsas'), findsOneWidget);
        expect(find.text('Pines'), findsNothing);

        await tester.tap(find.text('Bolsas'));
        await tester.pumpAndSettle();
        expect(last!.categoryId, categoryIds['Bolsas']);
        // La hoja se cerró y el chip muestra la categoría elegida.
        expect(find.text('Filtrar por Categoría'), findsNothing);
        expect(find.text('Bolsas'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('search ignores accents and case, and says when nothing matches', (
        tester,
      ) async {
        await pump(tester, combined: combined, onChanged: (_) {});
        await tester.tap(find.text('Categoría'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'PAPELERIA');
        await tester.pumpAndSettle();
        expect(find.text('Papelería'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();
        expect(find.text('Sin resultados'), findsOneWidget);
      });

      testWidgets('"Sin categoría" is a normal, searchable category', (tester) async {
        ReportFilters? last;
        await pump(tester, combined: combined, onChanged: (f) => last = f);
        await tester.tap(find.text('Categoría'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'sin cat');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sin categoría'));
        await tester.pumpAndSettle();
        expect(last!.categoryId, categoryIds['Sin categoría']);
      });

      testWidgets('"Todas las categorías" and the chip X both clear the filter', (
        tester,
      ) async {
        ReportFilters? last;
        await pump(tester, combined: combined, onChanged: (f) => last = f);

        Future<void> choose(String query, String name) async {
          await tester.tap(find.text('Categoría'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), query);
          await tester.pumpAndSettle();
          await tester.tap(find.text(name));
          await tester.pumpAndSettle();
        }

        await choose('pin', 'Pines');
        expect(last!.categoryId, categoryIds['Pines']);

        // Volver a abrir: la elegida aparece marcada y "Todas" la quita.
        await tester.tap(find.text('Pines'));
        await tester.pumpAndSettle();
        expect(find.text('Todas las categorías'), findsOneWidget);
        await tester.tap(find.text('Todas las categorías'));
        await tester.pumpAndSettle();
        expect(last!.categoryId, isNull);
        expect(find.text('Categoría'), findsOneWidget);

        // La X del chip también la quita, como antes.
        await choose('mini', 'Miniaturas');
        expect(last!.categoryId, categoryIds['Miniaturas']);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(last!.categoryId, isNull);
      });

      testWidgets('dismissing the sheet without choosing changes nothing', (
        tester,
      ) async {
        ReportFilters? last;
        await pump(tester, combined: combined, onChanged: (f) => last = f);
        await tester.tap(find.text('Categoría'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(180, 20)); // fuera de la hoja
        await tester.pumpAndSettle();
        expect(last, isNull);
        expect(find.text('Filtrar por Categoría'), findsNothing);
      });
    });
  }

  // Producto, Cliente y Evento también se eligen con el buscador.
  final searchSpecs = [
    (
      chip: 'Producto',
      onlyReportes: false,
      title: 'Filtrar por Producto',
      hint: 'Buscar producto',
      all: 'Todos los productos',
      query: 'producto 25',
      result: 'Producto 25',
      other: 'Producto 4',
      read: (ReportFilters f) => f.productId,
      expected: () => productIds['Producto 25'],
    ),
    (
      chip: 'Cliente',
      onlyReportes: true,
      title: 'Filtrar por Cliente',
      hint: 'Buscar cliente',
      all: 'Todos los clientes',
      query: 'martinez',
      result: 'Ana Martínez',
      other: 'Michael Brown',
      read: (ReportFilters f) => f.clientId,
      expected: () => clientIds['Ana Martínez'],
    ),
    (
      chip: 'Evento',
      onlyReportes: false,
      title: 'Filtrar por Evento',
      hint: 'Buscar evento',
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
      group('$where: filtro ${spec.chip} con buscador', () {
        testWidgets('opens the search sheet with no overflow, not a plain list', (
          tester,
        ) async {
          await pump(tester, combined: combined, onChanged: (_) {});
          await tester.tap(find.text(spec.chip));
          await tester.pumpAndSettle();
          expect(find.text(spec.title), findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);
          expect(find.text(spec.hint), findsOneWidget);
          expect(
            find.byKey(const ValueKey('picker-type-to-search')),
            findsOneWidget,
          );
          // Las opciones no se listan hasta buscar.
          expect(find.text(spec.other), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets(
          'search (accent/case-insensitive) narrows the list and selecting filters',
          (tester) async {
            ReportFilters? last;
            await pump(tester, combined: combined, onChanged: (f) => last = f);
            await tester.tap(find.text(spec.chip));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), spec.query);
            await tester.pumpAndSettle();
            expect(find.text(spec.result), findsOneWidget);
            expect(find.text(spec.other), findsNothing);
            await tester.tap(find.text(spec.result));
            await tester.pumpAndSettle();
            expect(spec.read(last!), spec.expected());
            expect(find.text(spec.title), findsNothing);
            expect(find.text(spec.result), findsOneWidget); // el chip
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'the "all" option and the chip X clear it, and a no-match says so',
          (tester) async {
            ReportFilters? last;
            await pump(tester, combined: combined, onChanged: (f) => last = f);

            Future<void> choose() async {
              await tester.tap(find.text(spec.chip));
              await tester.pumpAndSettle();
              await tester.enterText(find.byType(TextField), spec.query);
              await tester.pumpAndSettle();
              await tester.tap(find.text(spec.result));
              await tester.pumpAndSettle();
            }

            await tester.tap(find.text(spec.chip));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'zzzz');
            await tester.pumpAndSettle();
            expect(find.text('Sin resultados'), findsOneWidget);
            await tester.tapAt(const Offset(180, 20));
            await tester.pumpAndSettle();

            await choose();
            expect(spec.read(last!), isNotNull);
            await tester.tap(find.text(spec.result));
            await tester.pumpAndSettle();
            await tester.tap(find.text(spec.all));
            await tester.pumpAndSettle();
            expect(spec.read(last!), isNull);

            await choose();
            await tester.tap(find.byIcon(Icons.close));
            await tester.pumpAndSettle();
            expect(spec.read(last!), isNull);
          },
        );
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

      await tester.tap(find.text('Categoría'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'libros');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Libros'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Producto'));
      await tester.pumpAndSettle();
      // P00..P24 son de Bolsas: con "Libros" elegida no aparecen.
      await tester.enterText(find.byType(TextField), 'producto 1');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'libro');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Libro'));
      await tester.pumpAndSettle();
      expect(last!.categoryId, isNotNull);
      expect(last!.productId, isNotNull);
    });
  });

  group('Ubicación se busca en línea, igual que Evento', () {
    testWidgets(
      'opens the inline search (no sheet), narrows a long list and selects',
      (tester) async {
        ReportFilters? last;
        await pump(tester, combined: false, onChanged: (f) => last = f);
        await tester.tap(find.text('Ubicación'));
        await tester.pumpAndSettle();

        expect(find.text('Filtrar por Ubicación'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Buscar ubicación'), findsOneWidget);
        expect(find.text('Escribe para buscar'), findsOneWidget);
        expect(find.text('Zona 0, Bolivia'), findsNothing); // sin escribir
        expect(tester.takeException(), isNull);

        await tester.enterText(find.byType(TextField), 'zona 19');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Zona 19, Bolivia'));
        await tester.pumpAndSettle();
        expect(last!.locationId, isNotNull);
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
