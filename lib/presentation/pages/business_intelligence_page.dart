import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/bi_provider.dart';
import '../../application/product_provider.dart';
import '../../application/purchase_provider.dart';
import '../../application/report_provider.dart';
import '../../application/sale_provider.dart';
import '../../config/date_formatters.dart';
import '../../models/bi_config.dart';
import '../../models/purchase_kind.dart';
import '../../models/report_filters.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/bi_charts.dart';
import '../widgets/bi_config_view.dart';
import '../widgets/bi_insight_widgets.dart';
import '../widgets/bi_sales_widgets.dart';

// Business Intelligence: primero se configura el periodo, los filtros y los
// indicadores; al confirmar se muestra el panel, y desde él se puede volver a
// la configuración sin salir del módulo. Las ventas canceladas, los usos
// cancelados y los registros con fecha posterior a hoy nunca cuentan.
class BusinessIntelligencePage extends ConsumerStatefulWidget {
  const BusinessIntelligencePage({super.key});

  @override
  ConsumerState<BusinessIntelligencePage> createState() =>
      _BusinessIntelligencePageState();
}

class _BusinessIntelligencePageState
    extends ConsumerState<BusinessIntelligencePage> {
  // false = paso de configuración (siempre al entrar), true = panel.
  bool _showDashboard = false;

  BiConfig get _config => ref.read(biConfigProvider);

  void _update(BiConfig config) =>
      ref.read(biConfigProvider.notifier).state = config;

  void _setChartType(BiIndicator indicator, BiChartType type) => _update(
    _config.copyWith(chartTypes: {..._config.chartTypes, indicator: type}),
  );

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(biConfigProvider);
    final saleState = ref.watch(saleProvider);
    final purchaseState = ref.watch(purchaseProvider);
    final saleItemsMap = ref.watch(saleItemsMapProvider);
    final purchaseItemsMap = ref.watch(purchaseItemsMapProvider);

    final loading =
        saleState.isLoading ||
        purchaseState.isLoading ||
        saleItemsMap.isLoading ||
        purchaseItemsMap.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Business Intelligence', showBack: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _showDashboard
          ? _buildDashboard(config)
          : BiConfigView(
              config: config,
              onChanged: _update,
              onConfirm: () => setState(() => _showDashboard = true),
            ),
    );
  }

  Widget _buildDashboard(BiConfig config) {
    final report = ref.watch(biReportProvider(config.query));
    final products = ref.watch(productProvider).products;

    Widget? sectionFor(BiIndicator indicator) {
      final type = config.chartTypeFor(indicator);
      void onType(BiChartType t) => _setChartType(indicator, t);

      switch (indicator) {
        case BiIndicator.summary:
          return BiSummaryCards(summary: report.summary);
        case BiIndicator.periodComparison:
          return BiPeriodComparisonSection(
            comparison: report.periodComparison,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.timeSeries:
          return BiSectionCard(
            title: indicator.title,
            subtitle: report.timeSeries.isEmpty
                ? 'Ingresos y gastos'
                : 'Ingresos y gastos · vista ${report.timeSeries.granularity.label.toLowerCase()}',
            info: indicator.info,
            controls: BiControls.of(
              indicator: indicator,
              chartType: type,
              onChartTypeChanged: onType,
            ),
            child: BiTimeSeriesChart(
              series: report.timeSeries,
              asBars: type == BiChartType.bar,
            ),
          );
        case BiIndicator.salesProjection:
          return BiProjectionSection(
            projection: report.projection,
            series: report.timeSeries,
          );
        case BiIndicator.salesByProduct:
          return BiRankingSection(
            indicator: indicator,
            chartType: type,
            onChartTypeChanged: onType,
            subtitle: 'Los productos que más se vendieron',
            entries: report.salesByProduct,
            amountLabel: 'Ingresos',
            quantityLabel: 'Unidades',
            quantityText: (e) => '${formatQuantity(e.quantity)} uds.',
          );
        case BiIndicator.productMargin:
          return BiMarginSection(
            report: report.productMargins,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.salesByCategory:
          return BiRankingSection(
            indicator: indicator,
            chartType: type,
            onChartTypeChanged: onType,
            subtitle: 'Ingresos o unidades por categoría de producto',
            entries: report.salesByCategory,
            amountLabel: 'Ingresos',
            quantityLabel: 'Unidades',
            quantityText: (e) => '${formatQuantity(e.quantity)} uds.',
          );
        case BiIndicator.salesByPriceType:
          return BiRankingSection(
            indicator: indicator,
            chartType: type,
            onChartTypeChanged: onType,
            subtitle: 'Cuánto se vendió con Precio A y con Precio B',
            entries: report.salesByPriceType,
            amountLabel: 'Ingresos',
            quantityLabel: 'Unidades',
            keepOrder: true,
            quantityText: (e) => '${formatQuantity(e.quantity)} uds.',
          );
        case BiIndicator.salesByEvent:
          return BiRankingSection(
            indicator: indicator,
            chartType: type,
            onChartTypeChanged: onType,
            subtitle: 'Ingresos de las ventas vinculadas a cada evento',
            entries: report.salesByEvent,
            amountLabel: 'Ingresos',
            quantityText: (e) {
              final n = e.quantity.round();
              return n == 1 ? '1 venta' : '$n ventas';
            },
          );
        case BiIndicator.eventComparison:
          return BiEventComparisonSection(
            comparison: report.eventComparison,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.coPurchase:
          return BiCoPurchaseSection(
            report: report.coPurchases,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.weekdaySales:
          return BiWeekdaySection(
            entries: report.weekdays,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.averageTicket:
          return BiTicketSection(
            report: report.ticket,
            series: report.timeSeries,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.eventProfit:
          return BiEventProfitSection(
            entries: report.eventProfit,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.discountImpact:
          return BiDiscountSection(
            report: report.discounts,
            series: report.timeSeries,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.costReturn:
          return BiCostReturnSection(
            report: report.costReturn,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.purchasesByMaterial:
          return BiRankingSection(
            indicator: indicator,
            chartType: type,
            onChartTypeChanged: onType,
            subtitle: 'Gasto en cada material comprado',
            entries: report.purchasesByMaterial,
            amountLabel: 'Gasto',
            quantityText: (e) =>
                '${formatQuantity(e.quantity)}${e.unit == null ? '' : ' ${e.unit}'}',
          );
        case BiIndicator.materialCostRatio:
          return BiMaterialCostSection(
            cost: report.materialCost,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.productRadar:
          return BiRadarSection(
            radar: report.radar,
            products: products,
            onSelectionChanged: (ids) =>
                _update(_config.copyWith(radarProductIds: ids)),
          );
        case BiIndicator.lowStock:
          return BiLowStockSection(entries: report.lowStock);
        case BiIndicator.noMovement:
          return BiNoMovementSection(
            entries: report.noMovement,
            windowDays: config.noMovementDays,
            onWindowChanged: (days) =>
                _update(_config.copyWith(noMovementDays: days)),
          );
      }
    }

    final sections = <Widget>[
      for (final indicator in BiIndicator.values)
        if (config.indicators.contains(indicator))
          KeyedSubtree(
            key: ValueKey('bi-section-${indicator.name}'),
            child: sectionFor(indicator)!,
          ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        _DashboardHeader(
          config: config,
          onConfigure: () => setState(() => _showDashboard = false),
        ),
        for (final section in sections) ...[
          const SizedBox(height: AppSpacing.s16),
          section,
        ],
      ],
    );
  }
}

// Cabecera del panel: qué periodo y filtros se aplican y el acceso para
// volver a configurarlos.
class _DashboardHeader extends StatelessWidget {
  final BiConfig config;
  final VoidCallback onConfigure;

  const _DashboardHeader({required this.config, required this.onConfigure});

  ReportFilters get _filters => config.filters;

  String get _period {
    final start = _filters.startDate;
    final end = _filters.endDate;
    if (start == null && end == null) return 'Todo el historial hasta hoy';
    // Con solo "Desde" se filtra ese único día (igual que en Reportes).
    if (end == null || start == end) return formatDate((start ?? end)!);
    if (start == null) return 'Hasta ${formatDate(end)}';
    return '${formatDate(start)} – ${formatDate(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final notes = [
      'No incluye ventas canceladas ni registros con fecha posterior a hoy.',
      if (_filters.categoryId != null ||
          _filters.productId != null ||
          _filters.priceType != null)
        'Categoría, producto y tipo de precio solo filtran las ventas.',
      if (_filters.purchaseKind != PurchaseKind.all)
        'El tipo de operación solo filtra las compras.',
    ];
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('bi-period'),
            'Periodo: $_period',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            '${config.indicators.length} indicadores · ${notes.join(' ')}',
            style: style,
          ),
          const SizedBox(height: AppSpacing.s12),
          OutlinedButton.icon(
            key: const ValueKey('bi-configure'),
            onPressed: onConfigure,
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Configurar'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
