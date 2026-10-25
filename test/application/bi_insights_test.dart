import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/bi_service.dart';
import 'package:offline_first_bi/models/bi_models.dart';
import 'package:offline_first_bi/models/purchase_kind.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import '../support/bi_harness.dart';
import 'package:offline_first_bi/config/rounding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = BiHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  DateTime day(int offset, [int hour = 12]) => h.day(offset, hour);

  DateTime thisMonday() {
    final t = h.now;
    return DateTime(t.year, t.month, t.day - (t.weekday - DateTime.monday), 12);
  }

  group('margen de ganancia por producto', () {
    test('ranks by margin, not by revenue, and skips products without cost', () async {
      final oleo = await h.newProduct('Miniaturas', productionCost: 90);
      final libro = await h.newProduct('Libro', productionCost: 70);
      final stickersHolo = await h.newProduct('Stickers holográficos', productionCost: 40);
      final pinesGrandes = await h.newProduct('Pines grandes');
      await h.sell(day(0), oleo, 2, 300);
      await h.sell(day(-1), libro, 20, 90);
      await h.sell(day(-2), stickersHolo, 5, 45);
      await h.sell(day(-2), pinesGrandes, 3, 12);
      await h.sell(day(-3), oleo, 10, 300);
      await h.sell(day(4), oleo, 5, 300);
      await h.refresh();
      await h.cancelSaleOf(3000);
      await h.refresh();

      final margins = h.report().productMargins;
      expect(margins.withoutCost, 1);
      expect(margins.entries.map((e) => e.name), ['Miniaturas', 'Libro', 'Stickers holográficos']);

      final o = margins.entries[0];
      expect(o.revenue, 600);
      expect(o.cost, 180);
      expect(o.profit, 420);
      expect(o.marginPct, closeTo(70, 1e-9));
      expect(o.units, 2);

      final b = margins.entries[1];
      expect(b.revenue, 1800);
      expect(b.profit, 400);
      expect(b.marginPct, closeTo(round2(22.2222), 1e-9));

      final t = margins.entries[2];
      expect(t.profit, 25);
      expect(t.marginPct, closeTo(round2(11.1111), 1e-9));

      final byRevenue = h.report().salesByProduct.first;
      expect(byRevenue.label, 'Libro');
    });

    test('uses the net amount after the sale discount', () async {
      final p = await h.newProduct('Tote bag negra', productionCost: 50);
      await h.sell(day(0), p, 2, 100, discount: 20);
      await h.refresh();
      final e = h.report().productMargins.entries.single;
      expect(e.revenue, 180);
      expect(e.profit, 80);
      expect(e.marginPct, closeTo(44.444, 1e-2));
    });

    test('respects the period filter', () async {
      final p = await h.newProduct('Tote bag negra', productionCost: 50);
      await h.sell(day(0), p, 1, 100);
      await h.sell(day(-30), p, 1, 500);
      await h.refresh();
      final onlyToday = h.report(ReportFilters(startDate: day(0)));
      expect(onlyToday.productMargins.entries.single.revenue, 100);
    });
  });

  group('proyección de ventas', () {
    test('a perfectly linear weekly trend is extended exactly', () async {
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      final monday = thisMonday();
      for (var k = 16; k >= 1; k--) {
        final date = DateTime(monday.year, monday.month, monday.day - 7 * k + 2, 12);
        await h.sell(date, p, 1, 300.0 + 40 * (16 - k));
      }
      await h.sell(day(0), p, 1, 5);
      await h.refresh();

      final report = h.report();
      expect(report.timeSeries.granularity, BiGranularity.week);
      final projection = report.projection;
      expect(projection.isAvailable, isTrue);
      expect(projection.granularity, BiGranularity.week);
      expect(projection.slope, closeTo(40, 1e-9));

      expect(projection.fitted.length, 8);
      expect(projection.fitted.first.value, closeTo(620, 1e-9));
      expect(projection.fitted.last.value, closeTo(900, 1e-9));

      expect(projection.projected.map((e) => e.value.round()), [
        980,
        1020,
        1060,
        1100,
      ]);
      expect(projection.projectedTotal, closeTo(4160, 1e-6));
      expect(projection.projected.first.start, DateTime(monday.year, monday.month, monday.day + 7));
      expect(
        projection.projected.every((e) => e.start.weekday == DateTime.monday),
        isTrue,
      );
    });

    test('a short daily period projects the next 7 days from complete days only', () async {
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      for (var i = 0; i < 9; i++) {
        await h.sell(day(-9 + i), p, 1, 100.0 + 10 * i);
      }
      await h.sell(day(0), p, 1, 7);
      await h.refresh();

      final projection = h.report(ReportFilters(startDate: day(-9), endDate: day(0))).projection;
      expect(projection.isAvailable, isTrue);
      expect(projection.granularity, BiGranularity.day);
      expect(projection.fitted.length, 9);
      expect(projection.slope, closeTo(10, 1e-9));
      expect(projection.projected.map((e) => e.value.round()), [
        200, 210, 220, 230, 240, 250, 260,
      ]);
      expect(projection.projected.first.start, day(1, 0));
    });

    test('never projects below zero', () async {
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      final monday = thisMonday();
      for (var k = 5; k >= 1; k--) {
        final date = DateTime(monday.year, monday.month, monday.day - 7 * k + 2, 12);
        await h.sell(date, p, 1, 120.0 * (k - 1) + 60);
      }
      await h.refresh();
      final projection = h.report().projection;
      expect(projection.isAvailable, isTrue);
      expect(projection.slope, lessThan(0));
      expect(projection.projected.every((e) => e.value >= 0), isTrue);
      expect(projection.projected.last.value, 0);
    });

    test('is unavailable when the period ends before today', () async {
      final p = await h.newProduct('Tote bag negra');
      for (var i = 1; i <= 10; i++) {
        await h.sell(day(-i), p, 1, 100);
      }
      await h.refresh();
      final projection = h
          .report(ReportFilters(startDate: day(-10), endDate: day(-1)))
          .projection;
      expect(projection.isAvailable, isFalse);
      expect(projection.unavailableReason, contains('termina antes de hoy'));
    });

    test('is unavailable with fewer than 3 complete intervals or no sales', () async {
      final p = await h.newProduct('Tote bag negra');
      await h.sell(day(-1), p, 1, 100);
      await h.sell(day(0), p, 1, 100);
      await h.refresh();
      final few = h.report(ReportFilters(startDate: day(-1), endDate: day(0))).projection;
      expect(few.isAvailable, isFalse);
      expect(few.unavailableReason, contains('3 intervalos'));

      final none = h
          .report(ReportFilters(startDate: day(-400), endDate: day(-399)))
          .projection;
      expect(none.isAvailable, isFalse);
    });
  });

  group('evento vs. días regulares', () {
    test('splits days and sales by the event dates and the sale\'s own date', () async {
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      final feria = await h.newEvent('Feria de Arte', day(-6), day(-4));
      await h.sell(day(-5), p, 1, 200, eventId: feria);
      await h.sell(day(-5), p, 1, 100, eventId: feria);
      await h.sell(day(-4), p, 1, 400);
      await h.sell(day(-9), p, 1, 100);
      await h.sell(day(-7), p, 1, 50);
      await h.sell(day(-8), p, 1, 80, eventId: feria);
      await h.sell(day(-1), p, 1, 50);
      await h.sell(day(0), p, 1, 150);
      await h.sell(day(3), p, 1, 9999);
      await h.refresh();

      final c = h
          .report(ReportFilters(startDate: day(-9), endDate: day(0)))
          .eventComparison;
      expect(c.eventDays, 3);
      expect(c.regularDays, 7);
      expect(c.eventRevenue, 700);
      expect(c.eventSales, 3);
      expect(c.regularRevenue, 430);
      expect(c.regularSales, 5);
      expect(c.eventPerDay, closeTo(round2(700 / 3), 1e-9));
      expect(c.regularPerDay, closeTo(round2(430 / 7), 1e-9));
      expect(c.eventPerSale, closeTo(round2(700 / 3), 1e-9));
      expect(c.regularPerSale, closeTo(86, 1e-9));
      expect(
        c.perDayDifferencePct,
        closeTo(round2((700 / 3 - 430 / 7) / (430 / 7) * 100), 1e-9),
      );
    });

    test('an event that runs past today only counts the days up to today', () async {
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      await h.newEvent('Exposición de Arte', day(-1), day(3));
      await h.sell(day(-1), p, 1, 100);
      await h.sell(day(0), p, 1, 300);
      await h.sell(day(-4), p, 1, 40);
      await h.refresh();

      final c = h.report(ReportFilters(startDate: day(-4), endDate: day(0))).eventComparison;
      expect(c.eventDays, 2);
      expect(c.regularDays, 3);
      expect(c.eventRevenue, 400);
      expect(c.regularRevenue, 40);
    });

    test('no event days in the period leaves the comparison without data', () async {
      final p = await h.newProduct('Tote bag negra');
      await h.newEvent('Feria del Libro La Paz', day(-100), day(-98));
      await h.sell(day(0), p, 1, 100);
      await h.refresh();
      final c = h.report(ReportFilters(startDate: day(-5), endDate: day(0))).eventComparison;
      expect(c.eventDays, 0);
      expect(c.eventPerDay, isNull);
      expect(c.perDayDifferencePct, isNull);
    });
  });

  group('costo de materiales vs. ingresos', () {
    test('compares material purchases against sales revenue', () async {
      final p = await h.newProduct('Tote bag negra');
      final tela = await h.newMaterial('Tela negra');
      await h.sell(day(0), p, 4, 200);
      await h.buyMaterial(day(-1), tela, 10, 10);
      await h.buyMaterial(day(-3), tela, 6, 10);
      await h.spend(day(0), 500);
      await h.buyMaterial(day(7), tela, 100, 100);
      await h.refresh();

      final cost = h.report().materialCost;
      expect(cost.materialSpend, 160);
      expect(cost.revenue, 800);
      expect(cost.ratioPct, closeTo(20, 1e-9));
    });

    test('has no ratio without revenue and follows the purchase kind filter', () async {
      final tela = await h.newMaterial('Tela negra');
      await h.buyMaterial(day(0), tela, 1, 40);
      await h.refresh();
      expect(h.report().materialCost.ratioPct, isNull);
      expect(h.report().materialCost.materialSpend, 40);
      final onlyExpenses = h.report(
        const ReportFilters(purchaseKind: PurchaseKind.expense),
      );
      expect(onlyExpenses.materialCost.materialSpend, 0);
    });
  });

  group('productos sin movimiento', () {
    test('lists active products with no valid sale in the window, never-sold first', () async {
      final a = await h.newProduct('Stickers');
      final b = await h.newProduct('Pines grandes');
      await h.newProduct('Estuches');
      await h.newProduct('Tote bag beige', isActive: false);
      final cancelada = await h.newProduct('Libro');
      final futura = await h.newProduct('Miniaturas');
      await h.sell(day(-5), a, 1, 10);
      await h.sell(day(-40), b, 1, 20);
      await h.sell(day(-2), cancelada, 1, 77);
      await h.sell(day(6), futura, 1, 88);
      await h.refresh();
      await h.cancelSaleOf(77);
      await h.refresh();

      final entries = h.report().noMovement;
      expect(entries.map((e) => e.product.name), [
        'Estuches',
        'Libro',
        'Miniaturas',
        'Pines grandes',
      ]);
      expect(entries.first.lastSale, isNull);
      expect(entries.first.daysSinceLastSale, isNull);
      final pinesGrandes = entries.last;
      expect(pinesGrandes.daysSinceLastSale, 40);
      expect(pinesGrandes.lastSale, DateTime(day(-40).year, day(-40).month, day(-40).day));

      expect(
        h.report(const ReportFilters(), 60).noMovement.map((e) => e.product.name),
        ['Estuches', 'Libro', 'Miniaturas'],
      );
      expect(
        h.report(const ReportFilters(), 7).noMovement.map((e) => e.product.name),
        contains('Pines grandes'),
      );
      expect(
        h.report(const ReportFilters(), 7).noMovement.map((e) => e.product.name),
        isNot(contains('Stickers')),
      );
      expect(
        h.report(const ReportFilters(), 3).noMovement.map((e) => e.product.name),
        contains('Stickers'),
      );
    });

    test('ignores the period and every filter (it measures recency)', () async {
      final p = await h.newProduct('Stickers');
      final q = await h.newProduct('Libro');
      await h.sell(day(-1), p, 1, 10);
      await h.sell(day(-50), q, 1, 10);
      await h.refresh();
      final filtered = h.report(
        ReportFilters(startDate: day(-300), endDate: day(-200), productId: p),
      );
      expect(filtered.noMovement.map((e) => e.product.name), ['Libro']);
    });
  });

  group('período anterior de un rango personalizado', () {
    final service = BiService();
    DateTime d(int y, int m, int day) => DateTime(y, m, day);

    test('compares with the same number of days right before it', () {
      final p = service.previousEqualLengthPeriod(d(2026, 9, 10), d(2026, 9, 19));
      expect((p.start, p.end), (d(2026, 8, 31), d(2026, 9, 9)));
      final single = service.previousEqualLengthPeriod(d(2026, 10, 2), d(2026, 10, 2));
      expect((single.start, single.end), (d(2026, 10, 1), d(2026, 10, 1)));
    });

    test('a range shaped like a month keeps the equal-length rule', () {
      final p = service.previousEqualLengthPeriod(d(2026, 10, 1), d(2026, 10, 31));
      expect((p.start, p.end), (d(2026, 8, 31), d(2026, 9, 30)));
      final partial = service.previousEqualLengthPeriod(d(2026, 3, 1), d(2026, 3, 30));
      expect((partial.start, partial.end), (d(2026, 1, 30), d(2026, 2, 28)));
    });

    test('the previous period never overlaps the current one and has the same size', () {
      for (final range in [
        (d(2026, 9, 10), d(2026, 9, 19)),
        (d(2026, 9, 28), d(2026, 10, 2)),
        (d(2026, 10, 1), d(2026, 10, 2)),
        (d(2026, 6, 15), d(2026, 6, 15)),
      ]) {
        final p = service.previousEqualLengthPeriod(range.$1, range.$2);
        expect(p.end.isBefore(range.$1), isTrue, reason: '$range');
        expect(
          p.end.difference(p.start).inDays,
          range.$2.difference(range.$1).inDays,
          reason: '$range',
        );
      }
    });
  });

  group('comparación entre períodos', () {
    ({DateTime start, int len}) plainRange() {
      for (final len in [10, 11, 12, 13, 9]) {
        final start = DateTime(h.now.year, h.now.month, h.now.day - (len - 1));
        if (start.day != 1) return (start: start, len: len);
      }
      throw StateError('sin rango neutro');
    }

    test('shows totals and % change against the previous equivalent period', () async {
      final r = plainRange();
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      await h.sell(DateTime(r.start.year, r.start.month, r.start.day + 1, 12), p, 1, 400);
      await h.sell(day(0), p, 1, 200);
      await h.spend(day(-2), 200);
      await h.sell(DateTime(r.start.year, r.start.month, r.start.day - 3, 12), p, 1, 400);
      await h.spend(DateTime(r.start.year, r.start.month, r.start.day - 1, 12), 100);
      await h.sell(DateTime(r.start.year, r.start.month, r.start.day - r.len - 5, 12), p, 1, 9999);
      await h.refresh();

      final c = h.report(ReportFilters(startDate: r.start, endDate: day(0))).periodComparison;
      expect(c.isAvailable, isTrue);
      expect(c.currentStart, r.start);
      expect(c.previousEnd, DateTime(r.start.year, r.start.month, r.start.day - 1));
      expect(c.current.ingresos, 600);
      expect(c.current.gastos, 200);
      expect(c.current.balance, 400);
      expect(c.previous.ingresos, 400);
      expect(c.previous.gastos, 100);
      expect(c.previous.balance, 300);
      expect(BiPeriodComparison.changePct(c.current.ingresos, c.previous.ingresos), closeTo(50, 1e-9));
      expect(BiPeriodComparison.changePct(c.current.gastos, c.previous.gastos), closeTo(100, 1e-9));
      expect(BiPeriodComparison.changePct(c.current.balance, c.previous.balance), closeTo(round2(33.3333), 1e-9));
    });

    test('canceled and future-dated records are excluded from both periods', () async {
      final r = plainRange();
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      final before = DateTime(r.start.year, r.start.month, r.start.day - 2, 12);
      await h.sell(before, p, 1, 300);
      await h.sell(before, p, 1, 555);
      await h.sell(day(5), p, 1, 777);
      await h.sell(day(0), p, 1, 100);
      await h.refresh();
      await h.cancelSaleOf(555);
      await h.refresh();
      final c = h.report(ReportFilters(startDate: r.start, endDate: day(0))).periodComparison;
      expect(c.previous.ingresos, 300);
      expect(c.current.ingresos, 100);
    });

    test('percentage change handles a zero base and a negative base', () {
      expect(BiPeriodComparison.changePct(100, 0), isNull);
      expect(BiPeriodComparison.changePct(0, 0), isNull);
      expect(BiPeriodComparison.changePct(-50, -100), closeTo(50, 1e-9));
      expect(BiPeriodComparison.changePct(50, -100), closeTo(150, 1e-9));
      expect(BiPeriodComparison.changePct(-200, -100), closeTo(-100, 1e-9));
    });

    test('is unavailable without a start date', () async {
      await h.refresh();
      expect(h.report().periodComparison.isAvailable, isFalse);
      expect(
        h.report(ReportFilters(endDate: day(0))).periodComparison.isAvailable,
        isFalse,
      );
    });

    test('other filters carry over to the previous period', () async {
      final r = plainRange();
      final a = await h.newProduct('Estuches', stock: 1000);
      final b = await h.newProduct('Libro', stock: 1000);
      final before = DateTime(r.start.year, r.start.month, r.start.day - 2, 12);
      await h.sell(before, a, 1, 100);
      await h.sell(before, b, 1, 900);
      await h.sell(day(0), a, 1, 50);
      await h.sell(day(0), b, 1, 70);
      await h.refresh();
      final c = h
          .report(ReportFilters(startDate: r.start, endDate: day(0), productId: a))
          .periodComparison;
      expect(c.previous.ingresos, 100);
      expect(c.current.ingresos, 50);
    });
  });

  group('radar de productos', () {
    test('normalizes the four axes against the best product of the period', () async {
      final oleo = await h.newProduct('Miniaturas', productionCost: 90, stock: 5);
      final libro = await h.newProduct('Libro', productionCost: 70, stock: 20);
      final stickersHolo = await h.newProduct('Stickers holográficos', stock: 20);
      await h.sell(day(0), oleo, 2, 300);
      await h.sell(day(-1), libro, 20, 90);
      await h.sell(day(-1), stickersHolo, 10, 5);
      await h.refresh();

      final radar = h.report(const ReportFilters(), 30, [oleo, libro, stickersHolo]).radar;
      expect(radar.autoSelected, isFalse);
      expect(radar.products.map((p) => p.name), ['Miniaturas', 'Libro', 'Stickers holográficos']);

      final o = radar.products[0];
      expect(o.revenueNorm, closeTo(600 / 1800, 1e-9));
      expect(o.unitsNorm, closeTo(2 / 20, 1e-9));
      expect(o.marginPct, closeTo(70, 1e-9));
      expect(o.marginNorm, closeTo(0.7, 1e-9));
      expect(o.stock, 3);
      expect(o.rotationNorm, closeTo(2 / (2 + 3), 1e-9));

      final b = radar.products[1];
      expect(b.revenueNorm, 1);
      expect(b.unitsNorm, 1);
      expect(b.marginNorm, closeTo(0.2222, 1e-3));
      expect(b.rotationNorm, 1);

      final t = radar.products[2];
      expect(t.marginPct, isNull);
      expect(t.marginNorm, 0);
      expect(t.stock, 10);
      expect(t.rotationNorm, closeTo(10 / 20, 1e-9));
    });

    test('without a valid selection the 3 best sellers are used', () async {
      final ids = <int>[];
      for (var i = 0; i < 5; i++) {
        final id = await h.newProduct('Producto $i');
        ids.add(id);
        await h.sell(day(0), id, 1, 100.0 + i * 10);
      }
      await h.refresh();

      final auto = h.report().radar;
      expect(auto.autoSelected, isTrue);
      expect(auto.products.map((p) => p.name), ['Producto 4', 'Producto 3', 'Producto 2']);

      expect(h.report(const ReportFilters(), 30, [ids.first]).radar.autoSelected, isTrue);
      expect(h.report(const ReportFilters(), 30, [ids[0], 9999]).radar.autoSelected, isTrue);
    });

    test('at most four products are drawn, in the order chosen', () async {
      final ids = <int>[];
      for (var i = 0; i < 6; i++) {
        final id = await h.newProduct('Producto $i');
        ids.add(id);
        await h.sell(day(0), id, 1, 100.0);
      }
      await h.refresh();
      final radar = h.report(const ReportFilters(), 30, ids.reversed.toList()).radar;
      expect(radar.autoSelected, isFalse);
      expect(radar.products.map((p) => p.name), ['Producto 5', 'Producto 4', 'Producto 3', 'Producto 2']);
    });

    test('a selected product with no sales in the period shows zeros, not an error', () async {
      final a = await h.newProduct('Estuches');
      final b = await h.newProduct('Libro', stock: 8, productionCost: 5);
      await h.sell(day(0), a, 1, 100);
      await h.refresh();
      final radar = h.report(const ReportFilters(), 30, [a, b]).radar;
      final quiet = radar.products.last;
      expect(quiet.name, 'Libro');
      expect(quiet.revenueNorm, 0);
      expect(quiet.unitsNorm, 0);
      expect(quiet.rotationNorm, 0);
      expect(quiet.marginPct, 0);
    });
  });

  group('exclusión de registros cancelados y futuros en todos los indicadores nuevos', () {
    test('a canceled sale and a future sale leave no trace', () async {
      final p = await h.newProduct('Tote bag negra', productionCost: 10, stock: 1000);
      final q = await h.newProduct('Libro', productionCost: 10, stock: 1000);
      await h.sell(day(0), p, 1, 100);
      await h.sell(day(-1), q, 5, 321);
      await h.sell(day(3), q, 7, 654);
      await h.refresh();
      await h.cancelSaleOf(5 * 321);
      await h.refresh();

      final r = h.report(ReportFilters(startDate: day(-5), endDate: day(0)));
      expect(r.productMargins.entries.map((e) => e.name), ['Tote bag negra']);
      expect(r.radar.products.map((e) => e.name), isNot(contains('Libro')));
      expect(r.eventComparison.eventRevenue + r.eventComparison.regularRevenue, 100);
      expect(r.periodComparison.current.ingresos, 100);
      expect(r.materialCost.revenue, 100);
      expect(r.noMovement.map((e) => e.product.name), ['Libro']);
    });
  });
}
