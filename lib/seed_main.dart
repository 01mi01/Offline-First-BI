// Punto de entrada que carga datos de ejemplo y abre la aplicación. Escribe
// siempre por la capa de repositorios (los notifiers de Riverpod) y no hace
// nada si la base ya tiene productos.
//
// Uso: flutter run -t lib/seed_main.dart --dart-define-from-file=config/dev.json
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'application/category_provider.dart';
import 'application/client_provider.dart';
import 'application/event_provider.dart';
import 'application/location_provider.dart';
import 'application/material_provider.dart';
import 'application/product_provider.dart';
import 'application/purchase_provider.dart';
import 'application/sale_provider.dart';
import 'application/supplier_provider.dart';
import 'application/unit_provider.dart';
import 'main.dart' show MyApp;

// (nombre, información de contacto)
const seedClients = <(String, String)>[
  ('John Smith', 'john.smith@example.com | +591 7000 0001 | @johnsmith'),
  ('Emily Johnson', 'emily.johnson@example.com | +591 7000 0002'),
  ('Ana Martínez', '+591 7000 0003 | @anamartinez'),
  ('Michael Brown', 'michael.brown@example.com'),
  ('Sarah Davis', 'sarah.davis@example.com | @sarahdavis'),
  ('David Wilson', '+591 7000 0006'),
  (
    'Jessica Taylor',
    'jessica.taylor@example.com | +591 7000 0007 | @jessicataylor',
  ),
  ('Daniel Anderson', '@danielanderson'),
  ('Laura Thompson', 'laura.thompson@example.com | +591 7000 0009'),
  ('Robert Clark', 'robert.clark@example.com'),
];

const seedSuppliers = <(String, String)>[
  (
    'Riverside Supply Co.',
    'riverside.supply@example.com | +591 7000 0011 | @riversidesupply',
  ),
  ('Lino & Co.', 'lino.co@example.com | @linoandco'),
  ('Aurelia Studio', '+591 7000 0013 | @aureliastudio'),
  ('Bellamy House', 'bellamy.house@example.com | +591 7000 0014'),
  (
    'Monroe Studio',
    'monroe.studio@example.com | +591 7000 0015 | @monroestudio',
  ),
  ('Lunaris Supply', '@lunarissupply'),
  ('Veridian Trading', 'veridian.trading@example.com'),
  ('Harbor Textiles', 'harbor.textiles@example.com | +591 7000 0018'),
  ('Crestview Supply', '+591 7000 0019 | @crestviewsupply'),
  (
    'Northgate Trading',
    'northgate.trading@example.com | +591 7000 0020 | @northgatetrading',
  ),
];

// (ciudad - zona, país)
const seedLocations = <(String, String)>[
  ('La Paz - Calacoto', 'Bolivia'), // 0
  ('La Paz - San Miguel', 'Bolivia'), // 1
  ('La Paz - Achumani', 'Bolivia'), // 2
  ('La Paz - Los Pinos', 'Bolivia'), // 3
  ('La Paz - Irpavi', 'Bolivia'), // 4
  ('La Paz - Bolognia', 'Bolivia'), // 5
  ('Santa Cruz - Equipetrol', 'Bolivia'), // 6
  ('Santa Cruz - Las Palmas', 'Bolivia'), // 7
  ('Santa Cruz - Urubó', 'Bolivia'), // 8
  ('Santa Cruz - Sirari', 'Bolivia'), // 9
  ('Cochabamba - Campo Ferial FEXCO', 'Bolivia'), // 10
  ('Lima - Miraflores', 'Perú'), // 11
];

class SeedCategory {
  final String name;
  final String description;
  const SeedCategory(this.name, this.description);
}

const seedCategories = <SeedCategory>[
  SeedCategory('Bolsas', 'Bolsas de tela hechas a mano.'),
  SeedCategory('Pines', 'Pines metálicos de distintos tamaños.'),
  SeedCategory('Papelería', 'Stickers y artículos de papel.'),
  SeedCategory('Miniaturas', 'Figuras pequeñas de resina.'),
  SeedCategory('Libros', 'Libros ilustrados.'),
];

class SeedMaterial {
  final String name;
  final String unit;
  const SeedMaterial(this.name, this.unit);
}

