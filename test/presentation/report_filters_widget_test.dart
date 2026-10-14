import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/widgets/report_filters_widget.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'form_finders.dart';

// Cobertura ligera de ReportFiltersWidget (la matriz combinatoria completa se
// cubre a nivel de servicio en report_filters_db_test.dart): qué filtros
// aparecen según la pestaña activa, y que limpiar un filtro (o todos) emite el
// ReportFilters correcto vía onChanged.
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
    return SingleChildScrollView(
      child: ReportFiltersWidget(
        filters: filters,
        activeTab: widget.activeTab,
        alwaysOpen: true,
        onChanged: (f) {
          setState(() => filters = f);
          widget.onChanged?.call(f);
        },
      ),
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

  group('filtros por pestaña', () {
    testWidgets('sales tab (0) shows Cliente/Categoría/Producto/Tipo de precio + Evento/Ubicación', (tester) async {
      await pumpHarness(tester, activeTab: 0);

      for (final label in [
        'Cliente',
        'Categoría',
        'Producto',
        'Tipo de precio',
        'Evento',
        'Ubicación',
        'País',
        'Ciudad',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Proveedor'), findsNothing);
      expect(find.text('Tipo'), findsNothing);
    });

    testWidgets('purchases tab (1) shows only Proveedor + Tipo + Evento/Ubicación', (tester) async {
      await pumpHarness(tester, activeTab: 1);

      for (final label in ['Proveedor', 'Tipo', 'Evento', 'Ubicación', 'País', 'Ciudad']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final label in ['Cliente', 'Categoría', 'Producto', 'Tipo de precio']) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });
  });

  group('"Limpiar"', () {
    testWidgets('is hidden when no filter is active', (tester) async {
      await pumpHarness(tester, activeTab: 0);
      expect(find.text('Limpiar'), findsNothing);
    });

    testWidgets('is shown when a filter is active and resets every field on tap', (tester) async {
      ReportFilters? lastEmitted;
      await pumpHarness(
        tester,
        activeTab: 0,
        initialFilters: ReportFilters(clientId: clientId, categoryId: categoryId),
        onChanged: (f) => lastEmitted = f,
      );

      expect(find.text('Limpiar'), findsOneWidget);

      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();

      expect(lastEmitted, const ReportFilters());
      expect(find.text('Limpiar'), findsNothing);
    });
  });

  group('clearing an individual filter', () {
    testWidgets('removing the Desde date clears only startDate', (tester) async {
      ReportFilters? lastEmitted;
      await pumpHarness(
        tester,
        activeTab: 0,
        initialFilters: ReportFilters(startDate: DateTime(2024, 1, 1)),
        onChanged: (f) => lastEmitted = f,
      );

      await tester.ensureVisible(find.byTooltip('Quitar Desde'));
      await tester.tap(find.byTooltip('Quitar Desde'));
      await tester.pumpAndSettle();

      expect(lastEmitted, const ReportFilters());
      expect(lastEmitted!.startDate, isNull);
    });

    testWidgets('choosing "Todas las categorías" clears only categoryId', (tester) async {
      ReportFilters? lastEmitted;
      await pumpHarness(
        tester,
        activeTab: 0,
        initialFilters: ReportFilters(categoryId: categoryId),
        onChanged: (f) => lastEmitted = f,
      );

      await chooseOption(tester, 'Categoría', 'Todas las categorías');

      expect(lastEmitted, const ReportFilters());
      expect(lastEmitted!.categoryId, isNull);
    });

    testWidgets('choosing "Todos los proveedores" clears only supplierId on the purchases tab', (tester) async {
      final supplier = await (db.select(
        db.suppliers,
      )..where((s) => s.name.equals('Lino & Co.'))).getSingle();

      ReportFilters? lastEmitted;
      await pumpHarness(
        tester,
        activeTab: 1,
        initialFilters: ReportFilters(supplierId: supplier.id),
        onChanged: (f) => lastEmitted = f,
      );

      final field = find.descendant(
        of: find.byKey(const ValueKey('filter-search-Proveedor')),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos los proveedores'));
      await tester.pumpAndSettle();

      expect(lastEmitted, const ReportFilters());
      expect(lastEmitted!.supplierId, isNull);
    });
  });
}
