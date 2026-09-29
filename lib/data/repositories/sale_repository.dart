import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../models/sale_item_model.dart';

class SaleRepository {
  final AppDatabase database;

  SaleRepository(this.database);

  // Calcula el subtotal de un carrito según el precio de cada producto y la
  // banda de precio (A o B) elegida para cada ítem (por defecto A, si no se
  // especifica para ese producto).
  double calculateSubtotal(
    List<ProductModel> products,
    Map<int, int> cartItems, {
    Map<int, String> priceTypes = const {},
  }) {
    double total = 0;
    for (final entry in cartItems.entries) {
      final product = products.where((p) => p.id == entry.key).firstOrNull;
      if (product != null) {
        final priceType = priceTypes[entry.key] ?? 'A';
        final unitPrice = priceType == 'B' ? product.priceB : product.priceA;
        total += unitPrice * entry.value;
      }
    }
    return total;
  }

  // Calcula el total final aplicando el descuento
  double calculateTotal(double subtotal, double discount) {
    return (subtotal - discount).clamp(0, double.infinity);
  }

  // Valida que el descuento no exceda el subtotal
  String? validateDiscount(double discount, double subtotal) {
    if (discount > subtotal) {
      return 'El descuento no puede ser mayor al subtotal';
    }
    return null;
  }

  // Stock que se puede ofrecer de un producto al armar una venta. Al editar
  // una venta existente, las unidades que ESA venta ya tiene apartadas
  // ([reservedByThisSale]) vuelven al inventario antes de aplicar la nueva
  // cantidad (ver editSale), así que también están disponibles: con 3 en
  // stock y 2 en la venta editada se pueden ofrecer 5, no 3. Para una venta
  // nueva no hay nada apartado.
  int availableStock({required int currentStock, int reservedByThisSale = 0}) {
    return currentStock + reservedByThisSale;
  }

  // Cantidad de cada producto (productId -> unidades) que una venta ya tiene
  // apartada del inventario.
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
      isCanceled: row.isCanceled,
      canceledAt: row.canceledAt,
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
          priceType: row.priceType,
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

  // Cancela una venta en vez de borrarla: devuelve al inventario lo vendido y
  // la marca como cancelada, conservándola como historial. Devuelve un
  // mensaje de error, o null si salió bien.
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
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      final now = DateTime.now();
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

  // Edita una venta existente y ajusta stock. Devuelve un mensaje de error
  // (p. ej. si la venta está cancelada), o null si salió bien.
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
    return database.transaction(() async {
      final current = await (database.select(
        database.sales,
      )..where((s) => s.id.equals(saleId))).getSingleOrNull();
      if (current == null) return 'Venta no encontrada';
      if (current.isCanceled) {
        return 'La venta está cancelada y no se puede editar';
      }

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
                subtotal: quantity * unitPrice,
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
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
      return null;
    });
  }
}