const seedMaterials = <SeedMaterial>[
  SeedMaterial('Tela negra', 'metro'), // 0
  SeedMaterial('Tela beige', 'metro'), // 1
  SeedMaterial('Resina parte A', 'contenedor'), // 2
  SeedMaterial('Resina parte B', 'contenedor'), // 3
  SeedMaterial('Base metálica grande para pines', 'unidad'), // 4
  SeedMaterial('Base metálica pequeña para pines', 'unidad'), // 5
  SeedMaterial('Papel para stickers', 'paquete'), // 6
  SeedMaterial('Papel holográfico para stickers', 'paquete'), // 7
  SeedMaterial('Tela para estuches', 'metro'), // 8
];

class SeedProduct {
  final String name;
  final String? category; // null = Sin categoría
  final double priceA;
  final double priceB;
  final double cost;
  final int remaining; // stock que queda después de las ventas
  const SeedProduct(
    this.name,
    this.category,
    this.priceA,
    this.priceB,
    this.cost,
    this.remaining,
  );
}

const seedProducts = <SeedProduct>[
  SeedProduct('Tote bag negra', 'Bolsas', 85, 75, 38, 14), // 0
  SeedProduct('Tote bag beige', 'Bolsas', 85, 75, 36, 12), // 1
  SeedProduct('Miniaturas', 'Miniaturas', 70, 60, 28, 6), // 2
  SeedProduct('Pines grandes', 'Pines', 25, 20, 7, 3), // 3
  SeedProduct('Set de pines pequeños', 'Pines', 40, 34, 14, 3), // 4
  SeedProduct('Stickers', 'Papelería', 12, 10, 3, 40), // 5
  SeedProduct('Stickers holográficos', 'Papelería', 18, 15, 5, 35), // 6
  SeedProduct('Estuches', null, 55, 48, 22, 9), // 7
  SeedProduct('Libro', 'Libros', 95, 85, 40, 2), // 8
];

// (índice de producto, índice de material, cantidad usada)
typedef SeedUsage = (int, int, double);

const seedUsage = <SeedUsage>[
  (0, 0, 22.4),
  (1, 1, 18),
  (2, 2, 2.5),
  (2, 3, 2.5),
  (3, 4, 64),
  (4, 5, 120),
  (5, 6, 6),
  (6, 7, 4.5),
  (7, 8, 14.5),
];

// (índice de producto, índice de material) del uso que se deja cancelado.
const seedCanceledUsage = (7, 8);

const seedInactiveClient = 'Robert Clark';
const seedInactiveSupplier = 'Northgate Trading';
const seedInactiveLocation = 'Santa Cruz - Sirari';
const seedInactiveMaterial = 'Base metálica pequeña para pines';
const seedInactiveCategory = 'Libros';
const seedInactiveProduct = 'Stickers holográficos';

class SeedEvent {
  final String name;
  final int location; // índice en seedLocations
  final int start; // días relativos a hoy
  final int end;
  final bool active;
  const SeedEvent(
    this.name,
    this.location,
    this.start,
    this.end, {
    this.active = true,
  });
}

// Índices de los eventos que usan las ventas y los gastos.
const eventLibroLaPaz = 0;
const eventLibroCochabamba = 1;
const eventLibroSantaCruz = 2;
const eventFeriaDeArte = 3;
const eventExposicionDeArte = 4;
const eventFeriaCancelada = 5;
const eventLargaNoche = 6;
const eventFeriaDeLima = 7;
const eventFeriaActiva = 8;
const eventFeriaDeOctubre = 9;
const eventFeriaDeNavidad = 10;

// Once eventos: casi todos en el pasado, uno en el mes actual, uno en
// diciembre de este año y uno desactivado.
List<SeedEvent> buildSeedEvents(DateTime today) {
  final todayDate = DateTime(today.year, today.month, today.day);
  int offset(DateTime d) => d.difference(todayDate).inDays;
  final monthStart = offset(DateTime(today.year, today.month, 1));
  final christmas = offset(DateTime(today.year, 12, 20));
  return [
    const SeedEvent('Feria del Libro La Paz', 0, -100, -98),
    const SeedEvent('Feria del Libro Cochabamba', 10, -88, -86),
    const SeedEvent('Feria del Libro Santa Cruz', 6, -75, -73),
    const SeedEvent('Feria de Arte', 1, -66, -64),
    const SeedEvent('Exposición de Arte', 2, -50, -49),
    const SeedEvent('Feria Cancelada', 7, -42, -41, active: false),
    const SeedEvent('Larga Noche de Museos La Paz', 3, -35, -35),
    const SeedEvent('Feria de Lima', 11, -30, -27),
    const SeedEvent('Feria Activa', 8, -12, -10),
    SeedEvent('Feria de Octubre', 4, monthStart, monthStart + 2),
    SeedEvent('Feria de Navidad', 5, christmas, christmas + 2),
  ];
}

