import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/category_catalog_filter.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/material_provider.dart';
import 'package:offline_first_bi/application/product_catalog_filter.dart';
import 'package:offline_first_bi/application/purchase_provider.dart';
import 'package:offline_first_bi/application/report_service.dart';
import 'package:offline_first_bi/application/sale_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/material_repository.dart';
import 'package:offline_first_bi/data/repositories/product_repository.dart';
import 'package:offline_first_bi/data/repositories/purchase_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/models/category_model.dart';
import 'package:offline_first_bi/models/product_model.dart';
import 'package:offline_first_bi/models/purchase_kind.dart';
import 'package:offline_first_bi/models/purchase_model.dart';
import 'package:offline_first_bi/models/report_filters.dart';

ProductModel _product(
  int id,
  String name, {
  double a = 10,
  double b = 10,
  int category = 1,
  String? description,
}) => ProductModel(
  id: id,
  categoryId: category,
  name: name,
  description: description,
  priceA: a,
  priceB: b,
  stock: 1,
  isActive: true,
  createdAt: DateTime(2026),
);

PurchaseModel _purchase(int id, {required bool material}) => PurchaseModel(
  id: id,
  isMaterial: material,
  totalAmount: 10,
  date: DateTime(2026, 1, id),
  createdAt: DateTime(2026),
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> unitId(String name) async => (await (db.select(
    db.units,
  )..where((u) => u.name.equals(name))).getSingle()).id;

  group('product prices: only one is required', () {
    test('saving with only Precio A copies it to Precio B', () async {
      final repo = ProductRepository(db);
      await repo.save(name: 'Estuches', priceA: 55, stock: 1);
      final p = (await repo.getAllIncludingInactive()).single;
      expect(p.priceA, 55.0);
      expect(p.priceB, 55.0);
    });

    test('saving with only Precio B copies it to Precio A', () async {
      final repo = ProductRepository(db);
      await repo.save(name: 'Estuches', priceB: 40, stock: 1);
      final p = (await repo.getAllIncludingInactive()).single;
      expect(p.priceA, 40.0);
      expect(p.priceB, 40.0);
    });

    test('two different prices are kept as they are', () async {
      final repo = ProductRepository(db);
      await repo.save(name: 'Estuches', priceA: 55, priceB: 40, stock: 1);
      final p = (await repo.getAllIncludingInactive()).single;
      expect(p.priceA, 55.0);
      expect(p.priceB, 40.0);
    });

    test('editing to a single price also equalizes the other one', () async {
      final repo = ProductRepository(db);
      await repo.save(name: 'Estuches', priceA: 55, priceB: 40, stock: 1);
      final id = (await repo.getAllIncludingInactive()).single.id;
      await repo.save(id: id, name: 'Estuches', priceA: 70, stock: 1);
      final p = (await repo.getAllIncludingInactive()).single;
      expect([p.priceA, p.priceB], [70.0, 70.0]);
    });

    test('with no price at all it refuses to save', () async {
      final repo = ProductRepository(db);
      await expectLater(
        repo.save(name: 'Estuches', stock: 1),
        throwsArgumentError,
      );
      expect(await repo.getAllIncludingInactive(), isEmpty);
    });
  });

  group('sales: a discount is zero or positive', () {
    Future<void> seedProduct() async {
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Producto',
          priceA: 20,
          priceB: 20,
          stock: const Value(10),
        ),
      );
    }

    List<Map<String, dynamic>> items() => [
      {'productId': 1, 'quantity': 1, 'unitPrice': 20.0, 'priceType': 'A'},
    ];

    test('validateDiscount rejects negatives and accepts zero and positives', () {
      final repo = SaleRepository(db);
      expect(
        repo.validateDiscount(-1, 100),
        SaleRepository.negativeDiscountMessage,
      );
      expect(repo.validateDiscount(0, 100), isNull);
      expect(repo.validateDiscount(5, 100), isNull);
    });

    test('createSale refuses a negative discount and stores nothing', () async {
      await seedProduct();
      await expectLater(
        SaleRepository(db).createSale(
          clientId: null,
          locationId: null,
          eventId: null,
          totalAmount: 20,
          discount: -5,
          finalAmount: 25,
          date: DateTime.now(),
          items: items(),
        ),
        throwsArgumentError,
      );
      expect(await db.select(db.sales).get(), isEmpty);
      final product = await (db.select(db.products)).getSingle();
      expect(product.stock, 10, reason: 'el stock no se toca');
    });

    test('the provider returns the clear message for a negative discount', () async {
      await seedProduct();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final error = await container.read(saleProvider.notifier).createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 20,
        discount: -5,
        finalAmount: 25,
        date: DateTime.now(),
        items: items(),
      );
      expect(error, SaleRepository.negativeDiscountMessage);
      expect(await db.select(db.sales).get(), isEmpty);
    });

    test('editSale refuses a negative discount and keeps the sale intact', () async {
      await seedProduct();
      final repo = SaleRepository(db);
      await repo.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 20,
        discount: 3,
        finalAmount: 17,
        date: DateTime(2026, 1, 1),
        items: items(),
      );
      final sale = await db.select(db.sales).getSingle();

      final error = await repo.editSale(
        saleId: sale.id,
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 20,
        discount: -4,
        finalAmount: 24,
        date: DateTime(2026, 1, 1),
        newItems: items(),
      );

      expect(error, SaleRepository.negativeDiscountMessage);
      final after = await db.select(db.sales).getSingle();
      expect(after.discount, 3.0);
      expect(after.finalAmount, 17.0);
    });

    test('so no stored sale (and no report row) can carry a negative discount', () async {
      await seedProduct();
      final repo = SaleRepository(db);
      for (final discount in [-1.0, -0.01, double.nan]) {
        await expectLater(
          repo.createSale(
            clientId: null,
            locationId: null,
            eventId: null,
            totalAmount: 20,
            discount: discount,
            finalAmount: 20,
            date: DateTime.now(),
            items: items(),
          ),
          throwsArgumentError,
        );
      }
      await repo.createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 20,
        discount: 0,
        finalAmount: 20,
        date: DateTime.now(),
        items: items(),
      );
      final sales = await repo.getAll();
      expect(sales.every((s) => s.discount >= 0), isTrue);
    });
  });

  group('purchases: Material / Gasto filter', () {
    final purchases = [
      _purchase(1, material: true),
      _purchase(2, material: false),
      _purchase(3, material: true),
      _purchase(4, material: false),
    ];
    final service = ReportService();

    List<int> ids(PurchaseKind kind) => service
        .filterPurchases(
          purchases: purchases,
          filters: ReportFilters(purchaseKind: kind),
        )
        .map((p) => p.id)
        .toList();

    test('only Material', () => expect(ids(PurchaseKind.material), [1, 3]));
    test('only Gasto', () => expect(ids(PurchaseKind.expense), [2, 4]));
    test('both', () => expect(ids(PurchaseKind.all), [1, 2, 3, 4]));

    test('the filter counts as an active report filter and clears with the others', () {
      expect(const ReportFilters().hasActive, isFalse);
      expect(
        const ReportFilters(purchaseKind: PurchaseKind.expense).hasActive,
        isTrue,
      );
      expect(
        const ReportFilters(purchaseKind: PurchaseKind.expense),
        isNot(const ReportFilters()),
      );
      expect(
        const ReportFilters(purchaseKind: PurchaseKind.expense)
            .copyWith(purchaseKind: PurchaseKind.all),
        const ReportFilters(),
      );
    });

    test('it combines with the other purchase filters', () {
      final withEvent = [
        PurchaseModel(
          id: 10,
          isMaterial: false,
          totalAmount: 5,
          date: DateTime(2026, 2, 1),
          eventId: 7,
          createdAt: DateTime(2026),
        ),
        PurchaseModel(
          id: 11,
          isMaterial: true,
          totalAmount: 5,
          date: DateTime(2026, 2, 2),
          eventId: 7,
          createdAt: DateTime(2026),
        ),
      ];
      final result = service.filterPurchases(
        purchases: withEvent,
        filters: const ReportFilters(
          eventId: 7,
          purchaseKind: PurchaseKind.expense,
        ),
      );
      expect(result.map((p) => p.id), [10]);
    });
  });

  group('creating a material with initial stock creates its Compra', () {
    test('stock > 0 registers a Material purchase and does not double the stock', () async {
      final repo = MaterialRepository(db);
      await repo.save(
        name: 'Tela negra',
        unitId: await unitId('metro'),
        stock: 5,
        pricePerUnit: 3,
      );

      final material = await db.select(db.materials).getSingle();
      expect(material.stock, 5.0, reason: 'el stock inicial no se suma otra vez');

      final purchases = await PurchaseRepository(db).getAll();
      expect(purchases, hasLength(1));
      final purchase = purchases.single;
      expect(purchase.isMaterial, isTrue);
      expect(purchase.totalAmount, 15.0); // 5 x 3
      expect(purchase.notes, MaterialRepository.initialStockPurchaseNote);

      final items = await PurchaseRepository(db).getItemsForPurchase(purchase.id);
      expect(items, hasLength(1));
      expect(items.single.materialId, material.id);
      expect(items.single.quantity, 5.0);
      expect(items.single.unitPrice, 3.0);
      expect(items.single.subtotal, 15.0);
    });

    test('the purchase goes to the default supplier "Sin proveedor"', () async {
      await MaterialRepository(db).save(
        name: 'Tela negra',
        unitId: await unitId('metro'),
        stock: 2,
        pricePerUnit: 1,
      );
      final purchase = (await PurchaseRepository(db).getAll()).single;
      final supplier = await (db.select(
        db.suppliers,
      )..where((s) => s.id.equals(purchase.supplierId!))).getSingle();
      expect(supplier.name, AppDatabase.defaultSupplierName);
    });

    test('stock 0 creates the material without any purchase', () async {
      await MaterialRepository(db).save(
        name: 'Resina parte A',
        unitId: await unitId('metro'),
        stock: 0,
        pricePerUnit: 2,
      );
      expect(await db.select(db.materials).get(), hasLength(1));
      expect(await PurchaseRepository(db).getAll(), isEmpty);
    });

    test('editing an existing material never creates another purchase', () async {
      final repo = MaterialRepository(db);
      final unit = await unitId('metro');
      await repo.save(name: 'Tela negra', unitId: unit, stock: 5, pricePerUnit: 3);
      final id = (await db.select(db.materials).getSingle()).id;

      await repo.save(
        id: id,
        name: 'Tela beige',
        unitId: unit,
        stock: 9,
        pricePerUnit: 4,
      );

      expect(await PurchaseRepository(db).getAll(), hasLength(1));
      final material = await db.select(db.materials).getSingle();
      expect(material.stock, 9.0);
    });

    test('the provider refreshes the Compras list with the new purchase', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.read(purchaseProvider); // la lista de Compras ya está abierta

      await container.read(materialProvider.notifier).save(
        name: 'Tela negra',
        unitId: await unitId('metro'),
        stock: 4,
        pricePerUnit: 2,
      );

      final listed = container.read(purchaseProvider).purchases;
      expect(listed, hasLength(1));
      expect(listed.single.isMaterial, isTrue);
      expect(listed.single.totalAmount, 8.0);
    });
  });

  group('a manually edited purchase total', () {
    test('is stored as given and never touches the materials stock or price', () async {
      final unit = await unitId('metro');
      final materialId = await db.into(db.materials).insert(
        MaterialsCompanion.insert(
          name: 'Tela negra',
          unitId: unit,
          pricePerUnit: 4,
          stock: const Value(10),
        ),
      );
      final repo = PurchaseRepository(db);
      // Los ítems suman 3 x 6 = 18, pero el total se escribió a mano: 50.
      await repo.createPurchase(
        supplierId: null,
        isMaterial: true,
        description: null,
        totalAmount: 50,
        date: DateTime(2026, 1, 1),
        locationId: null,
        eventId: null,
        items: [
          {'materialId': materialId, 'quantity': 3.0, 'unitPrice': 6.0},
        ],
      );

      final purchase = (await repo.getAll()).single;
      expect(purchase.totalAmount, 50.0);
      final material = await db.select(db.materials).getSingle();
      expect(material.stock, 13.0, reason: 'el stock sale de los ítems (10 + 3)');
      expect(material.pricePerUnit, 6.0, reason: 'el precio sale de los ítems');
      final items = await repo.getItemsForPurchase(purchase.id);
      expect(items.single.subtotal, 18.0);
    });
  });

  group('Productos: búsqueda, categoría y orden por precio', () {
    final products = [
      _product(1, 'Estuches', a: 30, b: 10, category: 1, description: 'Pintura'),
      _product(2, 'Libro', a: 10, b: 50, category: 2),
      _product(3, 'Miniaturas', a: 20, b: 30, category: 2, description: 'Con pintura'),
    ];

    List<String> names(ProductCatalogFilter f) =>
        f.apply(products).map((p) => p.name).toList();

    test('the result keeps the incoming (alphabetical) order: there is no sorter', () {
      expect(names(const ProductCatalogFilter()), ['Estuches', 'Libro', 'Miniaturas']);
    });

    test('search matches name or description, ignoring case', () {
      expect(names(const ProductCatalogFilter(query: 'LIB')), ['Libro']);
      expect(names(const ProductCatalogFilter(query: 'pintura')), [
        'Estuches',
        'Miniaturas',
      ]);
      expect(names(const ProductCatalogFilter(query: 'zzz')), isEmpty);
    });

    test('filters by category', () {
      expect(names(const ProductCatalogFilter(categoryId: 2)), [
        'Libro',
        'Miniaturas',
      ]);
    });

    test('category and search combine', () {
      expect(
        names(const ProductCatalogFilter(categoryId: 2, query: 'pintura')),
        ['Miniaturas'],
      );
    });

    test('price display defaults to "Ambos" and the menu order is Ambos, A, B, none', () {
      expect(const ProductCatalogFilter().priceDisplay, PriceDisplay.both);
      expect(PriceDisplay.values, [
        PriceDisplay.both,
        PriceDisplay.a,
        PriceDisplay.b,
        PriceDisplay.none,
      ]);
      // Elegir otra opción la conserva al seguir filtrando.
      final chosen = const ProductCatalogFilter().copyWith(
        priceDisplay: PriceDisplay.b,
      );
      expect(chosen.copyWith(query: 'x').priceDisplay, PriceDisplay.b);
    });
  });

  group('Categorías: búsqueda por nombre y estado', () {
    CategoryModel cat(int id, String name, {bool active = true, String? d}) =>
        CategoryModel(
          id: id,
          name: name,
          description: d,
          isActive: active,
          createdAt: DateTime(2026),
        );
    final categories = [
      cat(1, 'Pines', d: 'Collares'),
      cat(2, 'Libros', active: false),
      cat(3, 'Papelería'),
    ];
    List<String> names(CategoryCatalogFilter f) =>
        f.apply(categories).map((c) => c.name).toList();

    test('keeps the incoming order (no sorter)', () {
      expect(names(const CategoryCatalogFilter()), [
        'Pines',
        'Libros',
        'Papelería',
      ]);
    });

    test('searches by name only, ignoring case', () {
      expect(names(const CategoryCatalogFilter(query: 'LIB')), ['Libros']);
      expect(names(const CategoryCatalogFilter(query: 'PAPE')), ['Papelería']);
      // La descripción ya no cuenta: "collar" está en la descripción de Pines.
      expect(names(const CategoryCatalogFilter(query: 'collar')), isEmpty);
    });

    test('filters by status', () {
      expect(
        names(const CategoryCatalogFilter(status: CategoryStatusFilter.active)),
        ['Pines', 'Papelería'],
      );
      expect(
        names(const CategoryCatalogFilter(status: CategoryStatusFilter.inactive)),
        ['Libros'],
      );
    });
  });
}
