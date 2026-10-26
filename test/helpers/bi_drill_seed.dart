import 'package:offline_first_bi/models/report_filters.dart';
import 'bi_harness.dart';

class DrillSeed {
  late int anillo, collar, cuadro, joyas, arte, feria, hilo, cuerda;

  late final ReportFilters filters;

  static Future<DrillSeed> create(BiHarness h) async {
    final s = DrillSeed();
    DateTime day(int offset) => h.day(offset);

    s.joyas = await h.newCategory('Joyas');
    s.arte = await h.newCategory('Arte');
    s.anillo = await h.newProduct(
      'Anillo',
      categoryId: s.joyas,
      priceA: 50,
      productionCost: 20,
    );
    s.collar = await h.newProduct(
      'Collar',
      categoryId: s.joyas,
      priceA: 80,
      productionCost: 30,
    );
    s.cuadro = await h.newProduct(
      'Cuadro',
      categoryId: s.arte,
      priceA: 40,
      productionCost: 15,
    );
    s.feria = await h.newEvent('Feria', day(-6), day(0));
    s.hilo = await h.newMaterial('Hilo');
    s.cuerda = await h.newMaterial('Cuerda');

    await h.sell(day(-1), s.anillo, 2, 50, eventId: s.feria);
    await h.sell(day(-1), s.collar, 1, 80, eventId: s.feria, discount: 10);
    await h.sell(day(-5), s.anillo, 1, 50);
    await h.sell(day(-5), s.cuadro, 3, 40, eventId: s.feria);
    await h.sell(day(0), s.anillo, 1, 50, discount: 5);
    await h.sell(day(-2), s.anillo, 5, 50);
    await h.sell(day(3), s.anillo, 1, 999);
    await h.sell(day(-30), s.anillo, 1, 50);
    await h.cancelSaleOf(250);

    await h.spend(day(-2), 40.5, eventId: s.feria);
    await h.buyMaterial(day(-3), s.hilo, 10, 3, eventId: s.feria);
    await h.spend(day(-4), 100);
    await h.buyMaterial(day(-8), s.hilo, 5, 4);
    await h.buyMaterial(day(-2), s.cuerda, 2, 10);
    await h.buyMaterial(day(-20), s.hilo, 100, 1);
    await h.buyMaterial(day(1), s.hilo, 7, 7);
    await h.spend(day(2), 999, eventId: s.feria);
    await h.spend(day(-40), 500, eventId: s.feria);

    s.filters = ReportFilters(startDate: day(-13), endDate: day(0));
    await h.refresh();
    return s;
  }
}