// (índice de producto, cantidad, tipo de precio)
typedef SeedLine = (int, int, String);

class SeedSale {
  final int day; // 0 = hoy, -3 = hace 3 días, 5 = futura
  final List<SeedLine> lines;
  final double discount;
  final int? event; // índice en buildSeedEvents
  final int? client; // índice en seedClients
  final int? location; // índice en seedLocations
  final bool cancel;
  const SeedSale(
    this.day,
    this.lines, {
    this.discount = 0,
    this.event,
    this.client,
    this.location,
    this.cancel = false,
  });
}

// (índice de material, cantidad, precio unitario)
typedef SeedMaterialItem = (int, double, double);

class SeedPurchase {
  final int day;
  final List<SeedMaterialItem> items; // vacío = gasto general
  final double expense;
  final String? description;
  final int? supplier; // índice en seedSuppliers
  final int? location;
  final int? event;
  const SeedPurchase(
    this.day,
    this.items, {
    this.expense = 0,
    this.description,
    this.supplier,
    this.location,
    this.event,
  });

  double get total =>
      items.isEmpty ? expense : items.fold(0.0, (t, i) => t + i.$2 * i.$3);
}

const expenseHotel = 'Hotel';
const expenseFlight = 'Pasaje de avión';
const expenseBus = 'Pasaje de bus';
const expenseFairFee = 'Participación en feria';

