import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'client_provider.dart';
import 'purchase_provider.dart';
import 'report_provider.dart';
import 'sale_provider.dart';
import 'search_filter.dart';
import 'supplier_provider.dart';

// Texto de los buscadores de Ventas y Compras.
final saleListQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final purchaseListQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// Todas las palabras escritas (en cualquier orden) están en [haystack], sin
// distinguir mayúsculas ni tildes. Una búsqueda vacía coincide siempre.
bool matchesAllWords(String haystack, String query) {
  final words = normalizeForSearch(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final text = normalizeForSearch(haystack);
  return words.every(text.contains);
}

// Texto buscable de cada venta (cliente y productos de sus líneas), calculado
// una sola vez por cambio de datos y no con cada tecla.
final saleSearchTextProvider = Provider.autoDispose<Map<int, String>>((ref) {
  final sales = ref.watch(saleProvider).sales;
  final clients = {for (final c in ref.watch(clientProvider).clients) c.id: c.name};
  final items = ref.watch(saleItemsMapProvider).valueOrNull ?? const {};
  return {
    for (final s in sales)
      s.id: [
        clients[s.clientId] ?? 'Sin nombre',
        for (final i in items[s.id] ?? const []) i.productName,
      ].join(' '),
  };
});

// Texto buscable de cada compra: proveedor, materiales de sus líneas y, en los
// gastos, su descripción.
final purchaseSearchTextProvider = Provider.autoDispose<Map<int, String>>((ref) {
  final purchases = ref.watch(purchaseProvider).purchases;
  final suppliers = {
    for (final s in ref.watch(supplierProvider).suppliers) s.id: s.name,
  };
  final items = ref.watch(purchaseItemsMapProvider).valueOrNull ?? const {};
  return {
    for (final p in purchases)
      p.id: [
        suppliers[p.supplierId] ?? 'Sin proveedor',
        p.description ?? '',
        for (final i in items[p.id] ?? const []) i.materialName,
      ].join(' '),
  };
});
