import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';
import 'record_search.dart';
import 'status_filter.dart';

// Qué precio(s) muestran las tarjetas de Productos (lista y catálogo).
// El orden de las opciones es el del menú: Ambos, Precio A, Precio B, Sin precio.
enum PriceDisplay { both, a, b, none }

// Búsqueda, categoría, estado y precio mostrado de Productos. El filtro de precio se
// controla desde la vista de lista; el catálogo solo lo refleja.
class ProductCatalogFilter {
  final String query;
  // null = todas las categorías
  final int? categoryId;
  // Por defecto "Ambos", en la lista y en el catálogo.
  final PriceDisplay priceDisplay;
  // Activos, inactivos o todos (por defecto, todos).
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

  bool get isFiltering =>
      query.trim().isNotEmpty ||
      categoryId != null ||
      status != StatusFilter.all;

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

// Vive mientras la pantalla de Productos está abierta (se reinicia al salir) y
// lo comparten la vista de lista y la de catálogo.
final productCatalogFilterProvider =
    StateProvider.autoDispose<ProductCatalogFilter>(
      (ref) => const ProductCatalogFilter(),
    );