// Compras de material (con proveedor) y gastos generales (sin proveedor: se
// guardan con "Sin proveedor") ligados a los eventos.
List<SeedPurchase> buildSeedPurchases(List<SeedEvent> events) {
  SeedPurchase expense(
    String description,
    double amount,
    int event, {
    required int day,
  }) {
    return SeedPurchase(
      day,
      const [],
      expense: amount,
      description: description,
      location: events[event].location,
      event: event,
    );
  }

  int start(int e) => events[e].start;
  int end(int e) => events[e].end;

  return [
    // Stock inicial de cada material.
    const SeedPurchase(-118, [(0, 60, 28)], supplier: 0, location: 0),
    const SeedPurchase(-118, [(1, 60, 26)], supplier: 1, location: 0),
    const SeedPurchase(-118, [(2, 12, 85)], supplier: 2, location: 1),
    const SeedPurchase(-118, [(3, 12, 80)], supplier: 2, location: 1),
    const SeedPurchase(-118, [(4, 200, 3.5)], supplier: 3, location: 2),
    const SeedPurchase(-118, [(5, 300, 2)], supplier: 3, location: 2),
    const SeedPurchase(-118, [(6, 20, 18)], supplier: 4, location: 6),
    const SeedPurchase(-118, [(7, 15, 30)], supplier: 4, location: 6),
    const SeedPurchase(-118, [(8, 40, 22)], supplier: 5, location: 7),
    // Reposiciones.
    const SeedPurchase(-84, [(0, 20, 30)], supplier: 6),
    const SeedPurchase(
      -63,
      [(4, 80, 3.6), (5, 100, 2.1)],
      supplier: 7,
      event: eventFeriaDeArte,
    ),
    const SeedPurchase(-47, [(6, 8, 18.5)], supplier: 8, location: 8),
    const SeedPurchase(-28, [(8, 15, 23)], supplier: 9),
    const SeedPurchase(-19, [(1, 20, 27)], supplier: 6),
    const SeedPurchase(-9, [(2, 4, 88), (3, 4, 82)], supplier: 2),
    const SeedPurchase(-3, [(7, 6, 31)], supplier: 4, location: 6),
    const SeedPurchase(-2, [(0, 15, 33)], supplier: 0, location: 0),
    // Participación en feria: una por evento.
    expense(
      expenseFairFee,
      150,
      eventLibroLaPaz,
      day: start(eventLibroLaPaz) - 3,
    ),
    expense(
      expenseFairFee,
      180,
      eventLibroCochabamba,
      day: start(eventLibroCochabamba) - 3,
    ),
    expense(
      expenseFairFee,
      180,
      eventLibroSantaCruz,
      day: start(eventLibroSantaCruz) - 3,
    ),
    expense(
      expenseFairFee,
      200,
      eventFeriaDeArte,
      day: start(eventFeriaDeArte) - 3,
    ),
    expense(
      expenseFairFee,
      120,
      eventExposicionDeArte,
      day: start(eventExposicionDeArte) - 3,
    ),
    expense(
      expenseFairFee,
      80,
      eventLargaNoche,
      day: start(eventLargaNoche) - 3,
    ),
    expense(
      expenseFairFee,
      350,
      eventFeriaDeLima,
      day: start(eventFeriaDeLima) - 3,
    ),
    expense(
      expenseFairFee,
      100,
      eventFeriaActiva,
      day: start(eventFeriaActiva) - 3,
    ),
    expense(
      expenseFairFee,
      160,
      eventFeriaDeOctubre,
      day: start(eventFeriaDeOctubre) - 3,
    ),
    expense(
      expenseFairFee,
      200,
      eventFeriaDeNavidad,
      day: start(eventFeriaDeNavidad) - 10,
    ),
    // Hotel.
    expense(
      expenseHotel,
      600,
      eventLibroCochabamba,
      day: start(eventLibroCochabamba),
    ),
    expense(
      expenseHotel,
      750,
      eventLibroSantaCruz,
      day: start(eventLibroSantaCruz),
    ),
    expense(expenseHotel, 1800, eventFeriaDeLima, day: start(eventFeriaDeLima)),
    expense(expenseHotel, 520, eventFeriaDeLima, day: end(eventFeriaDeLima)),
    // Pasaje de avión.
    expense(
      expenseFlight,
      1450,
      eventFeriaDeLima,
      day: start(eventFeriaDeLima) - 5,
    ),
    expense(
      expenseFlight,
      1380,
      eventFeriaDeLima,
      day: end(eventFeriaDeLima) + 1,
    ),
    expense(
      expenseFlight,
      940,
      eventLibroSantaCruz,
      day: start(eventLibroSantaCruz) - 2,
    ),
    // Pasaje de bus.
    expense(
      expenseBus,
      120,
      eventLibroCochabamba,
      day: start(eventLibroCochabamba) - 1,
    ),
    expense(
      expenseBus,
      120,
      eventLibroCochabamba,
      day: end(eventLibroCochabamba) + 1,
    ),
    expense(
      expenseBus,
      280,
      eventLibroSantaCruz,
      day: end(eventLibroSantaCruz) + 1,
    ),
    expense(expenseBus, 45, eventFeriaActiva, day: start(eventFeriaActiva)),
    // Futura: no cuenta en los totales.
    const SeedPurchase(6, [(1, 30, 27)], supplier: 6),
  ];
}

