import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/bi_provider.dart';
import 'package:offline_first_bi/application/category_provider.dart';
import 'package:offline_first_bi/application/client_provider.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/application/event_provider.dart';
import 'package:offline_first_bi/application/location_provider.dart';
import 'package:offline_first_bi/application/material_provider.dart';
import 'package:offline_first_bi/application/product_provider.dart';
import 'package:offline_first_bi/application/purchase_provider.dart';
import 'package:offline_first_bi/application/report_provider.dart';
import 'package:offline_first_bi/application/sale_provider.dart';
import 'package:offline_first_bi/application/supplier_provider.dart';
import 'package:offline_first_bi/application/unit_provider.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/models/bi_config.dart';
import 'package:offline_first_bi/models/bi_models.dart';
import 'package:offline_first_bi/models/report_filters.dart';
import 'package:offline_first_bi/config/app_clock.dart';

// Base Drift real en memoria + providers reales de Riverpod, con ayudantes para
// sembrar ventas, compras, eventos y usos de material por la capa de
// repositorios (los notifiers), igual que lo hace la app.
class BiHarness {
  late AppDatabase db;
  late ProviderContainer container;
  final DateTime now = appNow();

  // Un día relativo a hoy (0 = hoy, -3 = hace 3 días, 5 = dentro de 5 días).
  DateTime day(int offset, [int hour = 12]) =>
      DateTime(now.year, now.month, now.day + offset, hour);

