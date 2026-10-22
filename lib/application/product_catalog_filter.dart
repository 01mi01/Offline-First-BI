import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';
import 'record_search.dart';
import 'status_filter.dart';

enum PriceDisplay { both, a, b, none }

class ProductCatalogFilter {
  final String query;
  final int? categoryId;
  final PriceDisplay priceDisplay;
  final StatusFilter status;

  const ProductCatalogFilter({
    this.query = '',
    this.categoryId,
    this.priceDisplay = PriceDisplay.both,
    this.status = StatusFilter.all,
  });

  ProductCatalogFilter copyWith({
    String? query,
    int? categoryId,
    bool clearCategory = false,
    PriceDisplay? priceDisplay,
    StatusFilter? status,
  }) {
    return ProductCatalogFilter(
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      priceDisplay: priceDisplay ?? this.priceDisplay,
      status: status ?? this.status,
    );
  }

  List<ProductModel> apply(
    List<ProductModel> products, {
    SearchIndex<ProductModel>? index,
  }) {
    final found = (index ?? SearchIndex(products, (p) => '${p.name} ${p.description ?? ''}'))
        .search(query);
    return found.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      return status.matches(p.isActive);
    }).toList();
  }
}

final productCatalogFilterProvider =
    StateProvider.autoDispose<ProductCatalogFilter>(
      (ref) => const ProductCatalogFilter(),
    );
