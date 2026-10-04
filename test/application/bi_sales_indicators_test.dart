import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/material_provider.dart';
import 'package:offline_first_bi/application/product_provider.dart';
import 'package:offline_first_bi/models/bi_config.dart';
import 'package:offline_first_bi/models/bi_models.dart';
import 'package:offline_first_bi/models/purchase_kind.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import '../support/bi_harness.dart';

// Los seis indicadores de ventas adicionales de Business Intelligence (productos
// comprados juntos, ventas por día de la semana, ticket promedio, rentabilidad
// por evento, impacto de los descuentos y retorno sobre el costo de producción)
// sobre una base Drift real en memoria y los providers reales. Todos los
// valores esperados están calculados a mano en los comentarios.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = BiHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  DateTime day(int offset, [int hour = 12]) => h.day(offset, hour);

  // El [weekday] (DateTime.monday...sunday) de la semana que empezó hace
  // [weeksAgo] semanas (>= 1: siempre en el pasado), a las 12:00.
  DateTime weekday(int weekday, int weeksAgo) {
    final t = h.now;
    final monday = DateTime(t.year, t.month, t.day - (t.weekday - 1), 12);
    return DateTime(
      monday.year,
      monday.month,
      monday.day - 7 * weeksAgo + (weekday - 1),
      12,
    );
  }

  const mon = DateTime.monday;
  const tue = DateTime.tuesday;
  const wed = DateTime.wednesday;
  const fri = DateTime.friday;
  const sat = DateTime.saturday;
  const sun = DateTime.sunday;

  // Un conjunto de 9 ventas válidas de un solo producto repartidas por la
  // semana (más una cancelada y una futura que no cuentan). Devuelve el id del
  // evento al que está ligada la venta del viernes.
  //
  //   Lun (hace 1 sem.)  1 × 100            neto 100
  //   Lun (hace 2 sem.)  1 × 50             neto  50
  //   Mié (hace 1 sem.)  1 × 80  desc. 10   neto  70
  //   Sáb (hace 1 sem.)  1 × 200            neto 200
  //   Sáb (hace 2 sem.)  2 × 20             neto  40
  //   Sáb (hace 3 sem.)  1 × 60             neto  60
  //   Dom (hace 1 sem.)  1 × 30             neto  30
  //   Dom (hace 2 sem.)  2 × 50  desc. 15   neto  85   (bruto 100)
  //   Vie (hace 1 sem.)  1 × 25  (evento)   neto  25
  //   Mar (hace 1 sem.)  1 × 999  CANCELADA
  //   dentro de 3 días   1 × 777  FUTURA
  //
  // Neto total 660, bruto 685, descuentos 25, 9 ventas.
  Future<int> seedWeek() async {
    final p = await h.newProduct('Tote bag negra', stock: 1000);
    final feria = await h.newEvent('Feria de Arte', day(-40), day(-38));
    await h.sell(weekday(mon, 1), p, 1, 100);
    await h.sell(weekday(mon, 2), p, 1, 50);
    await h.sell(weekday(wed, 1), p, 1, 80, discount: 10);
    await h.sell(weekday(sat, 1), p, 1, 200);
    await h.sell(weekday(sat, 2), p, 2, 20);
    await h.sell(weekday(sat, 3), p, 1, 60);
    await h.sell(weekday(sun, 1), p, 1, 30);
    await h.sell(weekday(sun, 2), p, 2, 50, discount: 15);
    await h.sell(weekday(fri, 1), p, 1, 25, eventId: feria);
    await h.sell(weekday(tue, 1), p, 1, 999);
    await h.sell(day(3), p, 1, 777);
    await h.refresh();
    await h.cancelSaleOf(999);
    await h.refresh();
    return feria;
  }

  group('configuración de los indicadores nuevos', () {
    const added = [
      BiIndicator.coPurchase,
      BiIndicator.weekdaySales,
      BiIndicator.averageTicket,
      BiIndicator.eventProfit,
      BiIndicator.discountImpact,
      BiIndicator.costReturn,
    ];

    test('are in the Ventas group, unchecked by default, with info text', () {
      for (final i in added) {
        expect(i.group, BiGroup.ventas, reason: i.name);
        expect(i.defaultSelected, isFalse, reason: i.name);
        expect(BiConfig().indicators.contains(i), isFalse, reason: i.name);
        expect(i.info, contains('Qué muestra'), reason: i.name);
        expect(i.info, contains('Para qué sirve'), reason: i.name);
        expect(i.hasChartPicker, isTrue, reason: i.name);
      }
    });

    test('offer the requested chart types', () {
      expect(BiIndicator.coPurchase.chartTypes, [
        BiChartType.list,
        BiChartType.bar,
      ]);
      expect(BiIndicator.weekdaySales.chartTypes, [
        BiChartType.bar,
        BiChartType.line,
      ]);
      expect(BiIndicator.averageTicket.chartTypes, [
        BiChartType.cards,
        BiChartType.line,
      ]);
      expect(BiIndicator.eventProfit.chartTypes, [
        BiChartType.bar,
        BiChartType.list,
      ]);
      expect(BiIndicator.discountImpact.chartTypes, [
        BiChartType.cards,
        BiChartType.line,
      ]);
      expect(BiIndicator.costReturn.chartTypes, [
        BiChartType.bar,
        BiChartType.list,
      ]);
    });

    test('the info texts say what was asked for', () {
      final pairs = BiIndicator.coPurchase.info;
      expect(pairs, contains('al menos 3 ventas'));
      expect(pairs, contains('2 o más productos distintos'));

      final event = BiIndicator.eventProfit.info;
      expect(event, contains('gastos generales'));
      expect(event, contains('compras de materiales'));
      expect(event, contains('TODAS las compras vinculadas'));
      expect(event, contains('rojo'));

      final ret = BiIndicator.costReturn.info;
      expect(ret, contains('costo de producción manual'));
      expect(ret, contains('materiales, mano de obra y tiempo'));
      expect(ret, contains('costo actual'));
      expect(ret, contains('no el costo'));
      expect(ret, contains('No usa precios ni cantidades de materiales'));
    });
  });

  group('productos comprados juntos', () {
    // Productos: A = Tote bag negra, B = Pines grandes, C = Stickers,
    // D = Libro. Ventas válidas (10), con sus productos:
    //   S1  A+B          S2  A+B+C        S3  A+B       S4  A+C      S5  A+C
    //   S6  B            S7  A (dos líneas del mismo producto: 1 solo distinto)
    //   S10 A+B (evento) S11 A+D          S12 A+D
    // Más una venta A+B CANCELADA y otra FUTURA que no cuentan.
    //
    // Pares: A+B en S1, S2, S3, S10 = 4 → 4/10 = 40 %
    //        A+C en S2, S4, S5      = 3 → 3/10 = 30 %   (justo el mínimo)
    //        B+C solo en S2 = 1 y A+D en S11, S12 = 2 → no se muestran.
    // Ventas con 2+ productos distintos: S1, S2, S3, S4, S5, S10, S11, S12 = 8.
    late int a, b, c, d, feria;

    Future<void> seedPairs() async {
      a = await h.newProduct('Tote bag negra', stock: 1000);
      b = await h.newProduct('Pines grandes', stock: 1000);
      c = await h.newProduct('Stickers', stock: 1000);
      d = await h.newProduct('Libro', stock: 1000);
      feria = await h.newEvent('Feria de Lima', day(-30), day(-28));
      await h.sellMany(day(-1), [(a, 1, 100), (b, 1, 20)]); // S1
      await h.sellMany(day(-2), [(a, 1, 100), (b, 1, 20), (c, 1, 10)]); // S2
      await h.sellMany(day(-3), [(a, 2, 100), (b, 1, 20)]); // S3
      await h.sellMany(day(-4), [(a, 1, 100), (c, 1, 10)]); // S4
      await h.sellMany(day(-5), [(a, 1, 100), (c, 2, 10)]); // S5
      await h.sell(day(-6), b, 1, 20); // S6
      await h.sellMany(day(-6), [
        (a, 1, 100),
        (a, 1, 90),
      ]); // S7: mismo producto
      await h.sellMany(day(-7), [
        (a, 1, 100),
        (b, 1, 20),
      ], eventId: feria); // S10
      await h.sellMany(day(-8), [(a, 1, 100), (d, 1, 50)]); // S11
      await h.sellMany(day(-9), [(a, 1, 100), (d, 1, 50)]); // S12
      await h.sellMany(day(-1), [(a, 1, 999), (b, 1, 999)]); // se cancela
      await h.sellMany(day(5), [(a, 1, 100), (b, 1, 20)]); // futura
      await h.refresh();
      await h.cancelSaleOf(1998);
      await h.refresh();
    }

    test(
      'counts distinct pairs per sale, ranks them and shows the sales and %',
      () async {
        await seedPairs();
        final r = h.report().coPurchases;
        expect(r.totalSales, 10);
        expect(r.multiProductSales, 8);
        expect(r.pairs.length, 2);

        expect(r.pairs[0].label, 'Pines grandes + Tote bag negra');
        expect(r.pairs[0].sales, 4);
        expect(r.pairs[0].pct, closeTo(40, 1e-9));

        expect(r.pairs[1].label, 'Stickers + Tote bag negra');
        expect(r.pairs[1].sales, 3);
        expect(r.pairs[1].pct, closeTo(30, 1e-9));
      },
    );

    test(
      'a pair seen in only 2 sales (and a canceled or future one) is not shown',
      () async {
        await seedPairs();
        final r = h.report().coPurchases;
        expect(
          r.pairs.any((p) => p.label.contains('Libro')),
          isFalse,
        ); // 2 ventas
        expect(
          r.pairs.any((p) => p.label == 'Pines grandes + Stickers'),
          isFalse,
        ); // 1
        // La cancelada y la futura habrían subido A+B a 6.
        expect(r.pairs.first.sales, 4);
      },
    );

    test('respects the period filter', () async {
      await seedPairs();
      // Del día -3 a hoy: S1, S2, S3 → 3 ventas; A+B en las 3 (100 %), A+C solo
      // en S2 (1, no se muestra).
      final r = h
          .report(ReportFilters(startDate: day(-3), endDate: day(0)))
          .coPurchases;
      expect(r.totalSales, 3);
      expect(r.multiProductSales, 3);
      expect(r.pairs.map((p) => p.label), ['Pines grandes + Tote bag negra']);
      expect(r.pairs.single.sales, 3);
      expect(r.pairs.single.pct, closeTo(100, 1e-9));
    });

    test('respects the event filter', () async {
      await seedPairs();
      // Solo S10 está ligada al evento: 1 venta, ningún par llega a 3.
      final r = h.report(ReportFilters(eventId: feria)).coPurchases;
      expect(r.totalSales, 1);
      expect(r.multiProductSales, 1);
      expect(r.pairs, isEmpty);
    });

    test('respects the location filter', () async {
      final x = await h.newLocation('La Paz - Calacoto');
      final y = await h.newLocation('Santa Cruz - Equipetrol');
      final a = await h.newProduct('Tote bag negra', stock: 1000);
      final b = await h.newProduct('Pines grandes', stock: 1000);
      // 3 ventas A+B en La Paz y 3 en Santa Cruz, más una A sola en La Paz.
      for (var i = 1; i <= 3; i++) {
        await h.sellMany(day(-i), [(a, 1, 100), (b, 1, 20)], locationId: x);
        await h.sellMany(day(-i), [(a, 1, 100), (b, 1, 20)], locationId: y);
      }
      await h.sell(day(-1), a, 1, 100);
      await h.refresh();

      final all = h.report().coPurchases;
      expect(all.totalSales, 7);
      expect(all.pairs.single.sales, 6);
      expect(all.pairs.single.pct, closeTo(6 / 7 * 100, 1e-9));

      final paz = h.report(ReportFilters(locationId: x)).coPurchases;
      expect(paz.totalSales, 3); // la venta suelta no tiene ubicación
      expect(paz.pairs.single.sales, 3);
      expect(paz.pairs.single.pct, closeTo(100, 1e-9));
    });

    test(
      'a product filter looks at the whole sale, so it shows what goes with it',
      () async {
        await seedPairs();
        // Stickers está en S2, S4 y S5. Con los ítems completos: A+C 3 (100 %);
        // A+B y B+C solo en S2 (1 venta cada uno, no se muestran).
        final r = h.report(ReportFilters(productId: c)).coPurchases;
        expect(r.totalSales, 3);
        expect(r.pairs.map((p) => p.label), ['Stickers + Tote bag negra']);
        expect(r.pairs.single.pct, closeTo(100, 1e-9));
      },
    );

    test('without any multi-product sale there are no pairs', () async {
      final p = await h.newProduct('Tote bag negra');
      await h.sell(day(-1), p, 1, 100);
      await h.sell(day(-2), p, 1, 100);
      await h.refresh();
      final r = h.report().coPurchases;
      expect(r.totalSales, 2);
      expect(r.multiProductSales, 0);
      expect(r.pairs, isEmpty);
    });
  });

  group('ventas por día de la semana', () {
    test(
      'sums ingresos and sales per weekday, Monday first, with Spanish names',
      () async {
        await seedWeek();
        final w = h.report().weekdays;
        expect(w.map((e) => e.weekday), [1, 2, 3, 4, 5, 6, 7]);
        expect(w.map((e) => e.name), [
          'Lunes',
          'Martes',
          'Miércoles',
          'Jueves',
          'Viernes',
          'Sábado',
          'Domingo',
        ]);
        expect(w.map((e) => e.shortName), [
          'Lun',
          'Mar',
          'Mié',
          'Jue',
          'Vie',
          'Sáb',
          'Dom',
        ]);
        // Lunes 100 + 50; Miércoles 80 − 10; Viernes 25; Sábado 200 + 40 + 60;
        // Domingo 30 + (100 − 15); martes (cancelada) y jueves sin ventas.
        expect(w.map((e) => e.ingresos), [150, 0, 70, 0, 25, 300, 115]);
        expect(w.map((e) => e.ventas), [2, 0, 1, 0, 1, 3, 2]);
        expect(w.fold(0.0, (t, e) => t + e.ingresos), 660);
        expect(w.fold(0, (t, e) => t + e.ventas), 9);
      },
    );

    test('the canceled and the future sale never count', () async {
      await seedWeek();
      final w = h.report().weekdays;
      expect(w[1].ventas, 0); // martes: solo la cancelada
      expect(w.every((e) => e.ingresos < 700), isTrue); // ni 999 ni 777
    });

    test('respects the period filter', () async {
      await seedWeek();
      // Solo la semana que empezó hace 1 semana (lun–dom): Lun 100, Mié 70,
      // Vie 25, Sáb 200, Dom 30 (la cancelada del martes no cuenta).
      final w = h
          .report(
            ReportFilters(startDate: weekday(mon, 1), endDate: weekday(sun, 1)),
          )
          .weekdays;
      expect(w.map((e) => e.ingresos), [100, 0, 70, 0, 25, 200, 30]);
      expect(w.map((e) => e.ventas), [1, 0, 1, 0, 1, 1, 1]);
    });

    test('respects the event filter', () async {
      final feria = await seedWeek();
      final w = h.report(ReportFilters(eventId: feria)).weekdays;
      expect(w.map((e) => e.ingresos), [0, 0, 0, 0, 25, 0, 0]);
      expect(w.map((e) => e.ventas), [0, 0, 0, 0, 1, 0, 0]);
    });

    test('respects the location filter', () async {
      final loc = await h.newLocation('La Paz - Calacoto');
      final p = await h.newProduct('Tote bag negra');
      await h.sellMany(weekday(wed, 1), [(p, 1, 40)], locationId: loc);
      await h.sell(weekday(wed, 1), p, 1, 500); // sin ubicación
      await h.refresh();
      final w = h.report(ReportFilters(locationId: loc)).weekdays;
      expect(w[2].ingresos, 40);
      expect(w[2].ventas, 1);
    });

    test('a period without sales gives seven empty days', () async {
      await h.refresh();
      final w = h.report().weekdays;
      expect(w.length, 7);
      expect(w.every((e) => e.ingresos == 0 && e.ventas == 0), isTrue);
    });
  });

  group('ticket promedio', () {
    test('is the net income divided by the number of sales', () async {
      await seedWeek();
      final t = h.report().ticket;
      expect(t.salesCount, 9);
      expect(t.total, 660);
      expect(t.average, closeTo(660 / 9, 1e-9)); // 73.33...
    });

    test('respects the period filter', () async {
      await seedWeek();
      // Semana pasada: 100 + 70 + 25 + 200 + 30 = 425 en 5 ventas → 85.
      final t = h
          .report(
            ReportFilters(startDate: weekday(mon, 1), endDate: weekday(sun, 1)),
          )
          .ticket;
      expect(t.salesCount, 5);
      expect(t.total, 425);
      expect(t.average, closeTo(85, 1e-9));
    });

    test('has no average without sales', () async {
      await h.refresh();
      expect(h.report().ticket.average, isNull);
      expect(h.report().ticket.salesCount, 0);
    });

    test('its trend uses the same daily buckets as the time series', () async {
      await seedWeek();
      final series = h.report().timeSeries;
      expect(series.granularity, BiGranularity.day);

      BiTimeBucket bucketOf(DateTime d) => series.buckets.singleWhere(
        (b) => b.start == DateTime(d.year, d.month, d.day),
      );
      expect(bucketOf(weekday(sat, 2)).ventas, 1);
      expect(bucketOf(weekday(sat, 2)).ticket, 40);
      expect(bucketOf(weekday(sun, 2)).ticket, 85); // 100 − 15
      expect(bucketOf(weekday(mon, 1)).ticket, 100);
      // Un día sin ventas (el jueves, hace 1 semana) no tiene ticket.
      final thu = DateTime.thursday;
      expect(bucketOf(weekday(thu, 1)).ventas, 0);
      expect(bucketOf(weekday(thu, 1)).ticket, isNull);
      // Los intervalos suman lo mismo que el indicador.
      expect(series.buckets.fold(0, (t, b) => t + b.ventas), 9);
      expect(series.buckets.fold(0.0, (t, b) => t + b.ingresos), 660);
    });

    test(
      'over a long period the trend is weekly, like the time series',
      () async {
        final p = await h.newProduct('Tote bag negra', stock: 1000);
        // Mié y jue de la semana de hace 8 semanas: 100 y 50 → una sola semana.
        await h.sell(weekday(wed, 8), p, 1, 100);
        await h.sell(weekday(DateTime.thursday, 8), p, 1, 50);
        await h.sell(weekday(fri, 1), p, 1, 30);
        await h.refresh();
        final series = h.report().timeSeries;
        expect(series.granularity, BiGranularity.week);
        final first = series.buckets.first;
        expect(first.start, weekday(mon, 8).copyWith(hour: 0));
        expect(first.ventas, 2);
        expect(first.ticket, closeTo(75, 1e-9));
        // The series runs up to today, so the last bucket is the current week;
        // the Friday sale sits in the week that started one week ago.
        final lastWeek = series.buckets.singleWhere(
          (b) => b.start == weekday(mon, 1).copyWith(hour: 0),
        );
        expect(lastWeek.ventas, 1);
        expect(lastWeek.ticket, 30);
        expect(
          series.buckets.where((b) => b.ventas == 0 && b.ticket != null),
          isEmpty,
        );
      },
    );
  });

  group('impacto de los descuentos', () {
    test(
      'gives the total discount, the % of gross sales and the discounted sales',
      () async {
        await seedWeek();
        final d = h.report().discounts;
        expect(d.totalDiscount, 25); // 10 + 15
        expect(d.grossSales, 685);
        expect(d.pct, closeTo(25 / 685 * 100, 1e-9)); // 3.6496...
        expect(d.salesCount, 9);
        expect(d.discountedSales, 2);
        // Bruto − descuentos = ingresos del resumen.
        expect(d.grossSales - d.totalDiscount, h.report().summary.ingresos);
      },
    );

    test('respects the period filter', () async {
      await seedWeek();
      // Semana pasada: bruto 100 + 80 + 25 + 200 + 30 = 435, descuento 10.
      final d = h
          .report(
            ReportFilters(startDate: weekday(mon, 1), endDate: weekday(sun, 1)),
          )
          .discounts;
      expect(d.grossSales, 435);
      expect(d.totalDiscount, 10);
      expect(d.pct, closeTo(10 / 435 * 100, 1e-9));
      expect(d.discountedSales, 1);
    });

    test('with no discounts the amount and the % are 0', () async {
      final p = await h.newProduct('Tote bag negra');
      await h.sell(day(-1), p, 1, 100);
      await h.refresh();
      final d = h.report().discounts;
      expect(d.totalDiscount, 0);
      expect(d.pct, 0);
      expect(d.discountedSales, 0);
    });

    test('without sales there is no percentage', () async {
      await h.refresh();
      final d = h.report().discounts;
      expect(d.salesCount, 0);
      expect(d.pct, isNull);
    });

    test('its trend uses the same buckets as the time series', () async {
      await seedWeek();
      final series = h.report().timeSeries;
      BiTimeBucket bucketOf(DateTime d) => series.buckets.singleWhere(
        (b) => b.start == DateTime(d.year, d.month, d.day),
      );
      final wed1 = bucketOf(weekday(wed, 1));
      expect(wed1.descuentos, 10);
      expect(wed1.bruto, 80);
      expect(wed1.descuentoPct, closeTo(12.5, 1e-9));
      final sun2 = bucketOf(weekday(sun, 2));
      expect(sun2.descuentos, 15);
      expect(sun2.descuentoPct, closeTo(15, 1e-9));
      expect(bucketOf(weekday(mon, 1)).descuentos, 0);
      expect(series.buckets.fold(0.0, (t, b) => t + b.descuentos), 25);
      expect(series.buckets.fold(0.0, (t, b) => t + b.bruto), 685);
    });
  });

  group('rentabilidad por evento', () {
    // Productos y eventos (las fechas de los eventos no importan: cada venta y
    // cada compra cuenta por su propia fecha).
    //   Feria de Arte    ventas -10: 300 y -9: 2×100 desc. 20 (180) → 480 (2)
    //                    compras: gasto Hotel 150 (-11) + material 10×5 (-12)
    //                    = 200 (2) → resultado +280
    //   Feria de Lima    venta -5: 100 → gastos 400 (-6) + 250 (-4) = 650 (2)
    //                    → resultado −550 (pérdida)
    //   Feria Activa     sin ventas; gasto 80 (-20) → −80
    //   Feria de Octubre venta -1: 60, sin gastos → +60
    // Sin evento (no cuentan): venta 500, gasto 999. Excluidos: gasto futuro
    // 5000 de Feria de Arte, venta futura 5000 de Feria de Lima y venta
    // cancelada 777 de Feria de Octubre.
    late int arte, lima, activa, octubre, proveedor;

    Future<void> seedEvents() async {
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      final mat = await h.newMaterial('Tela negra');
      proveedor = await h.newSupplier('Riverside Supply Co.');
      arte = await h.newEvent('Feria de Arte', day(-100), day(-98));
      lima = await h.newEvent('Feria de Lima', day(-60), day(-58));
      activa = await h.newEvent('Feria Activa', day(-50), day(-48));
      octubre = await h.newEvent('Feria de Octubre', day(-40), day(-38));

      await h.sell(day(-10), p, 1, 300, eventId: arte);
      await h.sell(day(-9), p, 2, 100, discount: 20, eventId: arte);
      await h.spend(day(-11), 150, eventId: arte);
      await h.buyMaterial(day(-12), mat, 10, 5, eventId: arte);

      await h.sell(day(-5), p, 1, 100, eventId: lima);
      await h.spend(day(-6), 400, eventId: lima, supplierId: proveedor);
      await h.spend(day(-4), 250, eventId: lima);

      await h.spend(day(-20), 80, eventId: activa);
      await h.sell(day(-1), p, 1, 60, eventId: octubre);

      await h.sell(day(-3), p, 1, 500);
      await h.spend(day(-3), 999);
      await h.spend(day(2), 5000, eventId: arte);
      await h.sell(day(3), p, 1, 5000, eventId: lima);
      await h.sell(day(-2), p, 1, 777, eventId: octubre);
      await h.refresh();
      await h.cancelSaleOf(777);
      await h.refresh();
    }

    test(
      'income minus every linked purchase, best result first, losses negative',
      () async {
        await seedEvents();
        final e = h.report().eventProfit;
        expect(e.map((x) => x.name), [
          'Feria de Arte',
          'Feria de Octubre',
          'Feria Activa',
          'Feria de Lima',
        ]);
        expect(e.map((x) => x.income), [480, 60, 0, 100]);
        expect(e.map((x) => x.expenses), [200, 0, 80, 650]);
        expect(e.map((x) => x.profit), [280, 60, -80, -550]);
        expect(e.map((x) => x.salesCount), [2, 1, 0, 1]);
        expect(e.map((x) => x.purchaseCount), [2, 0, 1, 2]);
      },
    );

    test(
      'includes material purchases and general expenses, but not unlinked ones',
      () async {
        await seedEvents();
        final arteEntry = h.report().eventProfit.firstWhere(
          (x) => x.name == 'Feria de Arte',
        );
        // 150 de gasto general + 50 de material (10 × 5).
        expect(arteEntry.expenses, 200);
        // El gasto de 999 sin evento y la venta de 500 sin evento no aparecen.
        final total = h.report().eventProfit.fold(0.0, (t, x) => t + x.income);
        expect(total, 640);
      },
    );

    test(
      'never counts canceled sales or future-dated sales and purchases',
      () async {
        await seedEvents();
        final e = h.report().eventProfit;
        expect(
          e.firstWhere((x) => x.name == 'Feria de Octubre').income,
          60,
        ); // sin los 777
        expect(
          e.firstWhere((x) => x.name == 'Feria de Lima').income,
          100,
        ); // sin los 5000
        expect(
          e.firstWhere((x) => x.name == 'Feria de Arte').expenses,
          200,
        ); // sin los 5000
      },
    );

    test('each record counts by its own date, within the period', () async {
      await seedEvents();
      // Del día -7 a hoy: Feria de Arte y Feria Activa (registros anteriores)
      // desaparecen; Lima y Octubre quedan completas. Los eventos son de hace
      // meses, pero lo que cuenta es la fecha de cada venta y compra.
      final e = h
          .report(ReportFilters(startDate: day(-7), endDate: day(0)))
          .eventProfit;
      expect(e.map((x) => x.name), ['Feria de Octubre', 'Feria de Lima']);
      expect(e.map((x) => x.profit), [60, -550]);
    });

    test(
      'a purchase outside the period is left out even if its sale is inside',
      () async {
        await seedEvents();
        // Del día -5 a hoy: de Lima solo cuenta la venta (-5) y el gasto de -4;
        // el gasto de 400 es del día -6.
        final e = h
            .report(ReportFilters(startDate: day(-5), endDate: day(0)))
            .eventProfit;
        final limaEntry = e.firstWhere((x) => x.name == 'Feria de Lima');
        expect(limaEntry.income, 100);
        expect(limaEntry.expenses, 250);
        expect(limaEntry.profit, -150);
      },
    );

    test('respects the event filter', () async {
      await seedEvents();
      final e = h.report(ReportFilters(eventId: lima)).eventProfit;
      expect(e.map((x) => x.name), ['Feria de Lima']);
      expect(e.single.profit, -550);
    });

    test(
      'the purchase type and supplier filters do not drop linked purchases',
      () async {
        await seedEvents();
        // Con "solo gastos" y con un proveedor, el resumen general recorta las
        // compras, pero la rentabilidad por evento sigue sumando todas.
        final onlyExpenses = h.report(
          const ReportFilters(purchaseKind: PurchaseKind.expense),
        );
        expect(
          onlyExpenses.eventProfit
              .firstWhere((x) => x.name == 'Feria de Arte')
              .expenses,
          200, // incluye el material
        );
        final bySupplier = h.report(ReportFilters(supplierId: proveedor));
        expect(
          bySupplier.summary.gastos,
          400,
        ); // el filtro sí recorta el resumen
        expect(
          bySupplier.eventProfit
              .firstWhere((x) => x.name == 'Feria de Lima')
              .expenses,
          650,
        );
      },
    );

    test('respects the location filter', () async {
      final loc = await h.newLocation('Lima - Miraflores', country: 'Perú');
      final p = await h.newProduct('Tote bag negra', stock: 1000);
      final lima = await h.newEvent('Feria de Lima', day(-30), day(-28));
      await h.sellMany(day(-5), [(p, 1, 100)], eventId: lima, locationId: loc);
      await h.sell(day(-5), p, 1, 900, eventId: lima); // otra ubicación
      await h.spend(day(-6), 300, eventId: lima, locationId: loc);
      await h.spend(day(-6), 1000, eventId: lima);
      await h.refresh();
      final e = h.report(ReportFilters(locationId: loc)).eventProfit.single;
      expect(e.income, 100);
      expect(e.expenses, 300);
      expect(e.profit, -200);
    });

    test('is empty when no event has sales or purchases', () async {
      final p = await h.newProduct('Tote bag negra');
      await h.newEvent('Feria de Arte', day(-3), day(-2));
      await h.sell(day(-1), p, 1, 100);
      await h.refresh();
      expect(h.report().eventProfit, isEmpty);
    });
  });

  group('retorno sobre el costo de producción', () {
    // Costos de producción actuales: Tote bag negra 40, Stickers 5, Pines
    // grandes 10; Libro sin costo y Miniaturas con costo 0 (no entran).
    //   Tote bag negra: 2 × 100 (200) + 1 × 100 de la venta mixta (100 − 10 de
    //     descuento = 90) → 3 uds., ingresos 290, costo 120, ganancia 170,
    //     retorno 170 ÷ 120 = 1.41666...
    //   Stickers: 2 × 12 de la venta mixta (24 − 2.4 = 21.6) + 8 × 12 (96) →
    //     10 uds., ingresos 117.6, costo 50, ganancia 67.6, retorno 1.352
    //   Pines grandes: 5 × 8 = 40, costo 50 → ganancia −10, retorno −0.2
    // La venta mixta (Tote 1 × 100 + Stickers 2 × 12 = 124) lleva un descuento
    // de 12.4 repartido en proporción: 10 para la Tote y 2.4 para Stickers.
    late int tote, stickers, pines;

    Future<void> seedReturns() async {
      tote = await h.newProduct(
        'Tote bag negra',
        productionCost: 40,
        stock: 1000,
      );
      stickers = await h.newProduct('Stickers', productionCost: 5, stock: 1000);
      pines = await h.newProduct(
        'Pines grandes',
        productionCost: 10,
        stock: 1000,
      );
      final libro = await h.newProduct('Libro', stock: 1000); // sin costo
      final miniaturas = await h.newProduct(
        'Miniaturas',
        productionCost: 0,
        stock: 1000,
      );
      await h.sell(day(-6), tote, 2, 100);
      await h.sellMany(day(-5), [
        (tote, 1, 100),
        (stickers, 2, 12),
      ], discount: 12.4);
      await h.sell(day(-4), stickers, 8, 12);
      await h.sell(day(-3), pines, 5, 8);
      await h.sell(day(-3), libro, 1, 95);
      await h.sell(day(-2), miniaturas, 1, 70);
      await h.sell(day(-2), pines, 4, 8); // se cancela (32)
      await h.sell(day(4), tote, 9, 100); // futura
      await h.refresh();
      await h.cancelSaleOf(32);
      await h.refresh();
    }

    test(
      'ranks products from best to worst return and uses the net revenue',
      () async {
        await seedReturns();
        final r = h.report().costReturn;
        expect(r.entries.map((e) => e.name), [
          'Tote bag negra',
          'Stickers',
          'Pines grandes',
        ]);

        final t = r.entries[0];
        expect(t.units, 3);
        expect(t.revenue, closeTo(290, 1e-9));
        expect(t.cost, 120);
        expect(t.profit, closeTo(170, 1e-9));
        expect(t.ratio, closeTo(170 / 120, 1e-9));

        final s = r.entries[1];
        expect(s.units, 10);
        expect(s.revenue, closeTo(117.6, 1e-9));
        expect(s.cost, 50);
        expect(s.ratio, closeTo(67.6 / 50, 1e-9)); // 1.352

        final p = r.entries[2];
        expect(p.units, 5);
        expect(p.revenue, 40);
        expect(p.cost, 50);
        expect(p.profit, -10);
        expect(p.ratio, closeTo(-0.2, 1e-9));
      },
    );

    test('skips products without a production cost and counts them', () async {
      await seedReturns();
      final r = h.report().costReturn;
      // Libro (sin costo) y Miniaturas (costo 0, no se puede dividir).
      expect(r.withoutCost, 2);
      expect(
        r.entries.any((e) => e.name == 'Libro' || e.name == 'Miniaturas'),
        isFalse,
      );
    });

    test('is independent of material prices and quantities', () async {
      await seedReturns();
      final before = h.report().costReturn;

      final mat = await h.newMaterial('Tela negra');
      await h.buyMaterial(day(-10), mat, 500, 77);
      await h.container
          .read(materialProvider.notifier)
          .registerUsage(productId: tote, materialId: mat, quantityUsed: 123);
      await h.refresh();

      final after = h.report().costReturn;
      expect(
        after.entries.map((e) => e.name),
        before.entries.map((e) => e.name),
      );
      expect(
        after.entries.map((e) => e.cost),
        before.entries.map((e) => e.cost),
      );
      expect(
        after.entries.map((e) => e.ratio),
        before.entries.map((e) => e.ratio),
      );
    });

    test(
      'uses the CURRENT production cost, not the one when each sale was made',
      () async {
        await seedReturns();
        final notifier = h.container.read(productProvider.notifier);
        final product = h.container
            .read(productProvider)
            .products
            .firstWhere((p) => p.id == tote);
        await notifier.save(
          id: product.id,
          categoryId: product.categoryId,
          name: product.name,
          priceA: product.priceA,
          priceB: product.priceB,
          productionCost: 80,
          stock: product.stock,
        );
        await h.refresh();
        final t = h.report().costReturn.entries.firstWhere(
          (e) => e.name == 'Tote bag negra',
        );
        // Costo 80 × 3 = 240; ganancia 290 − 240 = 50; retorno 50 ÷ 240.
        expect(t.cost, 240);
        expect(t.ratio, closeTo(50 / 240, 1e-9));
      },
    );

    test('respects the period filter', () async {
      await seedReturns();
      // Solo el día -3: Pines grandes (5 uds.) y Libro sin costo.
      final r = h
          .report(ReportFilters(startDate: day(-3), endDate: day(-3)))
          .costReturn;
      expect(r.entries.map((e) => e.name), ['Pines grandes']);
      expect(r.withoutCost, 1);
    });

    test('a loss keeps its negative sign and goes last', () async {
      await seedReturns();
      final r = h.report().costReturn;
      expect(r.entries.last.ratio, lessThan(0));
      expect(r.entries.where((e) => e.ratio < 0).length, 1);
    });

    test('without any production cost the list is empty', () async {
      final libro = await h.newProduct('Libro');
      await h.sell(day(-1), libro, 1, 95);
      await h.refresh();
      final r = h.report().costReturn;
      expect(r.entries, isEmpty);
      expect(r.withoutCost, 1);
    });
  });
}