  void setUp() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  }

  Future<void> tearDown() async {
    container.dispose();
    await db.close();
  }

  // Recarga todo el estado y mantiene vivos los providers autoDispose.
  Future<void> refresh() async {
    await container.read(saleProvider.notifier).load();
    await container.read(purchaseProvider.notifier).load();
    await container.read(eventProvider.notifier).load();
    await container.read(productProvider.notifier).load();
    await container.read(categoryProvider.notifier).load();
    await container.read(clientProvider.notifier).load();
    await container.read(locationProvider.notifier).load();
    await container.read(supplierProvider.notifier).load();
    await container.read(materialProvider.notifier).load();
    await container.read(unitProvider.notifier).load();
    container.listen(saleItemsMapProvider, (_, _) {});
    container.invalidate(saleItemsMapProvider);
    await container.read(saleItemsMapProvider.future);
    container.listen(purchaseItemsMapProvider, (_, _) {});
    container.invalidate(purchaseItemsMapProvider);
    await container.read(purchaseItemsMapProvider.future);
  }

  Future<int> newCategory(String name) async {
    await container.read(categoryProvider.notifier).save(name: name);
    return container
        .read(categoryProvider)
        .categories
        .firstWhere((c) => c.name == name)
        .id;
  }

  Future<int> newProduct(
    String name, {
    int? categoryId,
    int stock = 100,
    bool isActive = true,
    double priceA = 10,
    double priceB = 8,
    double? productionCost,
  }) async {
    await container
        .read(productProvider.notifier)
        .save(
          categoryId: categoryId,
          name: name,
          priceA: priceA,
          priceB: priceB,
          productionCost: productionCost,
          stock: stock,
          isActive: isActive,
        );
    return container
        .read(productProvider)
        .products
        .firstWhere((p) => p.name == name)
        .id;
  }

  Future<int> newEvent(String name, DateTime start, DateTime? end) async {
    await container
        .read(eventProvider.notifier)
        .save(name: name, startDate: start, endDate: end);
    return container
        .read(eventProvider)
        .events
        .firstWhere((e) => e.name == name)
        .id;
  }

  // Un material con stock 0 (así no se crea la compra automática del stock
  // inicial); el stock se agrega con [buyMaterial].
  Future<int> newMaterial(String name) async {
    await container.read(unitProvider.notifier).load();
    final unit = container.read(unitProvider).units.first;
    await container
        .read(materialProvider.notifier)
        .save(name: name, unitId: unit.id, stock: 0, pricePerUnit: 1);
    return container
        .read(materialProvider)
        .materials
        .firstWhere((m) => m.name == name)
        .id;
  }

  // Una venta de una sola línea: [qty] unidades de [productId] a [price].
  Future<void> sell(
    DateTime date,
    int productId,
    int qty,
    double price, {
    String priceType = 'A',
    int? eventId,
    double discount = 0,
  }) async {
    final subtotal = qty * price;
    final error = await container
        .read(saleProvider.notifier)
        .createSale(
          clientId: null,
          locationId: null,
          eventId: eventId,
          totalAmount: subtotal,
          discount: discount,
          finalAmount: subtotal - discount,
          date: date,
          items: [
            {
              'productId': productId,
              'quantity': qty,
              'unitPrice': price,
              'priceType': priceType,
            },
          ],
        );
    expect(error, isNull);
  }

  // Una venta de varias líneas: cada una es (productId, cantidad, precio).
  // [discount] es el descuento global de la venta.
  Future<void> sellMany(
    DateTime date,
    List<(int, int, double)> lines, {
    String priceType = 'A',
    int? eventId,
    int? locationId,
    double discount = 0,
  }) async {
    final gross = lines.fold(0.0, (t, l) => t + l.$2 * l.$3);
    final error = await container
        .read(saleProvider.notifier)
        .createSale(
          clientId: null,
          locationId: locationId,
          eventId: eventId,
          totalAmount: gross,
          discount: discount,
          finalAmount: gross - discount,
          date: date,
          items: [
            for (final l in lines)
              {
                'productId': l.$1,
                'quantity': l.$2,
                'unitPrice': l.$3,
                'priceType': priceType,
              },
          ],
        );
    expect(error, isNull);
  }

  Future<int> newLocation(String city, {String country = 'Bolivia'}) async {
    await container
        .read(locationProvider.notifier)
        .save(city: city, country: country);
    return container
        .read(locationProvider)
        .locations
        .firstWhere((l) => l.city == city)
        .id;
  }

  Future<int> newSupplier(String name) async {
    final error = await container
        .read(supplierProvider.notifier)
        .save(name: name, contactInfo: '@${name.replaceAll(' ', '').toLowerCase()}');
    expect(error, isNull);
    return container
        .read(supplierProvider)
        .suppliers
        .firstWhere((s) => s.name == name)
        .id;
  }

  // Cancela la venta cuyo total bruto es [totalAmount].
  Future<void> cancelSaleOf(double totalAmount) async {
    await container.read(saleProvider.notifier).load();
    final sale = container
        .read(saleProvider)
        .sales
        .firstWhere((s) => s.totalAmount == totalAmount && !s.isCanceled);
    expect(await container.read(saleProvider.notifier).cancelSale(sale.id), isNull);
  }

  Future<void> buyMaterial(
    DateTime date,
    int materialId,
    double qty,
    double price, {
    int? eventId,
  }) async {
    final error = await container
        .read(purchaseProvider.notifier)
        .createPurchase(
          supplierId: null,
          locationId: null,
          eventId: eventId,
          isMaterial: true,
          description: null,
          totalAmount: qty * price,
          date: date,
          items: [
            {'materialId': materialId, 'quantity': qty, 'unitPrice': price},
          ],
        );
    expect(error, isNull);
  }

  Future<void> spend(
    DateTime date,
    double amount, {
    int? eventId,
    int? supplierId,
    int? locationId,
  }) async {
    final error = await container
        .read(purchaseProvider.notifier)
        .createPurchase(
          supplierId: supplierId,
          locationId: locationId,
          eventId: eventId,
          isMaterial: false,
          description: 'Participación en feria',
          totalAmount: amount,
          date: date,
          items: const [],
        );
    expect(error, isNull);
  }

  BiReport report([
    ReportFilters filters = const ReportFilters(),
    int noMovementDays = defaultNoMovementDays,
    List<int> radarProductIds = const [],
  ]) => container.read(
    biReportProvider(
      BiQuery(
        filters: filters,
        noMovementDays: noMovementDays,
        radarProductIds: radarProductIds,
      ),
    ),
  );
}
