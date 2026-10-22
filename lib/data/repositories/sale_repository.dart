import 'package:drift/drift.dart';
import '../../config/rounding.dart';
import '../../data/db/app_database.dart';
import '../../models/default_records.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../models/sale_item_model.dart';
import '../../config/app_clock.dart';

class SaleRepository {
  final AppDatabase database;

  SaleRepository(this.database);

  double calculateSubtotal(
    List<ProductModel> products,
    Map<int, int> cartItems, {
    Map<int, String> priceTypes = const {},
    Map<int, double> savedUnitPrices = const {},
  }) {
    double total = 0;
    for (final entry in cartItems.entries) {
      final product = products.where((p) => p.id == entry.key).firstOrNull;
      if (product != null) {
        final priceType = priceTypes[entry.key] ?? 'A';
        final unitPrice =
            savedUnitPrices[entry.key] ??
            (priceType == 'B' ? product.priceB : product.priceA);
        total += round2(unitPrice * entry.value);
      }
    }
    return round2(total);
  }

  double calculateTotal(double subtotal, double discount) {
    return round2((subtotal - discount).clamp(0, double.infinity).toDouble());
  }

  static const String negativeDiscountMessage =
      'El descuento no puede ser negativo';

  String? validateDiscount(double discount, double subtotal) {
    if (discount < 0 || discount.isNaN) {
      return negativeDiscountMessage;
    }
    if (discount > subtotal) {
      return 'El descuento no puede ser mayor al subtotal';
    }
    return null;
  }

  int availableStock({required int currentStock, int reservedByThisSale = 0}) {
    return currentStock + reservedByThisSale;
  }

  Future<Map<int, int>> getReservedQuantities(int saleId) async {
    final rows = await (database.select(
      database.saleItems,
    )..where((si) => si.saleId.equals(saleId))).get();
    final reserved = <int, int>{};
    for (final row in rows) {
      reserved[row.productId] = (reserved[row.productId] ?? 0) + row.quantity;
    }
    return reserved;
  }

