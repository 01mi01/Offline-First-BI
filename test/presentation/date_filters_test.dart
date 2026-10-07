import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/date_range_filter.dart';
import 'package:offline_first_bi/config/date_formatters.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/presentation/pages/events_page.dart';
import 'package:offline_first_bi/presentation/pages/purchases_page.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/presentation/widgets/date_range_filter_bar.dart';
import 'package:offline_first_bi/presentation/widgets/report_filters_widget.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

// Filtros por fecha de Ventas, Compras y Eventos (atajos + Desde/Hasta) y la
// validación de rangos (Hasta no antes que Desde, hoy como fecha máxima) en
// esos filtros y en Reportes.

String _us(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

// El lápiz del selector (no el de las tarjetas de la lista de detrás).
final _pickerEditIcon = find.descendant(
  of: find.byType(Dialog),
  matching: find.byIcon(Icons.edit_outlined),
);

// Escribe [date] en el selector de fecha (modo texto, mm/dd/aaaa) y confirma.
Future<void> _typeDate(WidgetTester tester, DateTime date) async {
  await tester.tap(_pickerEditIcon);
  await tester.pumpAndSettle();
  final field = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(field, _us(date));
  await tester.pump();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  // Una fecha de hace más de un año, fuera de cualquier atajo.
  final longAgo = DateTime(now.year - 1, 6, 15);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(412, 915);
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

  ProviderContainer containerOf(WidgetTester tester, Type page) =>
      ProviderScope.containerOf(tester.element(find.byType(page)));

  group('DateRangeFilterBar', () {
    // Banca el estado del filtro y registra cada cambio que emite la barra.
    late List<DateRangeFilter> emitted;

    Future<void> pumpBar(
      WidgetTester tester, {
      DateRangeFilter initial = const DateRangeFilter(),
    }) async {
      emitted = [];
      await pump(
        tester,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              var value = initial;
              return StatefulBuilder(
                builder: (context, setInner) => DateRangeFilterBar(
                  value: value,
                  onChanged: (v) {
                    emitted.add(v);
                    setInner(() => value = v);
                  },
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('shows the four presets and empty Desde / Hasta', (tester) async {
      await pumpBar(tester);
      for (final label in ['Hoy', 'Esta semana', 'Este mes', 'Este año']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Desde'), findsOneWidget);
      expect(find.text('Hasta'), findsOneWidget);
    });

    testWidgets('a preset fills Desde / Hasta and tapping it again clears them', (
      tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      expect(emitted.last.preset, DatePreset.today);
      expect(find.text('Desde: ${formatDate(today)}'), findsOneWidget);
      expect(find.text('Hasta: ${formatDate(today)}'), findsOneWidget);

      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      expect(emitted.last.isActive, isFalse);
      expect(find.text('Desde'), findsOneWidget);
    });

    testWidgets('a custom range via the pickers drops the preset', (tester) async {
      await pumpBar(tester, initial: DateRangeFilter.forPreset(DatePreset.year));
      await tester.tap(find.textContaining('Desde:'));
      await tester.pumpAndSettle();
      await _typeDate(tester, yesterday);
      expect(emitted.last.from, yesterday);
      expect(emitted.last.preset, isNull);
      expect(find.text('Desde: ${formatDate(yesterday)}'), findsOneWidget);
    });

    testWidgets('the X on a date chip clears just that date', (tester) async {
      await pumpBar(tester, initial: DateRangeFilter.forPreset(DatePreset.today));
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(emitted.last.from, isNull);
      expect(emitted.last.to, today);
    });

    testWidgets('Desde = Hasta = today is a valid range', (tester) async {
      await pumpBar(tester, initial: DateRangeFilter(from: today));
      await tester.tap(find.text('Hasta'));
      await tester.pumpAndSettle();
      await _typeDate(tester, today);
      expect(emitted.last.from, today);
      expect(emitted.last.to, today);
      expect(find.text(rangeOrderMessage), findsNothing);
    });

    testWidgets('Hasta before Desde is rejected with a message', (tester) async {
      await pumpBar(tester, initial: DateRangeFilter(from: today));
      await tester.tap(find.text('Hasta'));
      await tester.pumpAndSettle();
      await _typeDate(tester, yesterday);
      expect(find.text(rangeOrderMessage), findsOneWidget);
      expect(emitted, isEmpty);
      expect(find.text('Hasta'), findsOneWidget); // sigue sin fecha
    });

    testWidgets('Desde after an existing Hasta is rejected too', (tester) async {
      await pumpBar(tester, initial: DateRangeFilter(to: yesterday));
      await tester.tap(find.text('Desde'));
      await tester.pumpAndSettle();
      await _typeDate(tester, today);
      expect(find.text(rangeOrderMessage), findsOneWidget);
      expect(emitted, isEmpty);
    });

    testWidgets('a future date cannot be picked: the picker refuses it', (
      tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.text('Hasta'));
      await tester.pumpAndSettle();
      await tester.tap(_pickerEditIcon);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
        _us(tomorrow),
      );
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // El selector sigue abierto con el aviso y no se aplicó nada.
      expect(find.textContaining('Out of range'), findsOneWidget);
      expect(emitted, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Hasta'), findsOneWidget);
    });

    testWidgets('the picker opens on today at most (never beyond it)', (
      tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.text('Desde'));
      await tester.pumpAndSettle();
      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(picker.lastDate, today);
      expect(picker.initialDate, today);
    });
  });

  group('Ventas', () {
    setUp(() async {
      final ana = await db.into(db.clients).insert(ClientsCompanion.insert(name: 'John Smith'));
      final emily = await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Emily Johnson'));
      Future<void> sale(int client, DateTime date) => db.into(db.sales).insert(
        SalesCompanion.insert(
          clientId: Value(client),
          totalAmount: 10,
          finalAmount: 10,
          date: date,
        ),
      );
      await sale(ana, now);
      await sale(emily, longAgo);
    });

    testWidgets('lists everything until a date filter is applied', (tester) async {
      await pump(tester, const SalesListBody());
      expect(find.text('John Smith'), findsOneWidget);
      expect(find.text('Emily Johnson'), findsOneWidget);
    });

    testWidgets('Hoy and Este año keep only the recent sale', (tester) async {
      await pump(tester, const SalesListBody());
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      expect(find.text('John Smith'), findsOneWidget);
      expect(find.text('Emily Johnson'), findsNothing);

      await tester.tap(find.text('Este año'));
      await tester.pumpAndSettle();
      expect(find.text('John Smith'), findsOneWidget);
      expect(find.text('Emily Johnson'), findsNothing);
    });

    testWidgets('a custom Desde/Hasta range finds the old sale; same day is valid', (
      tester,
    ) async {
      await pump(tester, const SalesListBody());
      containerOf(tester, SalesListBody)
          .read(saleDateFilterProvider.notifier)
          .state = DateRangeFilter(from: longAgo, to: longAgo);
      await tester.pumpAndSettle();
      expect(find.text('Emily Johnson'), findsOneWidget);
      expect(find.text('John Smith'), findsNothing);
    });

    testWidgets('a range with no sales says "Sin resultados" and can be cleared', (
      tester,
    ) async {
      await pump(tester, const SalesListBody());
      containerOf(tester, SalesListBody)
          .read(saleDateFilterProvider.notifier)
          .state = DateRangeFilter(
        from: DateTime(now.year - 5, 1, 1),
        to: DateTime(now.year - 5, 1, 2),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(find.text('John Smith'), findsOneWidget);
      expect(find.text('Emily Johnson'), findsOneWidget);
    });
  });

  group('Compras', () {
    setUp(() async {
      Future<void> purchase(String description, DateTime date) =>
          db.into(db.purchases).insert(
            PurchasesCompanion.insert(
              isMaterial: const Value(false),
              description: Value(description),
              totalAmount: 5,
              date: date,
            ),
          );
      await purchase('Hotel', now);
      await purchase('Pasaje de bus', longAgo);
    });

    testWidgets('presets and a custom range narrow the purchases', (tester) async {
      await pump(tester, const PurchasesListBody());
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Pasaje de bus'), findsOneWidget);

      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Pasaje de bus'), findsNothing);

      containerOf(tester, PurchasesListBody)
          .read(purchaseDateFilterProvider.notifier)
          .state = DateRangeFilter(
        from: DateTime(longAgo.year, longAgo.month, 1),
        to: DateTime(longAgo.year, longAgo.month, 28),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pasaje de bus'), findsOneWidget);
      expect(find.text('Hotel'), findsNothing);
    });

    testWidgets('the Ventas date filter does not affect the Compras list', (
      tester,
    ) async {
      await pump(tester, const PurchasesListBody());
      containerOf(tester, PurchasesListBody)
          .read(saleDateFilterProvider.notifier)
          .state = DateRangeFilter.forPreset(DatePreset.today);
      await tester.pumpAndSettle();
      // El filtro de Ventas no toca la lista de Compras.
      expect(find.text('Pasaje de bus'), findsOneWidget);
    });
  });

  group('Eventos', () {
    setUp(() async {
      await db.into(db.events).insert(
        EventsCompanion.insert(name: 'Feria de Octubre', startDate: today),
      );
      await db.into(db.events).insert(
        EventsCompanion.insert(
          name: 'Feria del Libro La Paz',
          startDate: DateTime(longAgo.year, longAgo.month, 14),
          endDate: Value(DateTime(longAgo.year, longAgo.month, 18)),
        ),
      );
    });

    testWidgets('Hoy keeps the event of today', (tester) async {
      await pump(tester, const EventsPage());
      expect(find.text('Feria de Octubre'), findsOneWidget);
      expect(find.text('Feria del Libro La Paz'), findsOneWidget);
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      expect(find.text('Feria de Octubre'), findsOneWidget);
      expect(find.text('Feria del Libro La Paz'), findsNothing);
    });

    testWidgets('a custom range touching only one day of a multi-day event matches it', (
      tester,
    ) async {
      await pump(tester, const EventsPage());
      final middle = DateTime(longAgo.year, longAgo.month, 16);
      containerOf(tester, EventsPage)
          .read(eventDateFilterProvider.notifier)
          .state = DateRangeFilter(from: middle, to: middle);
      await tester.pumpAndSettle();
      expect(find.text('Feria del Libro La Paz'), findsOneWidget);
      expect(find.text('Feria de Octubre'), findsNothing);
    });

    testWidgets('shows the date bar together with the status chip', (
      tester,
    ) async {
      await pump(tester, const EventsPage());
      // Ambos filtros conviven: la barra de fechas y el chip de estado.
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
    });

    testWidgets('an invalid range is rejected here too', (tester) async {
      await pump(tester, const EventsPage());
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Hasta:'));
      await tester.pumpAndSettle();
      await _typeDate(tester, yesterday);
      expect(find.text(rangeOrderMessage), findsOneWidget);
      // Sigue el rango de "Hoy".
      expect(find.text('Hasta: ${formatDate(today)}'), findsOneWidget);
    });
  });

  group('Reportes', () {
    late List<ReportFilters> emitted;

    Future<void> pumpReport(
      WidgetTester tester, {
      ReportFilters initial = const ReportFilters(),
    }) async {
      emitted = [];
      await pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                var filters = initial;
                return StatefulBuilder(
                  builder: (context, setInner) => ReportFiltersWidget(
                    filters: filters,
                    activeTab: 0,
                    onChanged: (f) {
                      emitted.add(f);
                      setInner(() => filters = f);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('the same period presets as Business Intelligence fill Desde / Hasta', (
      tester,
    ) async {
      await pumpReport(tester);
      for (final label in ['Hoy', 'Esta semana', 'Este mes', 'Este año']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      expect(emitted.last.startDate, today);
      expect(emitted.last.endDate, today);

      await tester.tap(find.text('Este año'));
      await tester.pumpAndSettle();
      expect(emitted.last.startDate, DateTime(now.year));
      expect(emitted.last.endDate, today); // nunca más allá de hoy

      // Volver a tocarlo quita el rango.
      await tester.tap(find.text('Este año'));
      await tester.pumpAndSettle();
      expect(emitted.last.startDate, isNull);
      expect(emitted.last.endDate, isNull);
    });

    testWidgets('Hasta before Desde is rejected', (tester) async {
      await pumpReport(tester, initial: ReportFilters(startDate: today));
      await tester.tap(find.text('Fecha de fin'));
      await tester.pumpAndSettle();
      await _typeDate(tester, yesterday);
      expect(find.text(rangeOrderMessage), findsOneWidget);
      expect(emitted, isEmpty);
    });

    testWidgets('the same day for Desde and Hasta is accepted', (tester) async {
      await pumpReport(tester, initial: ReportFilters(startDate: today));
      await tester.tap(find.text('Fecha de fin'));
      await tester.pumpAndSettle();
      await _typeDate(tester, today);
      expect(emitted.single.startDate, today);
      expect(emitted.single.endDate, today);
    });

    testWidgets('a future date is refused by the picker', (tester) async {
      await pumpReport(tester);
      await tester.tap(find.text('Fecha de inicio'));
      await tester.pumpAndSettle();
      await tester.tap(_pickerEditIcon);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
        _us(tomorrow),
      );
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Out of range'), findsOneWidget);
      expect(emitted, isEmpty);
    });

    testWidgets('a valid past Desde is applied', (tester) async {
      await pumpReport(tester);
      await tester.tap(find.text('Fecha de inicio'));
      await tester.pumpAndSettle();
      await _typeDate(tester, yesterday);
      expect(emitted.single.startDate, yesterday);
    });
  });

  // Con solo "Desde" (sin "Hasta") se muestra ese único día.
  group('Solo Desde = un solo día', () {
    testWidgets('Ventas: picking only Desde shows that day only', (tester) async {
      final ana = await db.into(db.clients).insert(ClientsCompanion.insert(name: 'John Smith'));
      final emily = await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Emily Johnson'));
      Future<void> sale(int client, DateTime date) => db.into(db.sales).insert(
        SalesCompanion.insert(
          clientId: Value(client),
          totalAmount: 10,
          finalAmount: 10,
          date: date,
        ),
      );
      await sale(ana, now);
      await sale(emily, longAgo.add(const Duration(hours: 15)));
      await sale(emily, longAgo.add(const Duration(days: 1)));
      await pump(tester, const SalesListBody());
      await tester.tap(find.text('Desde'));
      await tester.pumpAndSettle();
      await _typeDate(tester, longAgo);
      // Solo hay Desde: aparece su chip y Hasta sigue vacío.
      expect(find.text('Desde: ${formatDate(longAgo)}'), findsOneWidget);
      expect(find.text('Hasta'), findsOneWidget);
      // Solo la venta de ese día (a cualquier hora); ni hoy ni el día siguiente.
      expect(find.text('John Smith'), findsNothing);
      expect(find.text('Emily Johnson'), findsOneWidget);
    });

    testWidgets('Compras: Desde alone shows that day only', (tester) async {
      Future<void> purchase(String description, DateTime date) =>
          db.into(db.purchases).insert(
            PurchasesCompanion.insert(
              isMaterial: const Value(false),
              description: Value(description),
              totalAmount: 5,
              date: date,
            ),
          );
      await purchase('Hotel', now);
      await purchase('Pasaje de avión', longAgo.add(const Duration(hours: 9)));
      await purchase('Participación en feria', longAgo.add(const Duration(days: 1)));
      await pump(tester, const PurchasesListBody());
      containerOf(tester, PurchasesListBody)
          .read(purchaseDateFilterProvider.notifier)
          .state = DateRangeFilter(from: longAgo);
      await tester.pumpAndSettle();
      expect(find.text('Pasaje de avión'), findsOneWidget);
      expect(find.text('Hotel'), findsNothing);
      expect(find.text('Participación en feria'), findsNothing);
    });

    testWidgets('Eventos: Desde alone shows the events that cover that day', (
      tester,
    ) async {
      await db.into(db.events).insert(
        EventsCompanion.insert(name: 'Feria de Octubre', startDate: today),
      );
      await db.into(db.events).insert(
        EventsCompanion.insert(
          name: 'Feria del Libro Santa Cruz',
          startDate: DateTime(longAgo.year, longAgo.month, 14),
          endDate: Value(DateTime(longAgo.year, longAgo.month, 18)),
        ),
      );
      await pump(tester, const EventsPage());
      containerOf(tester, EventsPage)
          .read(eventDateFilterProvider.notifier)
          .state = DateRangeFilter(
        from: DateTime(longAgo.year, longAgo.month, 16),
      );
      await tester.pumpAndSettle();
      expect(find.text('Feria del Libro Santa Cruz'), findsOneWidget);
      expect(find.text('Feria de Octubre'), findsNothing);
    });
  });

  group('Ocultar registros con fecha futura', () {
    Future<void> sale(String client, DateTime date) async {
      final id = await db.into(db.clients).insert(ClientsCompanion.insert(name: client));
      await db.into(db.sales).insert(
        SalesCompanion.insert(
          clientId: Value(id),
          totalAmount: 10,
          finalAmount: 10,
          date: date,
        ),
      );
    }

    Future<void> purchase(String description, DateTime date) =>
        db.into(db.purchases).insert(
          PurchasesCompanion.insert(
            isMaterial: const Value(false),
            description: Value(description),
            totalAmount: 5,
            date: date,
          ),
        );

    Future<void> choose(WidgetTester tester, String from, String to) async {
      await tester.tap(find.text(from));
      await tester.pumpAndSettle();
      await tester.tap(find.text(to).last);
      await tester.pumpAndSettle();
    }

    testWidgets('Ventas: "Ventas actuales" (default) hides future sales; "Todas" shows them', (
      tester,
    ) async {
      await sale('Hoy Cliente', now);
      await sale('Futuro Cliente', tomorrow);
      await pump(tester, const SalesListBody());
      expect(find.text('Ventas actuales'), findsOneWidget);
      expect(find.text('Hoy Cliente'), findsOneWidget); // hoy ya cuenta
      expect(find.text('Futuro Cliente'), findsNothing);

      await choose(tester, 'Ventas actuales', 'Todas');
      expect(find.text('Hoy Cliente'), findsOneWidget);
      expect(find.text('Futuro Cliente'), findsOneWidget);
    });

    testWidgets('Ventas: it combines with the date range filter', (tester) async {
      await sale('Hoy Cliente', now);
      await sale('Futuro Cliente', tomorrow);
      await sale('Antiguo Cliente', longAgo);
      await pump(tester, const SalesListBody());
      containerOf(tester, SalesListBody)
          .read(saleDateFilterProvider.notifier)
          .state = DateRangeFilter(from: longAgo, to: longAgo);
      await tester.pumpAndSettle();
      expect(find.text('Antiguo Cliente'), findsOneWidget);
      expect(find.text('Hoy Cliente'), findsNothing);

      // "Todas" no quita el rango: solo deja de ocultar lo futuro.
      await choose(tester, 'Ventas actuales', 'Todas');
      expect(find.text('Antiguo Cliente'), findsOneWidget);
      expect(find.text('Futuro Cliente'), findsNothing);
    });

    testWidgets('Compras: "Compras actuales" (default) hides future purchases; "Todas" shows them', (
      tester,
    ) async {
      await purchase('Compra de hoy', now);
      await purchase('Compra futura', tomorrow);
      await pump(tester, const PurchasesListBody());
      expect(find.text('Compras actuales'), findsOneWidget);
      expect(find.text('Compra de hoy'), findsOneWidget);
      expect(find.text('Compra futura'), findsNothing);

      await choose(tester, 'Compras actuales', 'Todas');
      expect(find.text('Compra de hoy'), findsOneWidget);
      expect(find.text('Compra futura'), findsOneWidget);
    });

    test('RecordTimeFilter.current includes today and the past, not tomorrow', () {
      expect(RecordTimeFilter.current.includes(now), isTrue);
      expect(RecordTimeFilter.current.includes(longAgo), isTrue);
      expect(RecordTimeFilter.current.includes(tomorrow), isFalse);
      expect(RecordTimeFilter.all.includes(tomorrow), isTrue);
    });
  });

  testWidgets('Compras: the Tipo chip and the "Compras actuales" chip sit on the right, on one row', (tester) async {
    await db.into(db.purchases).insert(
      PurchasesCompanion.insert(
        isMaterial: const Value(false),
        description: const Value('Algo'),
        totalAmount: 5,
        date: now,
      ),
    );
    await pump(tester, const PurchasesListBody());
    final tipo = tester.getRect(find.text('Tipo').first);
    final actuales = tester.getRect(find.text('Compras actuales').first);
    final screen = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    // Pegados al margen derecho (16), no centrados, en la misma fila y con el
    // filtro nuevo a la derecha de "Tipo".
    expect(actuales.right, greaterThan(screen * 0.8));
    expect(tipo.left, greaterThan(screen * 0.15));
    expect(actuales.left, greaterThan(tipo.right));
    expect((actuales.center.dy - tipo.center.dy).abs(), lessThan(4));
  });
}
