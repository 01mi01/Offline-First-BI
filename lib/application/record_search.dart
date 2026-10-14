import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../models/client_model.dart';
import '../models/event_model.dart';
import '../models/location_model.dart';
import '../models/material_model.dart';
import '../models/product_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../models/supplier_model.dart';
import 'category_provider.dart';
import 'client_provider.dart';
import 'event_provider.dart';
import 'location_options.dart';
import 'location_provider.dart';
import 'material_provider.dart';
import 'product_provider.dart';
import 'purchase_provider.dart';
import 'report_provider.dart';
import 'sale_provider.dart';
import 'search_filter.dart';
import 'supplier_provider.dart';
import 'unit_provider.dart';

final saleListQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final purchaseListQueryProvider = StateProvider.autoDispose<String>((ref) => '');

List<String> searchWords(String query) => normalizeForSearch(
  query,
).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

bool matchesWords(String normalizedText, List<String> words) =>
    words.every(normalizedText.contains);

class SearchIndex<T> {
  final List<T> items;
  final List<String> _texts;

  SearchIndex(Iterable<T> items, String Function(T item) textOf)
    : items = items.toList(),
      _texts = [for (final i in items) normalizeForSearch(textOf(i))];

  List<T> search(String query) {
    final words = searchWords(query);
    if (words.isEmpty) return items;
    return [
      for (var i = 0; i < items.length; i++)
        if (matchesWords(_texts[i], words)) items[i],
    ];
  }
}

String _join(Iterable<String?> parts) =>
    parts.whereType<String>().where((p) => p.isNotEmpty).join(' ');

final productSearchIndexProvider =
    Provider.autoDispose<SearchIndex<ProductModel>>((ref) {
      final categories = {
        for (final c in ref.watch(categoryProvider).categories) c.id: c.name,
      };
      return SearchIndex(
        ref.watch(productProvider).products,
        (p) => _join([p.name, p.description, categories[p.categoryId]]),
      );
    });

final categorySearchIndexProvider =
    Provider.autoDispose<SearchIndex<CategoryModel>>(
      (ref) => SearchIndex(
        ref.watch(categoryProvider).categories,
        (c) => c.name,
      ),
    );

final clientSearchIndexProvider = Provider.autoDispose<SearchIndex<ClientModel>>(
  (ref) => SearchIndex(
    ref.watch(clientProvider).clients,
    (c) => _join([c.name, c.contactInfo]),
  ),
);

final supplierSearchIndexProvider =
    Provider.autoDispose<SearchIndex<SupplierModel>>(
      (ref) => SearchIndex(
        ref.watch(supplierProvider).suppliers,
        (s) => _join([s.name, s.contactInfo]),
      ),
    );

final locationSearchIndexProvider =
    Provider.autoDispose<SearchIndex<LocationModel>>(
      (ref) => SearchIndex(
        ref.watch(locationProvider).locations,
        locationSearchText,
      ),
    );

final eventSearchIndexProvider = Provider.autoDispose<SearchIndex<EventModel>>((
  ref,
) {
  final locations = {
    for (final l in ref.watch(locationProvider).locations) l.id: l,
  };
  return SearchIndex(ref.watch(eventProvider).events, (e) {
    final location = locations[e.locationId];
    return _join([
      e.name,
      e.notes,
      location == null ? null : locationSearchText(location),
    ]);
  });
});

final materialSearchIndexProvider =
    Provider.autoDispose<SearchIndex<MaterialModel>>((ref) {
      final units = {for (final u in ref.watch(unitProvider).units) u.id: u.name};
      return SearchIndex(
        ref.watch(materialProvider).materials,
        (m) => _join([m.name, m.description, units[m.unitId]]),
      );
    });

final saleSearchIndexProvider = Provider.autoDispose<SearchIndex<SaleModel>>((
  ref,
) {
  final clients = {for (final c in ref.watch(clientProvider).clients) c.id: c.name};
  final items = ref.watch(saleItemsMapProvider).valueOrNull ?? const {};
  return SearchIndex(
    ref.watch(saleProvider).sales,
    (s) => _join([
      clients[s.clientId] ?? 'Sin nombre',
      for (final i in items[s.id] ?? const []) i.productName,
    ]),
  );
});

final purchaseSearchIndexProvider =
    Provider.autoDispose<SearchIndex<PurchaseModel>>((ref) {
      final suppliers = {
        for (final s in ref.watch(supplierProvider).suppliers) s.id: s.name,
      };
      final items = ref.watch(purchaseItemsMapProvider).valueOrNull ?? const {};
      return SearchIndex(
        ref.watch(purchaseProvider).purchases,
        (p) => _join([
          suppliers[p.supplierId] ?? 'Sin proveedor',
          p.description,
          for (final i in items[p.id] ?? const []) i.materialName,
        ]),
      );
    });
