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
    'Cerámica',
    'Joyería',
    'Madera',
    'Papelería',
    'Pinturas',
    'Sin categoría',
    'Textiles',
    'Vidrio',
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
      final name = 'P${i.toString().padLeft(2, '0')}';
      productIds[name] = await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              categoryId: categoryIds['Joyería']!,
              name: name,
              priceA: 10,
              priceB: 8,
            ),
          );
    }
    for (final name in [
      'Ana Pérez',
      'Beto Rojas',
      'Carla Mamani',
      'Diego Quispe',
      'Elena Torres',
      'Fabio Vega',
      'Gloria Paz',
      'Hugo Salas',
    ]) {
      clientIds[name] = await db
          .into(db.clients)
          .insert(ClientsCompanion.insert(name: name));
    }
    for (final name in [
      'Feria de Arte',
      'Bazar Navideño',
      'Expo Cultural',
      'Mercado Artesanal',
      'Festival de Otoño',
      'Muestra Anual',
      'Taller Abierto',
      'Noche de Museos',
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
            LocationsCompanion.insert(city: 'Ciudad $i', country: 'Bolivia'),
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
        // Las 8 categorías no se listan hasta buscar (ya no hay nada que desborde).
        expect(find.text('Madera'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('typing filters, tapping selects, and the chip shows the name', (
        tester,
      ) async {
        ReportFilters? last;
        await pump(tester, combined: combined, onChanged: (f) => last = f);
        await tester.tap(find.text('Categoría'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'jo');
        await tester.pumpAndSettle();
        expect(find.text('Joyería'), findsOneWidget);
        expect(find.text('Madera'), findsNothing);

        await tester.tap(find.text('Joyería'));
        await tester.pumpAndSettle();
        expect(last!.categoryId, categoryIds['Joyería']);
        // La hoja se cerró y el chip muestra la categoría elegida.
        expect(find.text('Filtrar por Categoría'), findsNothing);
        expect(find.text('Joyería'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('search ignores accents and case, and says when nothing matches', (
        tester,
      ) async {
        await pump(tester, combined: combined, onChanged: (_) {});
        await tester.tap(find.text('Categoría'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'CERAMICA');
        await tester.pumpAndSettle();
        expect(find.text('Cerámica'), findsOneWidget);

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

        await choose('mad', 'Madera');
        expect(last!.categoryId, categoryIds['Madera']);

        // Volver a abrir: la elegida aparece marcada y "Todas" la quita.
        await tester.tap(find.text('Madera'));
        await tester.pumpAndSettle();
        expect(find.text('Todas las categorías'), findsOneWidget);
        await tester.tap(find.text('Todas las categorías'));
        await tester.pumpAndSettle();
        expect(last!.categoryId, isNull);
        expect(find.text('Categoría'), findsOneWidget);

        // La X del chip también la quita, como antes.
        await choose('tex', 'Textiles');
        expect(last!.categoryId, categoryIds['Textiles']);
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
      query: 'p24',
      result: 'P24',
      other: 'P03',
      read: (ReportFilters f) => f.productId,
      expected: () => productIds['P24'],
    ),
    (
      chip: 'Cliente',
      onlyReportes: true,
      title: 'Filtrar por Cliente',
      hint: 'Buscar cliente',
      all: 'Todos los clientes',
      query: 'carla',
      result: 'Carla Mamani',
      other: 'Hugo Salas',
      read: (ReportFilters f) => f.clientId,
      expected: () => clientIds['Carla Mamani'],
    ),
    (
      chip: 'Evento',
      onlyReportes: false,
      title: 'Filtrar por Evento',
      hint: 'Buscar evento',
      all: 'Todos los eventos',
      query: 'otono',
      result: 'Festival de Otoño',
      other: 'Muestra Anual',
      read: (ReportFilters f) => f.eventId,
      expected: () => eventIds['Festival de Otoño'],
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
          .insert(CategoriesCompanion.insert(name: 'Otra'));
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              categoryId: otro,
              name: 'Solo en Otra',
              priceA: 1,
              priceB: 1,
            ),
          );
      ReportFilters? last;
      await pump(tester, combined: false, onChanged: (f) => last = f);

      await tester.tap(find.text('Categoría'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'otra');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otra'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Producto'));
      await tester.pumpAndSettle();
      // P00..P24 son de Joyería: con "Otra" elegida no aparecen.
      await tester.enterText(find.byType(TextField), 'p0');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'solo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solo en Otra'));
      await tester.pumpAndSettle();
      expect(last!.categoryId, isNotNull);
      expect(last!.productId, isNotNull);
    });
  });

  group('Ubicación sigue siendo una lista simple', () {
    testWidgets(
      'opens the plain sheet (no search box) and a long list scrolls without overflow',
      (tester) async {
        ReportFilters? last;
        await pump(tester, combined: false, onChanged: (f) => last = f);
        await tester.tap(find.text('Ubicación'));
        await tester.pumpAndSettle();

        expect(find.text('Filtrar por Ubicación'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Escribe para buscar'), findsNothing);
        expect(find.text('Ciudad 0, Bolivia'), findsOneWidget); // ya listada
        expect(tester.takeException(), isNull); // 20 ubicaciones en 640 px

        await tester.scrollUntilVisible(
          find.text('Ciudad 19, Bolivia'),
          200,
          scrollable: find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.text('Ciudad 19, Bolivia'));
        await tester.pumpAndSettle();
        expect(last!.locationId, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
