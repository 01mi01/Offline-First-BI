import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/bi_provider.dart';
import '../../application/product_provider.dart';
import '../../application/purchase_provider.dart';
import '../../application/report_provider.dart';
import '../../application/sale_provider.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';
import '../../models/bi_config.dart';
import '../../theme/app_theme.dart';
import '../widgets/profile_button.dart';
import '../widgets/screen_header.dart';
import '../widgets/bi_charts.dart';
import '../widgets/bi_config_view.dart';
import '../widgets/bi_drilldown.dart';
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

  // La opción del interruptor de métrica vive en la configuración (no en el
  // gráfico) para que no se pierda al salir de pantalla y volver.
  void _setMetric(BiIndicator indicator, int metric) => _update(
    _config.copyWith(metrics: {..._config.metrics, indicator: metric}),
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

    return PopScope(
      canPop: !_showDashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _showDashboard = false);
      },
      child: ScreenScaffold(
        title: 'Business Intelligence',
        actions: const [ProfileButton()],
        showBack: _showDashboard ? true : null,
        onBack: _showDashboard
            ? () => setState(() => _showDashboard = false)
            : null,
        bottomBar: loading || _showDashboard
            ? null
            : ElevatedButton(
                key: const ValueKey('bi-config-confirm'),
                onPressed: config.indicators.isEmpty ? null : _confirm,
                child: Text(
                  config.indicators.isEmpty
                      ? 'Elige al menos un indicador'
                      : 'Ver indicadores (${config.indicators.length})',
                ),
              ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : _showDashboard
            ? _buildDashboard(config)
            : BiConfigView(config: config, onChanged: _update),
      ),
    );
  }

  void _confirm() {
    _update(_config.copyWith(metrics: const {}));
    setState(() => _showDashboard = true);
  }

  Widget _buildDashboard(BiConfig config) {
    final report = ref.watch(biReportProvider(config.query));
    final products = ref.watch(productProvider).products;

    Widget? sectionFor(BiIndicator indicator) {
      final type = config.chartTypeFor(indicator);
      void onType(BiChartType t) => _setChartType(indicator, t);
      final metric = config.metricFor(indicator);
      void onMetric(int m) => _setMetric(indicator, m);

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
            metric: metric,
            onMetricChanged: onMetric,
            indicator: indicator,
            chartType: type,
            onChartTypeChanged: onType,
            subtitle: 'Los productos que más se vendieron',
            entries: report.salesByProduct,
            onEntryTap: (e) => showBiDrillDown(
              context,
              kind: BiDrillKind.product,
              entry: e,
              query: config.query,
            ),
            amountLabel: 'Ingresos',
            quantityLabel: 'Unidades',
            quantityText: (e) => '${formatQuantity(e.quantity)} uds.',
          );
        case BiIndicator.productMargin:
          return BiMarginSection(
            metric: metric,
            onMetricChanged: onMetric,
            report: report.productMargins,
            chartType: type,
            onChartTypeChanged: onType,
          );
        case BiIndicator.salesByCategory:
          return BiRankingSection(
            metric: metric,
            onMetricChanged: onMetric,
            indicator: indicator,
            chartType: type,
            onChartTypeChanged: onType,
            subtitle: 'Ingresos o unidades por categoría de producto',
            entries: report.salesByCategory,
            onEntryTap: (e) => showBiDrillDown(
              context,
              kind: BiDrillKind.category,
              entry: e,
              query: config.query,
            ),
            amountLabel: 'Ingresos',
            quantityLabel: 'Unidades',
            quantityText: (e) => '${formatQuantity(e.quantity)} uds.',
          );
        case BiIndicator.salesByPriceType:
          return BiRankingSection(
            metric: metric,
            onMetricChanged: onMetric,
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
            metric: metric,
            onMetricChanged: onMetric,
            indicator: indicator,
            chartType: type,
            onChartTypeChanged: onType,
            subtitle: 'Ingresos de las ventas vinculadas a cada evento',
            entries: report.salesByEvent,
            onEntryTap: (e) => showBiDrillDown(
              context,
              kind: BiDrillKind.event,
              entry: e,
              query: config.query,
            ),
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
            metric: metric,
            onMetricChanged: onMetric,
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
            metric: metric,
            onMetricChanged: onMetric,
            indicator: indicator,
            chartType: type,
            onChartTypeChanged: onType,
            subtitle: 'Gasto en cada material comprado',
            entries: report.purchasesByMaterial,
            onEntryTap: (e) => showBiDrillDown(
              context,
              kind: BiDrillKind.material,
              entry: e,
              query: config.query,
            ),
            amountLabel: 'Gasto',
            quantityText: (e) =>
                '${formatMaterialQuantity(e.quantity, unitType: e.unitType ?? 'medida', unitName: e.unit ?? '')}${e.unit == null ? '' : ' ${e.unit}'}',
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
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _DashboardHeader(config: config),
        for (final section in sections) ...[
          const SizedBox(height: AppSpacing.s16),
          section,
        ],
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final BiConfig config;

  const _DashboardHeader({required this.config});

  String get _period {
    final start = config.filters.startDate;
    final end = config.filters.endDate;
    if (start == null && end == null) return 'Todo el historial hasta hoy';
    if (end == null || start == end) return formatDate((start ?? end)!);
    if (start == null) return 'Hasta ${formatDate(end)}';
    return '${formatDate(start)} – ${formatDate(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Text(
        'Periodo: $_period',
        key: const ValueKey('bi-period'),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
