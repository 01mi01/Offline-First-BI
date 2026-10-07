import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/widgets/report_filters_widget.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// Cobertura ligera de ReportFiltersWidget ("donde sea relevante", no la
// matriz combinatoria completa que sí se cubre a nivel de servicio en
// report_filters_db_test.dart): qué chips aparecen según la pestaña activa,
// y que limpiar un filtro (el ícono "x" de un chip, o "Limpiar todo") emite
// el ReportFilters correcto vía onChanged.
class _Harness extends StatefulWidget {
  final int activeTab;
  final ReportFilters initialFilters;
  final ValueChanged<ReportFilters>? onChanged;

  const _Harness({
    required this.activeTab,
    this.initialFilters = const ReportFilters(),
    this.onChanged,
  });

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late ReportFilters filters = widget.initialFilters;

  @override
  Widget build(BuildContext context) {
    return ReportFiltersWidget(
      filters: filters,
      activeTab: widget.activeTab,
      onChanged: (f) {
        setState(() => filters = f);
        widget.onChanged?.call(f);
      },
    );
  }
}

void main() {
  late AppDatabase db;
  late int categoryId;
  late int clientId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    categoryId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'Bolsas'));
    clientId = await db.into(db.clients).insert(ClientsCompanion.insert(name: 'John Smith'));
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            categoryId: categoryId,
            name: 'Pines grandes',
            priceA: 10,
            priceB: 8,
          ),
        );
    await db.into(db.suppliers).insert(SuppliersCompanion.insert(name: 'Lino & Co.'));
    await db.into(db.locations).insert(
          LocationsCompanion.insert(city: 'La Paz - Calacoto', country: 'Bolivia'),
        );
    await db.into(db.events).insert(
          EventsCompanion.insert(name: 'Feria de Arte', startDate: DateTime(2024, 1, 1)),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    required int activeTab,
    ReportFilters initialFilters = const ReportFilters(),
    ValueChanged<ReportFilters>? onChanged,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: _Harness(
              activeTab: activeTab,
              initialFilters: initialFilters,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('chip visibility per tab', () {
    testWidgets('sales tab (0) shows Cliente/Categoría/Producto/Tipo de precio + Evento/Ubicación', (tester) async {
      await pumpHarness(tester, activeTab: 0);

      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('Categoría'), findsOneWidget);
      expect(find.text('Producto'), findsOneWidget);
      expect(find.text('Tipo de precio'), findsOneWidget);
      expect(find.text('Evento'), findsOneWidget);
      expect(find.text('Ubicación'), findsOneWidget);
      expect(find.text('Proveedor'), findsNothing);
    });

    testWidgets('purchases tab (1) shows only Proveedor + Evento/Ubicación', (tester) async {
      await pumpHarness(tester, activeTab: 1);

      expect(find.text('Proveedor'), findsOneWidget);
      expect(find.text('Evento'), findsOneWidget);
      expect(find.text('Ubicación'), findsOneWidget);
      expect(find.text('Cliente'), findsNothing);
      expect(find.text('Categoría'), findsNothing);
      expect(find.text('Producto'), findsNothing);
      expect(find.text('Tipo de precio'), findsNothing);
    });
  });

  group('chip layout', () {
    testWidgets(
      'every chip (including "Tipo de precio") fits inside the screen width at '
      'phone size instead of being cut off at the right edge',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpHarness(tester, activeTab: 0);

        for (final label in [
          'Cliente',
          'Categoría',
          'Producto',
          'Tipo de precio',
          'Evento',
          'Ubicación',
        ]) {
          final rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$label left');
          expect(
            rect.right,
            lessThanOrEqualTo(360 - 16),
            reason: '"$label" no debe quedar cortado en el borde derecho',
          );
        }
      },
    );

    testWidgets('chips wrap onto more rows instead of scrolling horizontally', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpHarness(tester, activeTab: 0);

      expect(find.byType(Wrap), findsWidgets);
      final firstTop = tester.getTopLeft(find.text('Cliente')).dy;
      final lastTop = tester.getTopLeft(find.text('Ubicación')).dy;
      expect(lastTop, greaterThan(firstTop), reason: 'debe haber más de una fila');
    });
  });

  group('"Limpiar todo"', () {
    testWidgets('is hidden when no filter is active', (tester) async {
      await pumpHarness(tester, activeTab: 0);
      expect(find.text('Limpiar todo'), findsNothing);
    });

    testWidgets('is shown when a filter is active and resets every field on tap', (tester) async {
      ReportFilters? lastEmitted;
      await pumpHarness(
        tester,
        activeTab: 0,
        initialFilters: ReportFilters(clientId: clientId),
        onChanged: (f) => lastEmitted = f,
      );

      expect(find.text('Limpiar todo'), findsOneWidget);

      await tester.tap(find.text('Limpiar todo'));
      await tester.pumpAndSettle();

      expect(lastEmitted, const ReportFilters());
      expect(find.text('Limpiar todo'), findsNothing);
    });
  });

  group('clearing an individual chip', () {
    testWidgets('tapping the date chip close icon clears only startDate', (tester) async {
      ReportFilters? lastEmitted;
      await pumpHarness(
        tester,
        activeTab: 0,
        initialFilters: ReportFilters(startDate: DateTime(2024, 1, 1)),
        onChanged: (f) => lastEmitted = f,
      );

      expect(find.textContaining('Desde: 01/01/2024'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(lastEmitted, const ReportFilters());
      expect(lastEmitted!.startDate, isNull);
    });

    testWidgets('tapping the Categoría chip close icon clears only categoryId', (tester) async {
      ReportFilters? lastEmitted;
      await pumpHarness(
        tester,
        activeTab: 0,
        initialFilters: ReportFilters(categoryId: categoryId),
        onChanged: (f) => lastEmitted = f,
      );

      // Se resuelve el nombre real de la categoría vía el provider real
      // (categoryProvider respaldado por la base sembrada), no un texto fijo.
      expect(find.text('Bolsas'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(lastEmitted, const ReportFilters());
      expect(lastEmitted!.categoryId, isNull);
    });

    testWidgets('tapping the Proveedor chip close icon clears only supplierId on the purchases tab', (tester) async {
      final supplier = await (db.select(
        db.suppliers,
      )..where((s) => s.name.equals('Lino & Co.'))).getSingle();
      final supplierId = supplier.id;

      ReportFilters? lastEmitted;
      await pumpHarness(
        tester,
        activeTab: 1,
        initialFilters: ReportFilters(supplierId: supplierId),
        onChanged: (f) => lastEmitted = f,
      );

      expect(find.text('Lino & Co.'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(lastEmitted, const ReportFilters());
      expect(lastEmitted!.supplierId, isNull);
    });
  });
}