// Ventas de 16 semanas completas con tendencia al alza (sin evento), ventas
// ligadas a cada evento (con la fecha propia de la venta), ventas de hoy, una
// cancelada y dos futuras.
List<SeedSale> buildSeedSales(DateTime today, List<SeedEvent> events) {
  final sales = <SeedSale>[];
  final mondayOffset = -(today.weekday - DateTime.monday);
  var seed = 20261003;
  int next(int max) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed % max;
  }

  // "Libro" no se vende nunca, "Estuches" solo hace más de 60 días y
  // "Stickers holográficos" solo hace más de 30 días.
  bool allowed(int product, int day) =>
      product != 8 &&
      !(product == 7 && day >= -60) &&
      !(product == 6 && day > -30);
  int draw(List<int> mix, int day) {
    var product = mix[next(mix.length)];
    while (!allowed(product, day)) {
      product = mix[next(mix.length)];
    }
    return product;
  }

  // Más peso para los productos de mayor rotación.
  const sellable = [0, 1, 2, 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7, 0, 1, 5];
  const weekdays = [1, 2, 3, 4, 5, 6, 3];
  for (var k = 16; k >= 1; k--) {
    final count = 1 + (16 - k) ~/ 5;
    for (var i = 0; i < count; i++) {
      final day = mondayOffset - 7 * k + weekdays[(i + k) % weekdays.length];
      final product = draw(sellable, day);
      final price = seedProducts[product].priceA;
      final qty = price >= 70 ? 1 : 1 + next(3);
      final type = next(2) == 0 ? 'A' : 'B';
      final gross = qty * (type == 'A' ? price : seedProducts[product].priceB);
      final clientIndex = next(12);
      final locationIndex = next(14);
      sales.add(
        SeedSale(
          day,
          [(product, qty, type)],
          discount: gross >= 40 && next(8) == 0 ? 5.0 : 0,
          client: clientIndex < 10 ? clientIndex : null,
          location: locationIndex < 10 ? locationIndex : null,
        ),
      );
    }
  }

  // Ventas de cada evento, en los días del evento (hasta hoy).
  const perEvent = {
    eventLibroLaPaz: 6,
    eventLibroCochabamba: 6,
    eventLibroSantaCruz: 6,
    eventFeriaDeArte: 8,
    eventExposicionDeArte: 5,
    eventFeriaCancelada: 2,
    eventLargaNoche: 4,
    eventFeriaDeLima: 7,
    eventFeriaActiva: 5,
    eventFeriaDeOctubre: 3,
  };
  const libroMix = [5, 6, 2, 4, 0, 5];
  const generalMix = [0, 1, 7, 3, 4, 6, 5, 2];
  perEvent.forEach((event, count) {
    final e = events[event];
    final lastDay = e.end > 0 ? 0 : e.end;
    final days = lastDay - e.start + 1;
    for (var i = 0; i < count; i++) {
      final day = e.start + (days <= 0 ? 0 : i % days);
      final mix = event <= eventLibroSantaCruz ? libroMix : generalMix;
      final product = draw(mix, day);
      final lines = <SeedLine>[
        (
          product,
          seedProducts[product].priceA >= 70 ? 1 : 1 + next(3),
          next(2) == 0 ? 'A' : 'B',
        ),
      ];
      if (next(3) == 0) {
        final extra = draw(generalMix, day);
        if (extra != product) lines.add((extra, 1, 'A'));
      }
      sales.add(
        SeedSale(
          day,
          lines,
          event: event,
          client: next(3) == 0 ? next(10) : null,
          location: e.location,
        ),
      );
    }
  });

  // Ligada a la Feria de Arte, pero con fecha propia fuera de ella.
  sales.add(
    const SeedSale(-70, [(1, 2, 'A')], event: eventFeriaDeArte, location: 1),
  );

  // Ventas con varios productos, para "Productos comprados juntos", repartidas
  // por TODOS los días de la semana (las ventas semanales de arriba no caen en
  // lunes) y varias con descuento. Son explícitas (no consumen números
  // aleatorios). Sin "Libro", "Estuches" ni "Stickers holográficos", que
  // tienen su propio escenario de inventario.
  int weekdayAgo(int weeksAgo, int weekday) =>
      mondayOffset - 7 * weeksAgo + (weekday - DateTime.monday);
  const monday = DateTime.monday;
  const tuesday = DateTime.tuesday;
  const wednesday = DateTime.wednesday;
  const thursday = DateTime.thursday;
  const friday = DateTime.friday;
  const saturday = DateTime.saturday;
  const sunday = DateTime.sunday;
  // Tote bag negra + Pines grandes: el par que más se repite.
  sales.add(
    SeedSale(
      weekdayAgo(2, monday),
      const [(0, 1, 'A'), (3, 2, 'A')],
      discount: 5,
      client: 0,
      location: 0,
    ),
  );
  sales.add(
    SeedSale(
      weekdayAgo(3, wednesday),
      const [(0, 1, 'B'), (3, 1, 'B')],
      client: 4,
    ),
  );
  sales.add(
    SeedSale(
      weekdayAgo(5, friday),
      const [(0, 2, 'A'), (3, 3, 'A')],
      discount: 10,
      location: 1,
    ),
  );
  sales.add(
    SeedSale(
      weekdayAgo(7, sunday),
      const [(0, 1, 'A'), (3, 1, 'A')],
      client: 6,
    ),
  );
  // Stickers + Set de pines pequeños: justo el mínimo de 3 ventas.
  sales.add(
    SeedSale(
      weekdayAgo(2, tuesday),
      const [(5, 3, 'A'), (4, 1, 'A')],
      client: 8,
      location: 2,
    ),
  );
  sales.add(
    SeedSale(
      weekdayAgo(4, thursday),
      const [(5, 2, 'B'), (4, 1, 'B')],
      discount: 5,
    ),
  );
  sales.add(
    SeedSale(
      weekdayAgo(6, saturday),
      const [(5, 4, 'A'), (4, 2, 'A'), (3, 1, 'B')],
      client: 2,
      location: 3,
    ),
  );
  // Tote bag beige + Miniaturas: solo 2 ventas, por debajo del mínimo.
  sales.add(
    SeedSale(
      weekdayAgo(1, thursday),
      const [(1, 1, 'A'), (2, 1, 'A')],
      client: 1,
    ),
  );
  sales.add(
    SeedSale(
      weekdayAgo(8, saturday),
      const [(1, 1, 'B'), (2, 1, 'B')],
      discount: 10,
    ),
  );
  // Un evento con ventas de varios productos que sí deja ganancia (sus gastos
  // son solo la participación en la feria).
  sales.add(
    SeedSale(
      events[eventLargaNoche].start,
      const [(0, 1, 'A'), (3, 2, 'A')],
      event: eventLargaNoche,
      location: events[eventLargaNoche].location,
    ),
  );
  sales.add(
    SeedSale(
      events[eventFeriaDeOctubre].start,
      const [(0, 1, 'A'), (3, 1, 'A')],
      event: eventFeriaDeOctubre,
      location: events[eventFeriaDeOctubre].location,
    ),
  );

  // Ventas antiguas de "Estuches" (la última hace más de 60 días) y de
  // "Stickers holográficos" (producto desactivado).
  sales.add(const SeedSale(-95, [(7, 2, 'A')], client: 1));
  sales.add(const SeedSale(-80, [(7, 1, 'B')]));
  sales.add(const SeedSale(-62, [(7, 1, 'A')], client: 5, location: 6));
  sales.add(const SeedSale(-58, [(6, 3, 'A')], client: 2));
  sales.add(const SeedSale(-45, [(6, 2, 'B')]));
  sales.add(const SeedSale(-33, [(6, 4, 'A')], location: 3));

  // Hoy y ayer.
  sales.add(
    const SeedSale(
      0,
      [(3, 2, 'B'), (5, 3, 'A')],
      discount: 5,
      client: 3,
      location: 0,
    ),
  );
  sales.add(const SeedSale(0, [(2, 1, 'A')], client: 7));
  sales.add(const SeedSale(-1, [(1, 1, 'A')], client: 2, location: 1));

  // Una cancelada y dos futuras (la segunda, de un evento aún sin ventas
  // pasadas, no cuenta hasta que ocurra).
  sales.add(const SeedSale(-3, [(2, 1, 'A')], cancel: true, client: 4));
  sales.add(const SeedSale(4, [(0, 1, 'A')], event: eventFeriaActiva));
  sales.add(const SeedSale(9, [(4, 1, 'B')]));

  // La cancelada se crea primero (se cancela justo después de crearla).
  sales.sort((a, b) {
    if (a.cancel != b.cancel) return a.cancel ? -1 : 1;
    return a.day.compareTo(b.day);
  });
  return sales;
}

