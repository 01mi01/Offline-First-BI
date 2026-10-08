import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/category_provider.dart';
import 'package:offline_first_bi/application/client_provider.dart';
import 'package:offline_first_bi/application/event_provider.dart';
import 'package:offline_first_bi/application/location_provider.dart';
import 'package:offline_first_bi/application/material_provider.dart';
import 'package:offline_first_bi/application/product_provider.dart';
import 'package:offline_first_bi/application/purchase_provider.dart';
import 'package:offline_first_bi/application/sale_provider.dart';
import 'package:offline_first_bi/application/supplier_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart' show SaleItem;
import 'package:offline_first_bi/config/rounding.dart';
import 'package:offline_first_bi/models/bi_models.dart';
import 'package:offline_first_bi/models/location_model.dart';
import 'package:offline_first_bi/models/default_records.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/models/sale_model.dart';
import 'package:offline_first_bi/seed_main.dart';
import '../support/bi_harness.dart';

// Los datos de ejemplo de lib/seed_main.dart: se cargan solo por los
// notifiers (repositorios), con los nombres aprobados, y ejercitan Reportes y
// Business Intelligence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = BiHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  const clients = [
    'John Smith',
    'Emily Johnson',
    'Ana Martínez',
    'Michael Brown',
    'Sarah Davis',
    'David Wilson',
    'Jessica Taylor',
    'Daniel Anderson',
    'Laura Thompson',
    'Robert Clark',
  ];
  const suppliers = [
    'Riverside Supply Co.',
    'Lino & Co.',
    'Aurelia Studio',
    'Bellamy House',
    'Monroe Studio',
    'Lunaris Supply',
    'Veridian Trading',
    'Harbor Textiles',
    'Crestview Supply',
    'Northgate Trading',
  ];
  const locations = [
    'La Paz - Calacoto',
    'La Paz - San Miguel',
    'La Paz - Achumani',
    'La Paz - Los Pinos',
    'La Paz - Irpavi',
    'La Paz - Bolognia',
    'Santa Cruz - Equipetrol',
    'Santa Cruz - Las Palmas',
    'Santa Cruz - Urubó',
    'Santa Cruz - Sirari',
    'Cochabamba - Campo Ferial FEXCO',
    'Lima - Miraflores',
  ];
  const materials = {
    'Tela negra': 'metro',
    'Tela beige': 'metro',
    'Resina parte A': 'contenedor',
    'Resina parte B': 'contenedor',
    'Base metálica grande para pines': 'unidad',
    'Base metálica pequeña para pines': 'unidad',
    'Papel para stickers': 'paquete',
    'Papel holográfico para stickers': 'paquete',
    'Tela para estuches': 'metro',
  };
  const products = [
    'Tote bag negra',
    'Tote bag beige',
    'Miniaturas',
    'Pines grandes',
    'Set de pines pequeños',
    'Stickers',
    'Stickers holográficos',
    'Estuches',
    'Libro',
  ];

  Future<void> seed() async {
    expect(await seedSampleData(h.container, now: h.now), isTrue);
    await h.refresh();
  }

  DateTime day(int offset) => h.day(offset, 0);

  // "Ciudad - Zona": the plain city plus the zone kept in the description.
  String zoneLabel(LocationModel l) => '${l.city} - ${l.description}';

  test(
    'creates exactly the approved clients, suppliers, locations, materials and products',
    () async {
      await seed();
      final c = h.container;
      expect(c.read(clientProvider).clients.map((x) => x.name).toSet(), {
        ...clients,
        DefaultRecords.client,
      });
      expect(c.read(supplierProvider).suppliers.map((x) => x.name).toSet(), {
        ...suppliers,
        DefaultRecords.supplier,
      });
      expect(
        c.read(locationProvider).locations.map(zoneLabel).toList()..sort(),
        [...locations]..sort(),
      );
      // The Ciudad filter lists each plain city once; the zone lives in the
      // description.
      expect(
        c.read(locationProvider).locations.map((x) => x.city).toSet(),
        {'La Paz', 'Santa Cruz', 'Cochabamba', 'Lima'},
      );
      final countries = {
        for (final x in c.read(locationProvider).locations)
          zoneLabel(x): x.country,
      };
      expect(countries['Lima - Miraflores'], 'Perú');
      expect(
        countries.entries
            .where((e) => e.key != 'Lima - Miraflores')
            .every((e) => e.value == 'Bolivia'),
        isTrue,
      );
      expect(
        c.read(productProvider).products.map((x) => x.name).toSet(),
        products.toSet(),
      );
      final loaded = c.read(materialProvider).materials;
      expect(loaded.map((m) => m.name).toSet(), materials.keys.toSet());
      final unitNames = {
        for (final u in (await h.db.select(h.db.units).get())) u.id: u.name,
      };
      for (final m in loaded) {
        expect(unitNames[m.unitId], materials[m.name], reason: m.name);
      }
    },
  );

  test(
    'every product costs less than both of its prices and the categories are the approved ones',
    () async {
      await seed();
      final list = h.container.read(productProvider).products;
      for (final p in list) {
        expect(p.productionCost, isNotNull, reason: p.name);
        expect(p.productionCost!, lessThan(p.priceA), reason: p.name);
        expect(p.productionCost!, lessThan(p.priceB), reason: p.name);
      }
      final categories = {
        for (final c in h.container.read(categoryProvider).categories) c.id: c,
      };
      expect(categories.values.map((c) => c.name).toSet(), {
        'Bolsas',
        'Pines',
        'Papelería',
        'Miniaturas',
        'Libros',
        DefaultRecords.category,
      });
      for (final c in categories.values.where(
        (c) => c.name != DefaultRecords.category,
      )) {
        expect(c.description, isNotNull, reason: c.name);
        expect(c.description!.length, lessThan(60), reason: c.name);
      }
      final byCategory = <String, Set<String>>{};
      for (final p in list) {
        byCategory
            .putIfAbsent(categories[p.categoryId]!.name, () => {})
            .add(p.name);
      }
      expect(byCategory, {
        'Bolsas': {'Tote bag negra', 'Tote bag beige'},
        'Pines': {'Pines grandes', 'Set de pines pequeños'},
        'Papelería': {'Stickers', 'Stickers holográficos'},
        'Miniaturas': {'Miniaturas'},
        'Libros': {'Libro'},
        DefaultRecords.category: {'Estuches'},
      });
    },
  );

  test(
    'material usage links: eight products use materials, "Libro" uses none',
    () async {
      await seed();
      final productList = h.container.read(productProvider).products;
      final usage = await h.db.select(h.db.productMaterials).get();
      expect(usage.length, 9);
      expect(usage.every((u) => u.quantityUsed > 0), isTrue);
      expect(usage.where((u) => u.isCanceled).length, 1);
      final libro = productList.firstWhere((p) => p.name == 'Libro');
      expect(usage.where((u) => u.productId == libro.id), isEmpty);
      final miniaturas = productList.firstWhere((p) => p.name == 'Miniaturas');
      expect(usage.where((u) => u.productId == miniaturas.id).length, 2);
      // Ningún material queda con stock negativo.
      expect(
        h.container.read(materialProvider).materials.every((m) => m.stock >= 0),
        isTrue,
      );
    },
  );

  test(
    'sales span about 17 weeks, mix prices, use discounts, clients and locations',
    () async {
      await seed();
      final sales = h.container.read(saleProvider).sales;
      final valid = sales.where((s) => !s.isCanceled && !s.date.isAfter(h.now));
      final first = valid
          .map((s) => s.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      expect(h.now.difference(first).inDays, greaterThanOrEqualTo(100));
      expect(sales.length, greaterThan(60));
      expect(sales.any((s) => s.discount > 0), isTrue);
      expect(sales.any((s) => s.clientId != null), isTrue);
      expect(sales.any((s) => s.locationId != null), isTrue);
      final items = await h.db.select(h.db.saleItems).get();
      expect({for (final i in items) i.priceType}, {'A', 'B'});
      // Cada semana completa del historial tiene ventas.
      final monday = day(-(h.now.weekday - 1));
      final weeks = {
        for (final s in valid) (s.date.difference(monday).inDays / 7).floor(),
      };
      expect(weeks.length, greaterThanOrEqualTo(16));
    },
  );

  test('one canceled sale and future-dated records that never count', () async {
    await seed();
    final sales = h.container.read(saleProvider).sales;
    expect(sales.where((s) => s.isCanceled).length, 1);
    final futureSales = sales.where((s) => s.date.isAfter(h.now));
    expect(futureSales.length, greaterThanOrEqualTo(1));
    final purchases = h.container.read(purchaseProvider).purchases;
    expect(
      purchases.where((p) => p.date.isAfter(h.now)).length,
      greaterThanOrEqualTo(1),
    );
    // Ni la cancelada ni las futuras entran en los totales.
    final counted = sales
        .where((s) => !s.isCanceled && !s.date.isAfter(h.now))
        .fold(0.0, (t, s) => t + s.finalAmount);
    expect(h.report().summary.ingresos, closeTo(counted, 1e-6));
    final spent = purchases
        .where((p) => !p.date.isAfter(h.now))
        .fold(0.0, (t, p) => t + p.totalAmount);
    expect(h.report().summary.gastos, closeTo(spent, 1e-6));
  });

  test('purchases cover both Material and Gasto, with suppliers', () async {
    await seed();
    final purchases = h.container.read(purchaseProvider).purchases;
    expect(purchases.any((p) => p.isMaterial), isTrue);
    expect(purchases.any((p) => !p.isMaterial), isTrue);
    expect(purchases.where((p) => p.supplierId != null).length, greaterThan(5));
    expect(purchases.length, greaterThanOrEqualTo(15));
  });

  test(
    'eleven approved events with the right locations, dates and links',
    () async {
      await seed();
      final c = h.container;
      final events = {for (final e in c.read(eventProvider).events) e.name: e};
      expect(events.keys.toSet(), {
        'Feria del Libro Cochabamba',
        'Feria del Libro Santa Cruz',
        'Feria del Libro La Paz',
        'Feria de Arte',
        'Exposición de Arte',
        'Feria de Octubre',
        'Larga Noche de Museos La Paz',
        'Feria Activa',
        'Feria Cancelada',
        'Feria de Navidad',
        'Feria de Lima',
      });
      final cities = {
        for (final l in c.read(locationProvider).locations) l.id: zoneLabel(l),
      };
      String cityOf(String event) => cities[events[event]!.locationId]!;
      expect(cityOf('Feria de Lima'), 'Lima - Miraflores');
      expect(
        cityOf('Feria del Libro Cochabamba'),
        'Cochabamba - Campo Ferial FEXCO',
      );
      expect(cityOf('Feria del Libro Santa Cruz'), startsWith('Santa Cruz'));
      expect(cityOf('Feria del Libro La Paz'), startsWith('La Paz'));
      expect(cityOf('Larga Noche de Museos La Paz'), startsWith('La Paz'));
      expect(events.values.where((e) => !e.isActive).map((e) => e.name), [
        'Feria Cancelada',
      ]);
      final october = events['Feria de Octubre']!.startDate;
      expect((october.year, october.month), (h.now.year, h.now.month));
      final christmas = events['Feria de Navidad']!.startDate;
      expect((christmas.year, christmas.month), (h.now.year, 12));
      expect(christmas.isAfter(h.now), isTrue);
      final past = events.values
          .where((e) => e.startDate.isBefore(h.now))
          .length;
      expect(past, greaterThanOrEqualTo(10));

      final sales = c.read(saleProvider).sales;
      int linked(String event) =>
          sales.where((s) => s.eventId == events[event]!.id).length;
      for (final name in events.keys.where((n) => n != 'Feria de Navidad')) {
        expect(linked(name), greaterThanOrEqualTo(2), reason: name);
      }
      expect(linked('Feria de Lima'), greaterThanOrEqualTo(5));
      expect(linked('Feria de Navidad'), 0);
      expect(sales.where((s) => s.eventId == null).length, greaterThan(20));
      // Cada venta ligada conserva su propia fecha.
      for (final e in events.values.where(
        (e) => e.name != 'Feria de Navidad',
      )) {
        final inEvent = sales.where(
          (s) => s.eventId == e.id && !s.isCanceled && !s.date.isAfter(h.now),
        );
        expect(inEvent, isNotEmpty, reason: e.name);
      }
    },
  );

  test(
    'general expenses use only the four approved descriptions and link to events',
    () async {
      await seed();
      final c = h.container;
      final events = {
        for (final e in c.read(eventProvider).events) e.name: e.id,
      };
      final defaultSupplier = c
          .read(supplierProvider)
          .suppliers
          .firstWhere((s) => s.name == DefaultRecords.supplier)
          .id;
      final expenses = c
          .read(purchaseProvider)
          .purchases
          .where((p) => !p.isMaterial)
          .toList();
      const allowed = {
        'Hotel',
        'Pasaje de avión',
        'Pasaje de bus',
        'Participación en feria',
      };
      expect(expenses.map((p) => p.description).toSet(), allowed);
      for (final d in allowed) {
        expect(
          expenses.where((p) => p.description == d).length,
          greaterThanOrEqualTo(3),
          reason: d,
        );
      }
      for (final p in expenses) {
        expect(p.eventId, isNotNull, reason: p.description);
        expect(p.supplierId == null || p.supplierId == defaultSupplier, isTrue);
        expect(p.totalAmount, greaterThan(0));
      }
      final lima = expenses
          .where((p) => p.eventId == events['Feria de Lima'])
          .map((p) => p.description);
      expect(lima, containsAll(['Pasaje de avión', 'Hotel']));
      expect(expenses.map((p) => p.date).toSet().length, greaterThan(10));
    },
  );

  test(
    'Business Intelligence has data for every indicator that needs history',
    () async {
      await seed();
      final r = h.report();
      expect(r.summary.ingresos, greaterThan(0));
      expect(r.summary.gastos, greaterThan(0));
      expect(r.salesByProduct.length, products.length - 1);
      expect(r.salesByEvent.length, 10);
      expect(r.salesByPriceType.map((e) => e.label), ['Precio A', 'Precio B']);
      expect(r.purchasesByMaterial, isNotEmpty);
      expect(r.projection.isAvailable, isTrue);
      expect(r.projection.granularity, BiGranularity.week);
      expect(r.productMargins.entries.length, products.length - 1);
      expect(r.productMargins.entries.every((e) => e.marginPct > 0), isTrue);
      expect(r.eventComparison.eventDays, greaterThan(0));
      expect(r.eventComparison.regularDays, greaterThan(0));
      expect(
        r.lowStock.map((e) => e.product.name),
        containsAll(['Libro', 'Pines grandes']),
      );
      expect(r.radar.products.length, 3);
    },
  );

  test('every client and supplier has fake contact info', () async {
    await seed();
    final c = h.container;
    final people = <(String, String?)>[
      for (final x in c.read(clientProvider).clients)
        if (clients.contains(x.name)) (x.name, x.contactInfo),
      for (final x in c.read(supplierProvider).suppliers)
        if (suppliers.contains(x.name)) (x.name, x.contactInfo),
    ];
    expect(people.length, 20);
    final valid = RegExp(
      r'^([a-z0-9.]+@example\.com|\+591 7000 \d{4}|@[a-z0-9]+)$',
    );
    for (final p in people) {
      expect(p.$2, isNotNull, reason: p.$1);
      for (final part in p.$2!.split(' | ')) {
        expect(valid.hasMatch(part), isTrue, reason: '${p.$1}: $part');
      }
    }
    expect(people.map((p) => p.$2).toSet().length, 20);
    final shapes = {
      for (final p in people)
        (
          p.$2!.contains('@example.com'),
          p.$2!.contains('+591'),
          p.$2!.split(' | ').any((x) => x.startsWith('@')),
        ),
    };
    expect(shapes.length, greaterThanOrEqualTo(5));
  });

  test(
    'descriptions and notes stay empty except categories and expense types',
    () async {
      await seed();
      final c = h.container;
      expect(
        c.read(productProvider).products.every((x) => x.description == null),
        isTrue,
      );
      expect(
        c.read(materialProvider).materials.every((x) => x.description == null),
        isTrue,
      );
      // Locations keep their zone in the description (seed cleanup).
      expect(
        c.read(locationProvider).locations.every(
          (x) => x.description != null && x.description!.isNotEmpty,
        ),
        isTrue,
      );
      expect(c.read(saleProvider).sales.every((x) => x.notes == null), isTrue);
      final purchases = c.read(purchaseProvider).purchases;
      expect(purchases.every((x) => x.notes == null), isTrue);
      expect(
        purchases
            .where((x) => x.isMaterial)
            .every((x) => x.description == null),
        isTrue,
      );
      final described = c
          .read(categoryProvider)
          .categories
          .where((x) => x.name != DefaultRecords.category);
      expect(described.every((x) => (x.description ?? '').isNotEmpty), isTrue);
    },
  );

  test(
    'exactly the chosen records are inactive and the defaults never are',
    () async {
      await seed();
      final c = h.container;
      final inactiveClients = c
          .read(clientProvider)
          .clients
          .where((x) => !x.isActive)
          .map((x) => x.name);
      expect(inactiveClients, ['Robert Clark']);
      final inactiveSuppliers = c
          .read(supplierProvider)
          .suppliers
          .where((x) => !x.isActive)
          .map((x) => x.name);
      expect(inactiveSuppliers, ['Northgate Trading']);
      final inactiveLocations = c
          .read(locationProvider)
          .locations
          .where((x) => !x.isActive)
          .map(zoneLabel);
      expect(inactiveLocations, ['Santa Cruz - Sirari']);
      final inactiveMaterials = c
          .read(materialProvider)
          .materials
          .where((x) => !x.isActive)
          .map((x) => x.name);
      expect(inactiveMaterials, ['Base metálica pequeña para pines']);
      final categories = c.read(categoryProvider).categories;
      expect(categories.where((x) => !x.isActive).map((x) => x.name), [
        'Libros',
      ]);
      final inactiveProducts = c
          .read(productProvider)
          .products
          .where((x) => !x.isActive)
          .map((x) => x.name);
      expect(inactiveProducts, ['Stickers holográficos']);
      final inactiveEvents = c
          .read(eventProvider)
          .events
          .where((x) => !x.isActive)
          .map((x) => x.name);
      expect(inactiveEvents, ['Feria Cancelada']);

      expect(
        categories
            .firstWhere((x) => x.name == DefaultRecords.category)
            .isActive,
        isTrue,
      );
      final defaultClient = c
          .read(clientProvider)
          .clients
          .firstWhere((x) => x.name == DefaultRecords.client);
      expect(defaultClient.isActive, isTrue);
      final defaultSupplier = c
          .read(supplierProvider)
          .suppliers
          .firstWhere((x) => x.name == DefaultRecords.supplier);
      expect(defaultSupplier.isActive, isTrue);

      final robert = c
          .read(clientProvider)
          .clients
          .firstWhere((x) => x.name == 'Robert Clark');
      expect(robert.contactInfo, 'robert.clark@example.com');
      final stickers = c
          .read(productProvider)
          .products
          .firstWhere((x) => x.name == 'Stickers holográficos');
      expect(
        (stickers.priceA, stickers.priceB, stickers.productionCost),
        (18, 15, 5),
      );
    },
  );

  test('the deactivated product keeps a few older sales', () async {
    await seed();
    final c = h.container;
    final id = c
        .read(productProvider)
        .products
        .firstWhere((x) => x.name == 'Stickers holográficos')
        .id;
    final items = await h.db.select(h.db.saleItems).get();
    final sales = {for (final s in c.read(saleProvider).sales) s.id: s};
    final soldOn = [
      for (final i in items.where((i) => i.productId == id))
        if (!sales[i.saleId]!.isCanceled) sales[i.saleId]!.date,
    ];
    expect(soldOn.length, greaterThanOrEqualTo(3));
    expect(soldOn.every((d) => h.now.difference(d).inDays >= 30), isTrue);
  });

  test(
    'Business Intelligence scenarios: low stock, no recent sales, never sold',
    () async {
      await seed();
      final c = h.container;
      final byName = {
        for (final p in c.read(productProvider).products) p.name: p,
      };
      expect(byName['Set de pines pequeños']!.stock, lessThanOrEqualTo(3));
      final r = h.report();
      expect(
        r.lowStock.map((e) => e.product.name),
        containsAll(['Set de pines pequeños', 'Pines grandes', 'Libro']),
      );

      final items = await h.db.select(h.db.saleItems).get();
      final sales = {for (final s in c.read(saleProvider).sales) s.id: s};
      List<DateTime> datesOf(String name) => [
        for (final i in items.where((i) => i.productId == byName[name]!.id))
          if (!sales[i.saleId]!.isCanceled) sales[i.saleId]!.date,
      ];
      expect(items.where((i) => i.productId == byName['Libro']!.id), isEmpty);
      final estuches = datesOf('Estuches');
      expect(estuches, isNotEmpty);
      expect(estuches.every((d) => h.now.difference(d).inDays > 60), isTrue);

      final stale = {for (final e in r.noMovement) e.product.name: e};
      expect(stale.keys, containsAll(['Estuches', 'Libro']));
      expect(stale['Libro']!.lastSale, isNull);
      expect(stale['Estuches']!.daysSinceLastSale, greaterThan(60));
    },
  );

  test(
    'one canceled material usage: Estuches with Tela para estuches',
    () async {
      await seed();
      final c = h.container;
      final usage = await h.db.select(h.db.productMaterials).get();
      final canceled = usage.where((u) => u.isCanceled).toList();
      expect(canceled.length, 1);
      final estuches = c
          .read(productProvider)
          .products
          .firstWhere((x) => x.name == 'Estuches');
      final tela = c
          .read(materialProvider)
          .materials
          .firstWhere((x) => x.name == 'Tela para estuches');
      expect(canceled.single.productId, estuches.id);
      expect(canceled.single.materialId, tela.id);
      final bought = (await h.db.select(h.db.purchaseItems).get())
          .where((i) => i.materialId == tela.id)
          .fold(0.0, (t, i) => t + i.quantity);
      expect(tela.stock, closeTo(bought, 1e-9));
    },
  );

  test(
    'Tela negra has three purchases at different prices; the latest date sets the price',
    () async {
      await seed();
      final c = h.container;
      final tela = c
          .read(materialProvider)
          .materials
          .firstWhere((x) => x.name == 'Tela negra');
      final items = (await h.db.select(h.db.purchaseItems).get())
          .where((i) => i.materialId == tela.id)
          .toList();
      final purchases = {
        for (final p in c.read(purchaseProvider).purchases) p.id: p,
      };
      expect(items.length, 3);
      expect(items.map((i) => i.unitPrice).toSet().length, 3);
      final dated = [
        for (final i in items) (purchases[i.purchaseId]!.date, i.unitPrice),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      expect(dated.map((x) => x.$1).toSet().length, 3);
      expect(dated.every((x) => !x.$1.isAfter(h.now)), isTrue);
      expect(tela.pricePerUnit, dated.last.$2);
    },
  );

  test('does nothing when products already exist', () async {
    await seed();
    final counts = (
      h.container.read(productProvider).products.length,
      h.container.read(saleProvider).sales.length,
      h.container.read(purchaseProvider).purchases.length,
      h.container.read(clientProvider).clients.length,
    );
    expect(await seedSampleData(h.container, now: h.now), isFalse);
    await h.refresh();
    expect(h.container.read(productProvider).products.length, counts.$1);
    expect(h.container.read(saleProvider).sales.length, counts.$2);
    expect(h.container.read(purchaseProvider).purchases.length, counts.$3);
    expect(h.container.read(clientProvider).clients.length, counts.$4);
  });

  group('data for the six sales indicators', () {
    // Valid sales: not canceled and not future-dated, exactly what every
    // indicator counts. Everything below is computed straight from the tables,
    // independently of BiService.
    Future<
      ({
        List<SaleModel> sales,
        Map<int, List<SaleItem>> itemsBySale,
        List<PurchaseModel> purchases,
      })
    >
    load() async {
      final c = h.container;
      final sales = [
        for (final s in c.read(saleProvider).sales)
          if (!s.isCanceled && !s.date.isAfter(h.now)) s,
      ];
      final ids = {for (final s in sales) s.id};
      final itemsBySale = <int, List<SaleItem>>{};
      for (final i in await h.db.select(h.db.saleItems).get()) {
        if (ids.contains(i.saleId)) {
          itemsBySale.putIfAbsent(i.saleId, () => []).add(i);
        }
      }
      final purchases = [
        for (final p in c.read(purchaseProvider).purchases)
          if (!p.date.isAfter(h.now)) p,
      ];
      return (sales: sales, itemsBySale: itemsBySale, purchases: purchases);
    }

    test('several-product sales form pairs seen in 3+ sales, and some below the minimum', () async {
      await seed();
      final d = await load();
      final names = {
        for (final p in h.container.read(productProvider).products) p.id: p.name,
      };
      // Independent count of distinct product pairs per sale.
      final counts = <String, int>{};
      var multi = 0;
      d.itemsBySale.forEach((_, items) {
        final ids = {for (final i in items) i.productId}.toList()..sort();
        if (ids.length < 2) return;
        multi++;
        for (var a = 0; a < ids.length; a++) {
          for (var b = a + 1; b < ids.length; b++) {
            final key = ([names[ids[a]]!, names[ids[b]]!]..sort()).join(' + ');
            counts[key] = (counts[key] ?? 0) + 1;
          }
        }
      });
      expect(multi, greaterThanOrEqualTo(10));

      final r = h.report().coPurchases;
      expect(r.totalSales, d.sales.length);
      expect(r.multiProductSales, multi);
      final expected = {
        for (final e in counts.entries)
          if (e.value >= 3) e.key: e.value,
      };
      expect({for (final p in r.pairs) p.label: p.sales}, expected);
      for (final p in r.pairs) {
        expect(p.pct, closeTo(p.sales / d.sales.length * 100, 1e-9));
      }
      // Several pairs are shown, the top one is Tote bag negra + Pines
      // grandes, and at least one pair is left out for having only 1-2 sales.
      expect(r.pairs.length, greaterThanOrEqualTo(2));
      expect(r.pairs.first.label, 'Pines grandes + Tote bag negra');
      expect(counts.values.any((n) => n < 3), isTrue);
      expect(counts['Miniaturas + Tote bag beige'], 2);
      // Only approved product names appear.
      for (final p in r.pairs) {
        expect(products.contains(p.productA), isTrue);
        expect(products.contains(p.productB), isTrue);
      }
    });

    test('sales fall on all seven weekdays and match an independent count', () async {
      await seed();
      final d = await load();
      final w = h.report().weekdays;
      for (var i = 0; i < 7; i++) {
        final onDay = d.sales.where((s) => s.date.weekday == i + 1);
        expect(onDay, isNotEmpty, reason: 'weekday ${i + 1}');
        expect(w[i].ventas, onDay.length, reason: 'weekday ${i + 1}');
        expect(
          w[i].ingresos,
          closeTo(onDay.fold(0.0, (t, s) => t + s.finalAmount), 1e-6),
        );
      }
    });

    test('there are discounted sales, and the totals match', () async {
      await seed();
      final d = await load();
      final withDiscount = d.sales.where((s) => s.discount > 0).toList();
      expect(withDiscount.length, greaterThanOrEqualTo(5));
      final r = h.report().discounts;
      expect(r.discountedSales, withDiscount.length);
      expect(
        r.totalDiscount,
        closeTo(withDiscount.fold(0.0, (t, s) => t + s.discount), 1e-6),
      );
      expect(
        r.grossSales,
        closeTo(d.sales.fold(0.0, (t, s) => t + s.totalAmount), 1e-6),
      );
      expect(r.pct, greaterThan(0));
    });

    test('ticket average is the net income over the sales count', () async {
      await seed();
      final d = await load();
      final net = d.sales.fold(0.0, (t, s) => t + s.finalAmount);
      final t = h.report().ticket;
      expect(t.salesCount, d.sales.length);
      expect(t.average, closeTo(round2(net / d.sales.length), 1e-9));
    });

    test('events with linked sales and linked expenses: both a profit and a loss', () async {
      await seed();
      final d = await load();
      final events = {
        for (final e in h.container.read(eventProvider).events) e.id: e.name,
      };
      final income = <int, double>{};
      final spent = <int, double>{};
      for (final s in d.sales.where((s) => s.eventId != null)) {
        income[s.eventId!] = (income[s.eventId!] ?? 0) + s.finalAmount;
      }
      for (final p in d.purchases.where((p) => p.eventId != null)) {
        spent[p.eventId!] = (spent[p.eventId!] ?? 0) + p.totalAmount;
      }
      final r = h.report().eventProfit;
      expect(r.map((e) => e.name).toSet(), {
        for (final id in {...income.keys, ...spent.keys}) events[id]!,
      });
      for (final e in r) {
        final id = events.entries.firstWhere((x) => x.value == e.name).key;
        expect(e.income, closeTo(income[id] ?? 0, 1e-6), reason: e.name);
        expect(e.expenses, closeTo(spent[id] ?? 0, 1e-6), reason: e.name);
      }
      // Feria de Lima: flights and hotel far exceed its sales, a clear loss.
      final lima = r.firstWhere((e) => e.name == 'Feria de Lima');
      expect(lima.salesCount, greaterThanOrEqualTo(5));
      expect(lima.purchaseCount, greaterThanOrEqualTo(4));
      expect(lima.expenses, greaterThan(lima.income));
      expect(lima.profit, lessThan(0));
      // At least one event comes out ahead and several lose money.
      expect(r.any((e) => e.profit > 0), isTrue);
      expect(r.where((e) => e.profit < 0).length, greaterThanOrEqualTo(2));
      // Sorted from the best result to the worst.
      for (var i = 1; i < r.length; i++) {
        expect(r[i - 1].profit, greaterThanOrEqualTo(r[i].profit));
      }
    });

    test('return on production cost: every sold product, Libro never sold', () async {
      await seed();
      final d = await load();
      final byId = {
        for (final p in h.container.read(productProvider).products) p.id: p,
      };
      final units = <int, int>{};
      final revenue = <int, double>{};
      for (final s in d.sales) {
        // Each line carries a share of the sale's global discount, in
        // proportion to its subtotal.
        for (final i in d.itemsBySale[s.id] ?? const <SaleItem>[]) {
          final share = s.totalAmount > 0
              ? s.discount * i.subtotal / s.totalAmount
              : 0.0;
          units[i.productId] = (units[i.productId] ?? 0) + i.quantity;
          revenue[i.productId] =
              (revenue[i.productId] ?? 0) + i.subtotal - share;
        }
      }
      final r = h.report().costReturn;
      expect(r.withoutCost, 0);
      expect(r.entries.length, units.length);
      expect(r.entries.any((e) => e.name == 'Libro'), isFalse);
      for (final e in r.entries) {
        final id = byId.values.firstWhere((p) => p.name == e.name).id;
        final cost = byId[id]!.productionCost! * units[id]!;
        expect(e.units, units[id]);
        expect(e.cost, closeTo(round2(cost), 1e-9), reason: e.name);
        expect(e.ratio, closeTo((revenue[id]! - cost) / cost, 0.011), reason: e.name);
      }
      // Sorted from the best return to the worst.
      for (var i = 1; i < r.entries.length; i++) {
        expect(r.entries[i - 1].ratio, greaterThanOrEqualTo(r.entries[i].ratio));
      }
    });
  });
}
