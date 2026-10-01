import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';

// Qué precio muestra la vista de catálogo en cada tarjeta. No hay opción
// "ambos": sin las etiquetas A/B, dos cifras sueltas no se distinguirían.
enum PriceDisplay { a, b, none }

enum ProductSort { name, priceAsc, priceDesc }

// Filtros, búsqueda y orden de Productos (vistas de lista y de catálogo).
class ProductCatalogFilter {
  final String query;
  // null = todas las categorías
  final int? categoryId;
  final PriceDisplay priceDisplay;
  final ProductSort sort;

  const ProductCatalogFilter({
    this.query = '',
    this.categoryId,
    this.priceDisplay = PriceDisplay.a,
    this.sort = ProductSort.name,
  });

  ProductCatalogFilter copyWith({
    String? query,
    int? categoryId,
    bool clearCategory = false,
    PriceDisplay? priceDisplay,
    ProductSort? sort,
  }) {
    return ProductCatalogFilter(
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      priceDisplay: priceDisplay ?? this.priceDisplay,
      sort: sort ?? this.sort,
    );
  }

  // El orden por precio usa el precio elegido en el filtro de precio; sin
  // precio elegido no hay con qué ordenar, y el orden vuelve a ser por nombre.
  bool get canSortByPrice => priceDisplay != PriceDisplay.none;

  ProductSort get effectiveSort =>
      canSortByPrice ? sort : ProductSort.name;

  // Precio del producto según el filtro de precio (A por defecto).
  double priceOf(ProductModel p) =>
      priceDisplay == PriceDisplay.b ? p.priceB : p.priceA;

  bool get isFiltering => query.trim().isNotEmpty || categoryId != null;

  List<ProductModel> apply(List<ProductModel> products) {
    final q = query.trim().toLowerCase();
    final result = products.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          (p.description ?? '').toLowerCase().contains(q);
    }).toList();

    int byName(ProductModel a, ProductModel b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    switch (effectiveSort) {
      case ProductSort.name:
        result.sort(byName);
      case ProductSort.priceAsc:
        result.sort((a, b) {
          final c = priceOf(a).compareTo(priceOf(b));
          return c != 0 ? c : byName(a, b);
        });
      case ProductSort.priceDesc:
        result.sort((a, b) {
          final c = priceOf(b).compareTo(priceOf(a));
          return c != 0 ? c : byName(a, b);
        });
    }
    return result;
  }
}

// Vive mientras la pantalla de Productos está abierta (se reinicia al salir) y
// lo comparten la vista de lista y la de catálogo.
final productCatalogFilterProvider =
    StateProvider.autoDispose<ProductCatalogFilter>(
      (ref) => const ProductCatalogFilter(),
    );