DateTime _at(DateTime today, int dayOffset) =>
    DateTime(today.year, today.month, today.day + dayOffset, 12);

// Carga los datos de ejemplo. Devuelve false (sin tocar nada) si ya hay
// productos; lanza si algo falla.
Future<bool> seedSampleData(ProviderContainer c, {DateTime? now}) async {
  final today = now ?? DateTime.now();
  DateTime at(int d) => _at(today, d);

  await c.read(productProvider.notifier).load();
  if (c.read(productProvider).products.isNotEmpty) return false;

  final events = buildSeedEvents(today);
  final sales = buildSeedSales(today, events);
  final purchases = buildSeedPurchases(events);

  // Categorías (la predeterminada "Sin categoría" ya existe).
  for (final cat in seedCategories) {
    await c
        .read(categoryProvider.notifier)
        .save(name: cat.name, description: cat.description);
  }
  final categoryId = {
    for (final cat in c.read(categoryProvider).categories) cat.name: cat.id,
  };

  // Clientes, proveedores y ubicaciones.
  for (final (name, contact) in seedClients) {
    final error = await c
        .read(clientProvider.notifier)
        .save(name: name, contactInfo: contact);
    if (error != null) throw StateError('cliente: $error');
  }
  for (final (name, contact) in seedSuppliers) {
    final error = await c
        .read(supplierProvider.notifier)
        .save(name: name, contactInfo: contact);
    if (error != null) throw StateError('proveedor: $error');
  }
  for (final (name, country) in seedLocations) {
    await c.read(locationProvider.notifier).save(city: name, country: country);
  }
  final clientId = [
    for (final (name, _) in seedClients)
      c.read(clientProvider).clients.firstWhere((x) => x.name == name).id,
  ];
  final supplierId = [
    for (final (name, _) in seedSuppliers)
      c.read(supplierProvider).suppliers.firstWhere((x) => x.name == name).id,
  ];
  final locationId = [
    for (final (name, _) in seedLocations)
      c.read(locationProvider).locations.firstWhere((x) => x.city == name).id,
  ];

  // Productos: el stock inicial deja justo "remaining" tras las ventas.
  for (var i = 0; i < seedProducts.length; i++) {
    final p = seedProducts[i];
    int qty(bool Function(SeedSale) where) => sales
        .where(where)
        .expand((s) => s.lines)
        .where((l) => l.$1 == i)
        .fold(0, (t, l) => t + l.$2);
    final kept = qty((s) => !s.cancel);
    final canceled = qty((s) => s.cancel);
    final initial = kept + p.remaining;
    if (initial < canceled) throw StateError('stock inicial corto: ${p.name}');
    await c
        .read(productProvider.notifier)
        .save(
          categoryId: p.category == null ? null : categoryId[p.category],
          name: p.name,
          priceA: p.priceA,
          priceB: p.priceB,
          productionCost: p.cost,
          stock: initial,
        );
  }
  await c.read(productProvider.notifier).load();
  final productId = [
    for (final p in seedProducts)
      c.read(productProvider).products.firstWhere((x) => x.name == p.name).id,
  ];

  // Eventos (uno de ellos desactivado).
  for (final e in events) {
    await c
        .read(eventProvider.notifier)
        .save(
          name: e.name,
          locationId: locationId[e.location],
          startDate: at(e.start),
          endDate: at(e.end),
          isActive: e.active,
        );
  }
  final eventId = [
    for (final e in events)
      c.read(eventProvider).events.firstWhere((x) => x.name == e.name).id,
  ];

  // Materiales (con stock 0: el stock llega con las compras).
  await c.read(unitProvider.notifier).load();
  final units = c.read(unitProvider).units;
  int unitId(String name) => units.firstWhere((u) => u.name == name).id;
  for (final m in seedMaterials) {
    await c
        .read(materialProvider.notifier)
        .save(name: m.name, unitId: unitId(m.unit), stock: 0, pricePerUnit: 1);
  }
  final materialId = [
    for (final m in seedMaterials)
      c.read(materialProvider).materials.firstWhere((x) => x.name == m.name).id,
  ];

  // Compras, de la más antigua a la más reciente.
  final orderedPurchases = [...purchases]
    ..sort((a, b) => a.day.compareTo(b.day));
  for (final p in orderedPurchases) {
    final error = await c
        .read(purchaseProvider.notifier)
        .createPurchase(
          supplierId: p.supplier == null ? null : supplierId[p.supplier!],
          locationId: p.location == null ? null : locationId[p.location!],
          eventId: p.event == null ? null : eventId[p.event!],
          isMaterial: p.items.isNotEmpty,
          description: p.description,
          totalAmount: p.total,
          date: at(p.day),
          items: [
            for (final i in p.items)
              {
                'materialId': materialId[i.$1],
                'quantity': i.$2,
                'unitPrice': i.$3,
              },
          ],
        );
    if (error != null) throw StateError('compra: $error');
  }

  // Ventas.
  for (final s in sales) {
    double priceOf(SeedLine l) =>
        l.$3 == 'A' ? seedProducts[l.$1].priceA : seedProducts[l.$1].priceB;
    final gross = s.lines.fold(0.0, (t, l) => t + l.$2 * priceOf(l));
    final error = await c
        .read(saleProvider.notifier)
        .createSale(
          clientId: s.client == null ? null : clientId[s.client!],
          locationId: s.location == null ? null : locationId[s.location!],
          eventId: s.event == null ? null : eventId[s.event!],
          totalAmount: gross,
          discount: s.discount,
          finalAmount: gross - s.discount,
          date: at(s.day),
          items: [
            for (final l in s.lines)
              {
                'productId': productId[l.$1],
                'quantity': l.$2,
                'unitPrice': priceOf(l),
                'priceType': l.$3,
              },
          ],
        );
    if (error != null) throw StateError('venta: $error');
    if (s.cancel) {
      final created = c
          .read(saleProvider)
          .sales
          .firstWhere((x) => x.totalAmount == gross && x.date == at(s.day));
      final cancelError = await c
          .read(saleProvider.notifier)
          .cancelSale(created.id);
      if (cancelError != null) throw StateError('cancelar: $cancelError');
    }
  }

  // Registros de uso de material.
  for (final u in seedUsage) {
    final error = await c
        .read(materialProvider.notifier)
        .registerUsage(
          productId: productId[u.$1],
          materialId: materialId[u.$2],
          quantityUsed: u.$3,
        );
    if (error != null) throw StateError('uso: $error');
  }

  // Un registro de uso cancelado.
  final usageRecords = await c
      .read(materialProvider.notifier)
      .getMaterialsForProduct(productId[seedCanceledUsage.$1]);
  final canceledUsage = usageRecords.firstWhere(
    (x) => x.materialId == materialId[seedCanceledUsage.$2],
  );
  final cancelUsageError = await c
      .read(materialProvider.notifier)
      .cancelUsage(canceledUsage.id);
  if (cancelUsageError != null) throw StateError('uso: $cancelUsageError');

  // Registros inactivos (con las ventas y compras ya creadas).
  await c.read(productProvider.notifier).load();
  await c.read(materialProvider.notifier).load();
  final client = c
      .read(clientProvider)
      .clients
      .firstWhere((x) => x.name == seedInactiveClient);
  await c
      .read(clientProvider.notifier)
      .save(
        id: client.id,
        name: client.name,
        contactInfo: client.contactInfo,
        isActive: false,
      );
  final supplier = c
      .read(supplierProvider)
      .suppliers
      .firstWhere((x) => x.name == seedInactiveSupplier);
  await c
      .read(supplierProvider.notifier)
      .save(
        id: supplier.id,
        name: supplier.name,
        contactInfo: supplier.contactInfo,
        isActive: false,
      );
  final location = c
      .read(locationProvider)
      .locations
      .firstWhere((x) => x.city == seedInactiveLocation);
  await c
      .read(locationProvider.notifier)
      .save(
        id: location.id,
        city: location.city,
        country: location.country,
        isActive: false,
      );
  final material = c
      .read(materialProvider)
      .materials
      .firstWhere((x) => x.name == seedInactiveMaterial);
  await c
      .read(materialProvider.notifier)
      .save(
        id: material.id,
        name: material.name,
        unitId: material.unitId,
        stock: material.stock,
        pricePerUnit: material.pricePerUnit,
        isActive: false,
      );
  final product = c
      .read(productProvider)
      .products
      .firstWhere((x) => x.name == seedInactiveProduct);
  await c
      .read(productProvider.notifier)
      .save(
        id: product.id,
        categoryId: product.categoryId,
        name: product.name,
        priceA: product.priceA,
        priceB: product.priceB,
        productionCost: product.productionCost,
        stock: product.stock,
        isActive: false,
      );
  await c
      .read(categoryProvider.notifier)
      .deactivate(categoryId[seedInactiveCategory]!);

  await c.read(materialProvider.notifier).load();
  await c.read(productProvider.notifier).load();
  return true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  final container = ProviderContainer();
  try {
    final seeded = await seedSampleData(container);
    print(
      seeded
          ? 'SEED: datos de ejemplo cargados'
          : 'SEED: la base ya tiene productos, no se carga nada',
    );
  } catch (e, st) {
    print('SEED ERROR: $e\n$st');
  }
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
