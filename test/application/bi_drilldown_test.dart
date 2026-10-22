import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/bi_provider.dart';
import 'package:offline_first_bi/models/bi_config.dart';
import 'package:offline_first_bi/models/bi_models.dart';
import 'package:offline_first_bi/models/purchase_kind.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import '../support/bi_drill_seed.dart';
import '../support/bi_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = BiHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  BiQuery q(ReportFilters f) => BiQuery(filters: f);

  BiProductDetail product(int id, ReportFilters f) =>
      h.container.read(biProductDetailProvider((query: q(f), id: id)));
  BiCategoryDetail category(String name, ReportFilters f) =>
      h.container.read(biCategoryDetailProvider((query: q(f), name: name)));
  BiEventDetail event(int id, ReportFilters f) =>
      h.container.read(biEventDetailProvider((query: q(f), id: id)));
  BiMaterialDetail material(int id, ReportFilters f) =>
      h.container.read(biMaterialDetailProvider((query: q(f), id: id)));

  DateTime day(int offset) => h.day(offset);
  DateTime only(DateTime d) => DateTime(d.year, d.month, d.day);

  group('producto', () {
    test(
      'ingresos y unidades en el tiempo, sin canceladas, futuras ni fuera del período',
      () async {
        final s = await DrillSeed.create(h);
        final d = product(s.anillo, s.filters);

        expect(d.name, 'Anillo');
        expect(d.revenue, 195);
        expect(d.units, 4);
        expect(d.salesCount, 3);

        expect(d.granularity, BiGranularity.day);
        expect(d.buckets.length, 14);
        final byDay = {for (final b in d.buckets) b.start: b};
        expect(byDay[only(day(-1))]!.amount, 100);
        expect(byDay[only(day(-1))]!.quantity, 2);
        expect(byDay[only(day(-1))]!.count, 1);
        expect(byDay[only(day(-5))]!.amount, 50);
        expect(byDay[only(day(-5))]!.quantity, 1);
        expect(byDay[only(day(0))]!.amount, 45);
        expect(byDay[only(day(0))]!.quantity, 1);
        expect(d.buckets.where((b) => b.count > 0).length, 3);
        expect(d.buckets.fold(0.0, (t, b) => t + b.amount), d.revenue);
        expect(d.buckets.fold(0.0, (t, b) => t + b.quantity), d.units);
      },
    );

    test('usa los mismos intervalos que Evolución en el tiempo', () async {
      final s = await DrillSeed.create(h);
      final series = h.report(s.filters).timeSeries;
      final d = product(s.anillo, s.filters);
      expect(
        [for (final b in d.buckets) b.start],
        [for (final b in series.buckets) b.start],
      );
      expect(d.granularity, series.granularity);
    });

    test(
      'un producto con un solo registro y otro sin ventas en el período',
      () async {
        final s = await DrillSeed.create(h);
        final collar = product(s.collar, s.filters);
        expect(collar.revenue, 70);
        expect(collar.units, 1);
        expect(collar.salesCount, 1);

        final empty = product(
          s.cuadro,
          ReportFilters(startDate: day(-3), endDate: day(0)),
        );
        expect(empty.isEmpty, isTrue);
        expect(empty.revenue, 0);
      },
    );

    test('respeta los filtros vigentes', () async {
      final s = await DrillSeed.create(h);
      expect(
        product(s.anillo, s.filters.copyWith(categoryId: s.arte)).isEmpty,
        isTrue,
      );
      final oneDay = product(s.anillo, ReportFilters(startDate: day(-1)));
      expect(oneDay.revenue, 100);
      expect(oneDay.units, 2);
      expect(oneDay.salesCount, 1);
      expect(oneDay.granularity, BiGranularity.day);
      expect(
        product(s.anillo, s.filters.copyWith(eventId: s.feria)).revenue,
        100,
      );
    });

    test('su total es el de la barra del ranking', () async {
      final s = await DrillSeed.create(h);
      for (final e in h.report(s.filters).salesByProduct) {
        final d = product(e.refId!, s.filters);
        expect(d.revenue, e.amount, reason: e.label);
        expect(d.units, e.quantity, reason: e.label);
        expect(d.name, e.label);
      }
    });
  });

  group('categoría', () {
    test('sus productos de mayor a menor ingreso', () async {
      final s = await DrillSeed.create(h);
      final joyas = category('Joyas', s.filters);
      expect(joyas.revenue, 265);
      expect(joyas.units, 5);
      expect(joyas.products.map((p) => p.label), ['Anillo', 'Collar']);
      expect(joyas.products.map((p) => p.amount), [195, 70]);
      expect(joyas.products.map((p) => p.quantity), [4, 1]);
      expect(joyas.products.map((p) => p.refId), [s.anillo, s.collar]);

      final arte = category('Arte', s.filters);
      expect(arte.revenue, 120);
      expect(arte.units, 3);
      expect(arte.products.single.label, 'Cuadro');
    });

    test('respeta el período y los filtros', () async {
      final s = await DrillSeed.create(h);
      final today = category('Joyas', ReportFilters(startDate: day(0)));
      expect(today.products.map((p) => p.label), ['Anillo']);
      expect(today.revenue, 45);
      final collar = category('Joyas', s.filters.copyWith(productId: s.collar));
      expect(collar.products.map((p) => p.label), ['Collar']);
      expect(collar.revenue, 70);
      expect(
        category('Arte', ReportFilters(startDate: day(0))).isEmpty,
        isTrue,
      );
    });

    test('su total es el de la barra del ranking', () async {
      final s = await DrillSeed.create(h);
      for (final e in h.report(s.filters).salesByCategory) {
        final d = category(e.label, s.filters);
        expect(d.revenue, e.amount, reason: e.label);
        expect(d.units, e.quantity, reason: e.label);
      }
    });
  });

  group('evento', () {
    test('sus ventas y sus gastos vinculados, resumidos', () async {
      final s = await DrillSeed.create(h);
      final d = event(s.feria, s.filters);

      expect(d.name, 'Feria');
      expect(d.sales.length, 3);
      expect(d.income, 290);
      expect(d.expenses.length, 2);
      expect(d.generalExpenses, 40.5);
      expect(d.materialExpenses, 30);
      expect(d.totalExpenses, 70.5);
      expect(d.profit, 219.5);

      expect(d.sales.first.amount, 120);
      expect(d.expenses.first.isMaterial, isTrue);
      expect(d.expenses.first.description, 'Hilo');
      expect(d.expenses.last.description, 'Participación en feria');
    });

    test('es lo mismo que la barra de Rentabilidad por evento', () async {
      final s = await DrillSeed.create(h);
      final profit = h.report(s.filters).eventProfit.single;
      final d = event(s.feria, s.filters);
      expect(profit.name, d.name);
      expect(profit.income, d.income);
      expect(profit.expenses, d.totalExpenses);
      expect(profit.profit, d.profit);
      expect(profit.salesCount, d.sales.length);
      expect(profit.purchaseCount, d.expenses.length);
      final bar = h.report(s.filters).salesByEvent.single;
      expect(bar.amount, d.income);
      expect(bar.refId, s.feria);
    });

    test(
      'el tipo de operación no recorta sus gastos (como en Rentabilidad por evento)',
      () async {
        final s = await DrillSeed.create(h);
        final d = event(
          s.feria,
          s.filters.copyWith(purchaseKind: PurchaseKind.material),
        );
        expect(d.totalExpenses, 70.5);
        expect(d.expenses.length, 2);
      },
    );

    test('respeta el período', () async {
      final s = await DrillSeed.create(h);
      final d = event(s.feria, ReportFilters(startDate: day(-5)));
      expect(d.income, 120);
      expect(d.sales.length, 1);
      expect(d.expenses, isEmpty);
      expect(d.profit, 120);
    });
  });

  group('material', () {
    test(
      'sus compras en el tiempo, sin las futuras ni las de fuera del período',
      () async {
        final s = await DrillSeed.create(h);
        final d = material(s.hilo, s.filters);

        expect(d.name, 'Hilo');
        expect(d.unit, isNotNull);
        expect(d.spend, 50);
        expect(d.quantity, 15);
        expect(d.purchaseCount, 2);

        expect(d.granularity, BiGranularity.day);
        expect(d.buckets.length, 14);
        final byDay = {for (final b in d.buckets) b.start: b};
        expect(byDay[only(day(-3))]!.amount, 30);
        expect(byDay[only(day(-3))]!.quantity, 10);
        expect(byDay[only(day(-8))]!.amount, 20);
        expect(byDay[only(day(-8))]!.quantity, 5);
        expect(d.buckets.where((b) => b.count > 0).length, 2);
        expect(d.buckets.fold(0.0, (t, b) => t + b.amount), d.spend);

        expect(material(s.cuerda, s.filters).spend, 20);
      },
    );

    test('su total es el de la barra del ranking', () async {
      final s = await DrillSeed.create(h);
      final bars = h.report(s.filters).purchasesByMaterial;
      expect(bars.length, 2);
      for (final e in bars) {
        final d = material(e.refId!, s.filters);
        expect(d.spend, e.amount, reason: e.label);
        expect(d.quantity, e.quantity, reason: e.label);
        expect(d.unit, e.unit, reason: e.label);
      }
    });

    test('respeta el tipo de operación y el período', () async {
      final s = await DrillSeed.create(h);
      expect(
        material(
          s.hilo,
          s.filters.copyWith(purchaseKind: PurchaseKind.expense),
        ).isEmpty,
        isTrue,
      );
      final recent = material(
        s.hilo,
        ReportFilters(startDate: day(-5), endDate: day(0)),
      );
      expect(recent.spend, 30);
      expect(recent.purchaseCount, 1);
    });
  });
}
