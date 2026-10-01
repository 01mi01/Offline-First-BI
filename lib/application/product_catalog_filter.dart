import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';

// Qué precio(s) muestran las tarjetas de Productos (lista y catálogo).
// El orden de las opciones es el del menú: Ambos, Precio A, Precio B, Sin precio.
enum PriceDisplay { both, a, b, none }

// Búsqueda, categoría y precio mostrado de Productos. El filtro de precio se
// controla desde la vista de lista; el catálogo solo lo refleja.
class ProductCatalogFilter {
  final String query;
  // null = todas las categorías
  final int? categoryId;
  // Por defecto "Ambos", en la lista y en el catálogo.
  final PriceDisplay priceDisplay;

  const ProductCatalogFilter({
    this.query = '',
    this.categoryId,
    this.priceDisplay = PriceDisplay.both,
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
