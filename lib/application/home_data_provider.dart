import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bi_config.dart';
import '../models/bi_models.dart';
import '../models/product_model.dart';
import '../models/purchase_model.dart';
import '../models/report_filters.dart';
import '../models/report_models.dart';
import 'bi_provider.dart';
import 'date_range_filter.dart';
import 'event_provider.dart';
import 'home_dashboard.dart';
import 'material_provider.dart';
import 'module_permission_provider.dart';
import 'product_provider.dart';
import 'report_provider.dart';
import 'today_provider.dart';

final homeAccessProvider = Provider<HomeAccess>(
  (ref) => HomeAccess.from(
    ref.watch(readableModulesProvider).valueOrNull ?? const [],
  ),
);

final homeReportProvider = Provider.autoDispose.family<BiReport?, BiQuery>((
  ref,
  query,
) {
  if (!ref.watch(homeAccessProvider).needsReport) return null;
  return ref.watch(biReportProvider(query));
});

final homeSaleRowsProvider = Provider.autoDispose
    .family<List<SaleReportRow>, ReportFilters>((ref, filters) {
      if (!ref.watch(homeAccessProvider).salesFigures) return const [];
      return ref.watch(saleReportRowsProvider(filters));
    });

final homePurchasesProvider = Provider.autoDispose
    .family<List<PurchaseModel>, ReportFilters>((ref, filters) {
      if (!ref.watch(homeAccessProvider).purchaseFigures) return const [];
      return ref.watch(filteredPurchasesProvider(filters));
    });

final homeOverviewProvider = Provider.autoDispose<HomeOverview>((ref) {
  final access = ref.watch(homeAccessProvider);
  if (!access.overview) return const HomeOverview();
  final today = ref.watch(todayProvider);
  final products = access.inventory
      ? ref.watch(productProvider).products.where((p) => p.isActive).toList()
      : null;
  final materials = access.materials
      ? ref.watch(materialProvider).materials.where((m) => m.isActive).length
      : null;
  final events = access.events
      ? ref
            .watch(eventProvider)
            .events
            .where(
              (e) =>
                  e.isActive &&
                  !dateOnly(e.endDate ?? e.startDate).isBefore(today),
            )
            .length
      : null;
  return HomeOverview(
    activeProducts: products?.length,
    lowStockProducts: products
        ?.where((p) => p.stock <= lowStockThreshold)
        .length,
    activeMaterials: materials,
    upcomingEvents: events,
  );
});
