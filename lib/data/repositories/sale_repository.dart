import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/sale_model.dart';
import '../../models/sale_item_model.dart';

class SaleRepository {
  final AppDatabase database;

  SaleRepository(this.database);

  // Convierte fila a modelo
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
    );
  }

  // Obtiene todas las ventas ordenadas por fecha descendente
  Future<List<SaleModel>> getAll() async {
    final rows = await (database.select(
      database.sales,
    )..orderBy([(s) => OrderingTerm.desc(s.date)])).get();
    return rows.map(_toModel).toList();
  }

  // Obtiene los ítems de una venta con nombre del producto
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
          subtotal: row.subtotal,
        ),
      );
    }
    return result;
  }

  // Registra una nueva venta y descuenta stock
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
    await database.transaction(() async {
      // Inserta la venta
      final saleId = await database
          .into(database.sales)
          .insert(
            SalesCompanion.insert(
              clientId: Value(clientId),
              locationId: Value(locationId),
              eventId: Value(eventId),
              totalAmount: totalAmount,
              discount: Value(discount),
              finalAmount: finalAmount,
              date: date,
              notes: Value(notes),
            ),
          );

      // Inserta los ítems y descuenta stock
      for (final item in items) {
        final productId = item['productId'] as int;
        final quantity = item['quantity'] as int;
        final unitPrice = item['unitPrice'] as double;

        await database
            .into(database.saleItems)
            .insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
                subtotal: quantity * unitPrice,
              ),
            );

        // Descuenta stock del producto
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
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
    });
  }

  // Edita una venta existente y ajusta stock
  Future<void> editSale({
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
    await database.transaction(() async {
      // Obtiene los ítems anteriores para ajustar stock
      final oldItems = await (database.select(
        database.saleItems,
      )..where((si) => si.saleId.equals(saleId))).get();

      // Devuelve el stock de los ítems anteriores
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
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }

      // Elimina los ítems anteriores
      await (database.delete(
        database.saleItems,
      )..where((si) => si.saleId.equals(saleId))).go();

      // Actualiza la venta
      await (database.update(
        database.sales,
      )..where((s) => s.id.equals(saleId))).write(
        SalesCompanion(
          clientId: Value(clientId),
          locationId: Value(locationId),
          eventId: Value(eventId),
          totalAmount: Value(totalAmount),
          discount: Value(discount),
          finalAmount: Value(finalAmount),
          date: Value(date),
          notes: Value(notes),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Inserta los nuevos ítems y descuenta stock
      for (final item in newItems) {
        final productId = item['productId'] as int;
        final quantity = item['quantity'] as int;
        final unitPrice = item['unitPrice'] as double;

        await database
            .into(database.saleItems)
            .insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
                subtotal: quantity * unitPrice,
              ),
            );

        final product = await (database.select(
          database.products,
        )..where((p) => p.id.equals(productId))).getSingleOrNull();

        if (product != null) {
          await (database.update(
            database.products,
          )..where((p) => p.id.equals(productId))).write(
            ProductsCompanion(
              stock: Value(product.stock - quantity),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
    });
  }
}
