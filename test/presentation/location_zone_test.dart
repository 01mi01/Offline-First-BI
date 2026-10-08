import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/location_options.dart';
import 'package:offline_first_bi/application/report_service.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/location_model.dart';
import 'package:offline_first_bi/models/sale_model.dart';
import 'package:offline_first_bi/presentation/dialogs/event_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/pages/business_intelligence_page.dart';
import 'package:offline_first_bi/presentation/pages/events_page.dart';
import 'package:offline_first_bi/presentation/pages/purchases_page.dart';
import 'package:offline_first_bi/presentation/pages/reports_page.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/presentation/widgets/searchable_picker.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// La zona de una ubicación (su descripción) se busca y se ve en todas partes:
// todos los buscadores de ubicaciones aciertan por ella, y donde se muestra una
// ubicación se ve "Ciudad, País" y la zona.
void main() {
  late AppDatabase db;
  late Map<String, int> ids;

  // Ciudad, país y zona (las zonas aprobadas del seed).
  const zones = [
    ('La Paz', 'Bolivia', 'Calacoto'),
    ('La Paz', 'Bolivia', 'San Miguel'),
    ('Santa Cruz', 'Bolivia', 'Equipetrol'),
    ('Santa Cruz', 'Bolivia', 'Urubó'),
    ('Cochabamba', 'Bolivia', 'Campo Ferial FEXCO'),
    ('Lima', 'Perú', 'Miraflores'),
  ];

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ids = {};
    for (final (city, country, zone) in zones) {
      ids[zone] = await db.into(db.locations).insert(
        LocationsCompanion.insert(
          city: city,
          country: country,
          description: Value(zone),
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget home, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: lightTheme, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder pickerField(String label) => find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is SearchablePickerField<int> && w.label == label,
    ),
    matching: find.byType(TextField),
  );

  group('helpers', () {
    final calacoto = LocationModel(
      id: 1,
      city: 'La Paz',
      country: 'Bolivia',
      description: 'Calacoto',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    );
    final plain = LocationModel(
      id: 2,
      city: 'Lima',
      country: 'Perú',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    );

    test('label, zone and the search text', () {
      expect(locationLabel(calacoto), 'La Paz, Bolivia');
      expect(locationZone(calacoto), 'Calacoto');
      expect(locationLabelWithZone(calacoto), 'La Paz, Bolivia · Calacoto');
      expect(locationSearchText(calacoto), contains('Calacoto'));
      expect(locationSearchText(calacoto), contains('Bolivia'));
    });

    test('a location without a zone shows only city and country', () {
      expect(locationZone(plain), isNull);
      expect(locationLabelWithZone(plain), 'Lima, Perú');
    });

    test('report rows name the location with its zone', () {
      final rows = ReportService().buildSaleRows(
        sales: [
          SaleModel(
            id: 1,
            locationId: 1,
            totalAmount: 10,
            discount: 0,
            finalAmount: 10,
            date: DateTime(2024, 1, 1),
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
        clients: const [],
        locations: [calacoto],
        events: const [],
      );
      expect(rows.single.locationName, 'La Paz, Bolivia · Calacoto');
    });
  });

  group('searches that match only through the zone', () {
    testWidgets('Ubicaciones list: each zone finds its location', (tester) async {
      await pump(tester, const EventsPage());
      await tester.tap(find.widgetWithText(Tab, 'Ubicaciones'));
      await tester.pumpAndSettle();

      for (final (zone, city) in [
        ('calacoto', 'La Paz'),
        ('equipetrol', 'Santa Cruz'),
        ('urubo', 'Santa Cruz'),
        ('campo ferial', 'Cochabamba'),
        ('MIRAFLORES', 'Lima'),
      ]) {
        await tester.enterText(find.byType(TextField), zone);
        await tester.pumpAndSettle();
        expect(find.textContaining('$city, '), findsOneWidget, reason: zone);
      }
      await tester.enterText(find.byType(TextField), 'calacoto');
      await tester.pumpAndSettle();
      expect(find.text('Calacoto'), findsOneWidget);
      expect(find.text('Santa Cruz, Bolivia'), findsNothing);
    });

    testWidgets('Ubicaciones list: the País and Ciudad dropdowns still narrow', (
      tester,
    ) async {
      await pump(tester, const EventsPage());
      await tester.tap(find.widgetWithText(Tab, 'Ubicaciones'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Todas las ciudades'));
      await tester.pumpAndSettle();
      // Cada ciudad una sola vez, aunque tenga varias zonas.
      expect(find.text('La Paz'), findsOneWidget);
      expect(find.text('Santa Cruz'), findsOneWidget);
      await tester.tap(find.text('Santa Cruz').last);
      await tester.pumpAndSettle();
      expect(find.text('Equipetrol'), findsOneWidget);
      expect(find.text('Urubó'), findsOneWidget);
      expect(find.text('Calacoto'), findsNothing);

      // La búsqueda por zona respeta el filtro de ciudad.
      await tester.enterText(find.byType(TextField), 'calacoto');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets('sale form: Ubicación picker matches the zone and shows it', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: SaleDialog()));
      final field = pickerField('Ubicación');
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, 'san miguel');
      await tester.pumpAndSettle();
      expect(find.text('La Paz, Bolivia'), findsOneWidget);
      expect(find.text('San Miguel'), findsOneWidget); // segunda línea
      expect(find.text('Santa Cruz, Bolivia'), findsNothing);

      await tester.tap(find.text('San Miguel'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'La Paz, Bolivia · San Miguel',
      );
    });

    testWidgets('purchase form: Ubicación picker matches the zone and shows it', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: PurchaseDialog()));
      final field = pickerField('Ubicación');
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, 'campo ferial');
      await tester.pumpAndSettle();
      expect(find.text('Cochabamba, Bolivia'), findsOneWidget);
      expect(find.text('Campo Ferial FEXCO'), findsOneWidget);
      expect(find.text('Lima, Perú'), findsNothing);

      await tester.tap(find.text('Campo Ferial FEXCO'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Cochabamba, Bolivia · Campo Ferial FEXCO',
      );
    });

    testWidgets('event form: Ubicación picker matches the zone and shows it', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: EventDialog()), size: const Size(480, 1400));
      final field = pickerField('Ubicación');
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, 'miraflores');
      await tester.pumpAndSettle();
      expect(find.text('Lima, Perú'), findsOneWidget);
      expect(find.text('Miraflores'), findsOneWidget);
      expect(find.text('La Paz, Bolivia'), findsNothing);

      await tester.tap(find.text('Miraflores'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Lima, Perú · Miraflores',
      );
    });

    testWidgets('Reportes: the Ubicación filter matches the zone and the chip shows it', (
      tester,
    ) async {
      await pump(tester, const ReportsPage());
      await tester.ensureVisible(find.text('Ubicación'));
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(SearchablePickerField<int>),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'equipetrol');
      await tester.pumpAndSettle();
      expect(find.text('Santa Cruz, Bolivia'), findsOneWidget);
      expect(find.text('Equipetrol'), findsOneWidget);
      expect(find.text('La Paz, Bolivia'), findsNothing);

      await tester.tap(find.text('Equipetrol'));
      await tester.pumpAndSettle();
      expect(find.text('Santa Cruz, Bolivia · Equipetrol'), findsOneWidget);
    });

    testWidgets('Reportes > Compras: the same filter works on purchases', (
      tester,
    ) async {
      await pump(tester, const ReportsPage());
      await tester.tap(find.widgetWithText(Tab, 'Compras'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ubicación'));
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(SearchablePickerField<int>),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'urubo');
      await tester.pumpAndSettle();
      expect(find.text('Santa Cruz, Bolivia'), findsOneWidget);
      expect(find.text('Urubó'), findsOneWidget);
    });

    testWidgets('Business Intelligence: the Ubicación filter matches the zone', (
      tester,
    ) async {
      await pump(
        tester,
        const BusinessIntelligencePage(),
        size: const Size(412, 2400),
      );
      await tester.ensureVisible(find.text('Ubicación'));
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(SearchablePickerField<int>),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'calacoto');
      await tester.pumpAndSettle();
      expect(find.text('La Paz, Bolivia'), findsOneWidget);
      expect(find.text('Calacoto'), findsOneWidget);
      expect(find.text('Lima, Perú'), findsNothing);

      await tester.tap(find.text('Calacoto'));
      await tester.pumpAndSettle();
      expect(find.text('La Paz, Bolivia · Calacoto'), findsOneWidget);
    });
  });

  group('the zone is shown wherever a location is shown', () {
    testWidgets('event cards', (tester) async {
      await db.into(db.events).insert(
        EventsCompanion.insert(
          name: 'Feria de Lima',
          locationId: Value(ids['Miraflores']),
          startDate: DateTime(2024, 1, 1),
          endDate: Value(DateTime(2024, 1, 2)),
        ),
      );
      await pump(tester, const EventsPage());
      expect(find.text('Lima, Perú · Miraflores'), findsOneWidget);
    });

    testWidgets('sale details', (tester) async {
      await db.into(db.sales).insert(
        SalesCompanion.insert(
          locationId: Value(ids['Calacoto']),
          totalAmount: 10,
          finalAmount: 10,
          date: DateTime(2024, 1, 1, 12),
        ),
      );
      await pump(tester, const SalesPage(), size: const Size(700, 1400));
      await tester.tap(find.text('Bs. 10.00'));
      await tester.pumpAndSettle();
      expect(find.text('La Paz, Bolivia · Calacoto'), findsOneWidget);
    });

    testWidgets('purchase details', (tester) async {
      await db.into(db.purchases).insert(
        PurchasesCompanion.insert(
          locationId: Value(ids['Urubó']),
          isMaterial: const Value(false),
          description: const Value('Pasaje'),
          totalAmount: 20,
          date: DateTime(2024, 1, 1, 12),
        ),
      );

      await pump(tester, const PurchasesPage(), size: const Size(700, 1400));
      await tester.tap(find.text('Bs. 20.00'));
      await tester.pumpAndSettle();
      expect(find.text('Santa Cruz, Bolivia · Urubó'), findsOneWidget);
    });
  });
}
