import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';

// Qué precio(s) muestran las tarjetas de Productos (lista y catálogo).
enum PriceDisplay { a, b, both, none }

// Búsqueda, categoría y precio mostrado de Productos. El filtro de precio se
// controla desde la vista de lista; el catálogo solo lo refleja.
class ProductCatalogFilter {
  final String query;
  // null = todas las categorías
  final int? categoryId;
  // null = sin elegir: cada vista usa su valor por defecto (ver [displayFor]).
  final PriceDisplay? priceDisplay;

  const ProductCatalogFilter({
    this.query = '',
    this.categoryId,
    this.priceDisplay,
  });

  ProductCatalogFilter copyWith({
    String? query,
    int? categoryId,
    bool clearCategory = false,
    PriceDisplay? priceDisplay,
  }) {
    return ProductCatalogFilter(
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      priceDisplay: priceDisplay ?? this.priceDisplay,
    );
  }

  // Mientras no se elija nada, la lista muestra ambos precios (como siempre) y
  // el catálogo uno solo (Precio A). Al elegir, la opción vale para las dos
  // vistas.
  PriceDisplay displayFor({required bool grid}) =>
      priceDisplay ?? (grid ? PriceDisplay.a : PriceDisplay.both);

  bool get isFiltering => query.trim().isNotEmpty || categoryId != null;

  // Productos que cumplen la búsqueda (nombre o descripción) y la categoría,
  // en el orden en que llegan (alfabético por nombre desde el repositorio).
  List<ProductModel> apply(List<ProductModel> products) {
    final q = query.trim().toLowerCase();
    return products.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          (p.description ?? '').toLowerCase().contains(q);
    }).toList();
  }
}

// Vive mientras la pantalla de Productos está abierta (se reinicia al salir) y
// lo comparten la vista de lista y la de catálogo.
final productCatalogFilterProvider =
    StateProvider.autoDispose<ProductCatalogFilter>(
      (ref) => const ProductCatalogFilter(),
    );