  Future<int> _defaultClientId() async {
    final existing = await (database.select(
      database.clients,
    )..where((c) => c.name.equals(DefaultRecords.client))).getSingleOrNull();
    if (existing != null) return existing.id;
    final now = appNow();
    return database.into(database.clients).insert(
      ClientsCompanion.insert(
        name: DefaultRecords.client,
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  SaleModel _toModel(Sale row) {
    return SaleModel(
      id: row.id,
      clientId: row.clientId,
      locationId: row.locationId,
      eventId: row.eventId,
      totalAmount: row.totalAmount,
      discount: row.discount,
      finalAmount: row.finalAmount,
      date: row.date,
      notes: row.notes,
      createdAt: row.createdAt,
      isCanceled: row.isCanceled,
      canceledAt: row.canceledAt,
    );
  }

  Future<List<SaleModel>> getAll() async {
    final rows = await (database.select(
      database.sales,
    )..orderBy([(s) => OrderingTerm.desc(s.date)])).get();
    return rows.map(_toModel).toList();
  }

  Future<List<SaleItemModel>> getItemsForSale(int saleId) async {
    final rows = await (database.select(
      database.saleItems,
    )..where((si) => si.saleId.equals(saleId))).get();

    final result = <SaleItemModel>[];
    for (final row in rows) {
      final product = await (database.select(
        database.products,
      )..where((p) => p.id.equals(row.productId))).getSingleOrNull();
      result.add(
        SaleItemModel(
          id: row.id,
          saleId: row.saleId,
          productId: row.productId,
          productName: product?.name ?? 'Producto eliminado',
          quantity: row.quantity,
          unitPrice: row.unitPrice,
          priceType: row.priceType,
          subtotal: row.subtotal,
        ),
      );
    }
    return result;
  }

  Future<void> createSale({
    required int? clientId,
    required int? locationId,
    required int? eventId,
    required double totalAmount,
    required double discount,
    required double finalAmount,
    required DateTime date,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    if (discount < 0 || discount.isNaN) {
      throw ArgumentError(negativeDiscountMessage);
    }
    totalAmount = round2(totalAmount);
    discount = round2(discount);
    finalAmount = round2(finalAmount);
    await database.transaction(() async {
      final resolvedClientId = clientId ?? await _defaultClientId();
      final saleId = await database
          .into(database.sales)
          .insert(
            SalesCompanion.insert(
              clientId: Value(resolvedClientId),
              locationId: Value(locationId),
              eventId: Value(eventId),
              totalAmount: totalAmount,
              discount: Value(discount),
              finalAmount: finalAmount,
              date: date,
              notes: Value(notes),
            ),
          );

      for (final item in items) {
        final productId = item['productId'] as int;
        final quantity = item['quantity'] as int;
        final unitPrice = round2(item['unitPrice'] as double);
        final priceType = item['priceType'] as String? ?? 'A';

        await database
            .into(database.saleItems)
            .insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
                priceType: Value(priceType),
                subtotal: round2(quantity * unitPrice),
              ),
            );

        final product = await (database.select(
          database.products,
        )..where((p) => p.id.equals(productId))).getSingleOrNull();

        if (product != null) {
          final newStock = product.stock - quantity;
          await (database.update(
            database.products,
          )..where((p) => p.id.equals(productId))).write(
            ProductsCompanion(
              stock: Value(newStock < 0 ? 0 : newStock),
              updatedAt: Value(appNow()),
            ),
          );
        }
      }
    });
  }

  Future<String?> cancelSale(int saleId) async {
    return database.transaction(() async {
      final sale = await (database.select(
        database.sales,
      )..where((s) => s.id.equals(saleId))).getSingleOrNull();
      if (sale == null) return 'Venta no encontrada';
      if (sale.isCanceled) return 'La venta ya está cancelada';

      final items = await (database.select(
        database.saleItems,
      )..where((si) => si.saleId.equals(saleId))).get();

      for (final item in items) {
        final product = await (database.select(
          database.products,
        )..where((p) => p.id.equals(item.productId))).getSingleOrNull();
        if (product == null) continue;
        await (database.update(
          database.products,
        )..where((p) => p.id.equals(item.productId))).write(
          ProductsCompanion(
            stock: Value(product.stock + item.quantity),
            updatedAt: Value(appNow()),
          ),
        );
      }

      final now = appNow();
      await (database.update(
        database.sales,
      )..where((s) => s.id.equals(saleId))).write(
        SalesCompanion(
          isCanceled: const Value(true),
          canceledAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return null;
    });
  }

  Future<String?> editSale({
    required int saleId,
    required int? clientId,
    required int? locationId,
    required int? eventId,
    required double totalAmount,
    required double discount,
    required double finalAmount,
    required DateTime date,
    String? notes,
    required List<Map<String, dynamic>> newItems,
  }) async {
    if (discount < 0 || discount.isNaN) return negativeDiscountMessage;
    totalAmount = round2(totalAmount);
    discount = round2(discount);
    finalAmount = round2(finalAmount);
    return database.transaction(() async {
      final current = await (database.select(
        database.sales,
      )..where((s) => s.id.equals(saleId))).getSingleOrNull();
      if (current == null) return 'Venta no encontrada';
      if (current.isCanceled) {
        return 'La venta está cancelada y no se puede editar';
      }

      final oldItems = await (database.select(
        database.saleItems,
      )..where((si) => si.saleId.equals(saleId))).get();

      for (final oldItem in oldItems) {
        final product = await (database.select(
          database.products,
        )..where((p) => p.id.equals(oldItem.productId))).getSingleOrNull();
        if (product != null) {
          await (database.update(
            database.products,
          )..where((p) => p.id.equals(oldItem.productId))).write(
            ProductsCompanion(
              stock: Value(product.stock + oldItem.quantity),
              updatedAt: Value(appNow()),
            ),
          );
        }
      }

      await (database.delete(
        database.saleItems,
      )..where((si) => si.saleId.equals(saleId))).go();

      final resolvedClientId = clientId ?? await _defaultClientId();
      await (database.update(
        database.sales,
      )..where((s) => s.id.equals(saleId))).write(
        SalesCompanion(
          clientId: Value(resolvedClientId),
          locationId: Value(locationId),
          eventId: Value(eventId),
          totalAmount: Value(totalAmount),
          discount: Value(discount),
          finalAmount: Value(finalAmount),
          date: Value(date),
          notes: Value(notes),
          updatedAt: Value(appNow()),
        ),
      );

      for (final item in newItems) {
        final productId = item['productId'] as int;
        final quantity = item['quantity'] as int;
        final unitPrice = round2(item['unitPrice'] as double);
        final priceType = item['priceType'] as String? ?? 'A';

        await database
            .into(database.saleItems)
            .insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
                priceType: Value(priceType),
                subtotal: round2(quantity * unitPrice),
              ),
            );

        final product = await (database.select(
          database.products,
        )..where((p) => p.id.equals(productId))).getSingleOrNull();

        if (product != null) {
          final newStock = product.stock - quantity;
          await (database.update(
            database.products,
          )..where((p) => p.id.equals(productId))).write(
            ProductsCompanion(
              stock: Value(newStock < 0 ? 0 : newStock),
              updatedAt: Value(appNow()),
            ),
          );
        }
      }
      return null;
    });
  }
}
