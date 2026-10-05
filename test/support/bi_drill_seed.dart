import 'package:offline_first_bi/models/report_filters.dart';
import 'bi_harness.dart';

// Datos de prueba de los detalles de Business Intelligence, con todos los
// valores esperados calculados a mano. El periodo es de 14 días (de hace 13
// días a hoy), así que los intervalos son diarios.
//
// Productos: Anillo (Joyas, Bs. 50), Collar (Joyas, Bs. 80), Cuadro (Arte,
// Bs. 40). Evento: Feria.
//
//   Venta  Día    Contenido                       Neto   Cuenta
//   A      -1     Anillo 2 × 50 (Feria)           100    sí
//   B      -1     Collar 1 × 80, desc. 10 (Feria)  70    sí
//   C      -5     Anillo 1 × 50                    50    sí
//   D      -5     Cuadro 3 × 40 (Feria)           120    sí
//   E       0     Anillo 1 × 50, desc. 5           45    sí
//   X      -2     Anillo 5 × 50                   250    NO (cancelada)
//   F      +3     Anillo 1 × 999                  999    NO (futura)
//   G     -30     Anillo 1 × 50                    50    NO (fuera del periodo)
//
//   Compra         Día    Contenido                          Cuenta
//   gasto Feria    -2     general 40.50 (Feria)               sí
//   Hilo Feria     -3     Hilo 10 × 3 = 30 (Feria)            sí
//   gasto suelto   -4     general 100                         sí (sin evento)
//   Hilo           -8     Hilo 5 × 4 = 20                     sí
//   Cuerda         -2     Cuerda 2 × 10 = 20                  sí
//   Hilo viejo    -20     Hilo 100 × 1 = 100                  NO (fuera del periodo)
//   Hilo futuro    +1     Hilo 7 × 7 = 49                     NO (futura)
//   gasto futuro   +2     general 999 (Feria)                 NO (futura)
//   gasto viejo   -40     general 500 (Feria)                 NO (fuera del periodo)
//
// Esperado: Anillo = 195 en 4 uds. y 3 ventas (día -1: 100/2, día -5: 50/1,
// día 0: 45/1); Collar = 70; Cuadro = 120. Joyas = 265 en 5 uds.; Arte = 120.
// Feria: ingresos 290 (3 ventas), gastos 70.50 (40.50 generales + 30
// materiales), resultado 219.50. Hilo = 50 en 15 (2 compras: día -8: 20/5,
// día -3: 30/10); Cuerda = 20.
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
    await h.sell(day(-2), s.anillo, 5, 50); // 250, se cancela
    await h.sell(day(3), s.anillo, 1, 999); // futura
    await h.sell(day(-30), s.anillo, 1, 50); // fuera del periodo
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
