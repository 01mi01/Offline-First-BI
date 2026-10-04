import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/config/date_formatters.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/presentation/dialogs/event_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/purchase_dialog.dart';
import 'package:offline_first_bi/presentation/dialogs/sale_dialog.dart';
import 'package:offline_first_bi/presentation/widgets/transaction_date_field.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'search_helpers.dart';

// La fecha de una venta, compra o evento al crearlo NO tiene límite: se puede
// registrar algo pasado (se anota tarde) o futuro (se deja preparado). Solo los
// filtros y reportes se limitan a hoy o antes.
String _us(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

final _pickerEdit = find.descendant(
  of: find.byType(Dialog),
  matching: find.byIcon(Icons.edit_outlined),
);

// Escribe [date] en el selector de fecha (mm/dd/aaaa) y confirma.
Future<void> _typeDate(WidgetTester tester, DateTime date) async {
  await tester.tap(_pickerEdit);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
    _us(date),
  );
  await tester.pump();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final past = DateTime(now.year - 1, 3, 5);
  final future = DateTime(now.year + 1, 2, 20);
  final veryOld = DateTime(2018, 1, 1);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        categoryId: 1,
        name: 'Libro',
        priceA: 20,
        priceB: 20,
        stock: const Value(50),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openSheet(WidgetTester tester, Widget sheet) async {
    tester.view.physicalSize = const Size(900, 2000);
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
                  builder: (_) => sheet,
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

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('Venta', () {
    Future<void> sellWith(WidgetTester tester, DateTime? date) async {
      await openSheet(tester, const SaleDialog());
      await searchProducts(tester, 'Libro');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      if (date != null) {
        await tapText(tester, 'Fecha: ${formatDate(today)}');
        await _typeDate(tester, date);
        expect(find.text('Fecha: ${formatDate(date)}'), findsOneWidget);
      }
      await tapText(tester, 'Registrar venta');
    }

    testWidgets('the date defaults to today and an untouched sale is saved as of now', (
      tester,
    ) async {
      await openSheet(tester, const SaleDialog());
      expect(find.text('Fecha: ${formatDate(today)}'), findsOneWidget);
      await searchProducts(tester, 'Libro');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tapText(tester, 'Registrar venta');
      final sale = await db.select(db.sales).getSingle();
      expect(DateTime(sale.date.year, sale.date.month, sale.date.day), today);
    });

    testWidgets('a past date can be recorded', (tester) async {
      await sellWith(tester, past);
      final sale = await db.select(db.sales).getSingle();
      expect(DateTime(sale.date.year, sale.date.month, sale.date.day), past);
    });

    testWidgets('a future date can be recorded', (tester) async {
      await sellWith(tester, future);
      final sale = await db.select(db.sales).getSingle();
      expect(DateTime(sale.date.year, sale.date.month, sale.date.day), future);
    });
  });

  group('Compra', () {
    Future<void> buyWith(WidgetTester tester, DateTime? date) async {
      await openSheet(tester, const PurchaseDialog());
      await tester.tap(find.text('Gasto general'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción del gasto'),
        'Pasaje de bus',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Total (Bs.)'), '15');
      await tester.pumpAndSettle();
      if (date != null) {
        await tapText(tester, 'Fecha: ${formatDate(today)}');
        await _typeDate(tester, date);
        expect(find.text('Fecha: ${formatDate(date)}'), findsOneWidget);
      }
      await tapText(tester, 'Registrar compra');
    }

    testWidgets('the date defaults to today', (tester) async {
      await buyWith(tester, null);
      final p = await db.select(db.purchases).getSingle();
      expect(DateTime(p.date.year, p.date.month, p.date.day), today);
    });

    testWidgets('a past date can be recorded', (tester) async {
      await buyWith(tester, past);
      final p = await db.select(db.purchases).getSingle();
      expect(DateTime(p.date.year, p.date.month, p.date.day), past);
    });

    testWidgets('a future date can be recorded', (tester) async {
      await buyWith(tester, future);
      final p = await db.select(db.purchases).getSingle();
      expect(DateTime(p.date.year, p.date.month, p.date.day), future);
    });
  });

  group('Evento', () {
    Future<void> createWith(WidgetTester tester, DateTime date) async {
      await openSheet(tester, const EventDialog());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del evento'),
        'Feria de Arte',
      );
      await tapText(tester, 'Fecha de inicio');
      await _typeDate(tester, date);
      await tapText(tester, 'Crear');
    }

    for (final entry in {
      'past': past,
      'future': future,
      'before 2020': veryOld,
    }.entries) {
      testWidgets('an event can start on a ${entry.key} date', (tester) async {
        await createWith(tester, entry.value);
        final e = await db.select(db.events).getSingle();
        expect(
          DateTime(e.startDate.year, e.startDate.month, e.startDate.day),
          entry.value,
        );
      });
    }
  });

  test('transaction dates go from 2000 to 2100', () {
    expect(transactionFirstDate, DateTime(2000));
    expect(transactionLastDate, DateTime(2100));
  });

  test('picking a day keeps the time of the record', () {
    final base = DateTime(2026, 9, 10, 17, 45, 12);
    expect(
      withDayOf(DateTime(2027, 1, 3), base),
      DateTime(2027, 1, 3, 17, 45, 12),
    );
  });
}
