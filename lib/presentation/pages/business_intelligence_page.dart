import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/bi_provider.dart';
import '../../application/purchase_provider.dart';
import '../../application/report_provider.dart';
import '../../application/sale_provider.dart';
import '../../config/date_formatters.dart';
import '../../models/bi_models.dart';
import '../../models/product_model.dart';
import '../../models/purchase_kind.dart';
import '../../models/report_filters.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/bi_charts.dart';
import '../widgets/report_filters_widget.dart';

// Business Intelligence: indicadores y gráficos de ventas y compras para el
// periodo y los filtros elegidos (los mismos de Reportes). Las ventas
// canceladas y los registros con fecha posterior a hoy nunca cuentan.
class BusinessIntelligencePage extends ConsumerStatefulWidget {
  const BusinessIntelligencePage({super.key});

  @override
  ConsumerState<BusinessIntelligencePage> createState() =>
      _BusinessIntelligencePageState();
}

class _BusinessIntelligencePageState
    extends ConsumerState<BusinessIntelligencePage> {
  ReportFilters _filters = const ReportFilters();

  @override
  Widget build(BuildContext context) {
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
      appBar: const CustomAppBar(
        title: 'Business Intelligence',
        showBack: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final report = ref.watch(biReportProvider(_filters));

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      children: [
        // Los filtros van dentro de la lista: se desplazan con los gráficos
        // para no quitarles pantalla.
        ReportFiltersWidget(
          filters: _filters,
          onChanged: (f) => setState(() => _filters = f),
          activeTab: 0,
          combined: true,
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryCards(summary: report.summary),
              const SizedBox(height: AppSpacing.s8),
              _PeriodNote(filters: _filters),
              const SizedBox(height: AppSpacing.s16),
              BiRankingSection(
                title: 'Ventas por producto',
                subtitle: 'Los productos que más se vendieron',
                entries: report.salesByProduct,
                amountLabel: 'Ingresos',
                quantityLabel: 'Unidades',
                quantityText: (e) => '${formatQuantity(e.quantity)} uds.',
              ),
              const SizedBox(height: AppSpacing.s16),
              BiRankingSection(
                title: 'Ventas por categoría',
                subtitle: 'Ingresos o unidades por categoría de producto',
                entries: report.salesByCategory,
                amountLabel: 'Ingresos',
                quantityLabel: 'Unidades',
                quantityText: (e) => '${formatQuantity(e.quantity)} uds.',
              ),
              const SizedBox(height: AppSpacing.s16),
              BiRankingSection(
                title: 'Compras por material',
                subtitle: 'Gasto en cada material comprado',
                entries: report.purchasesByMaterial,
                amountLabel: 'Gasto',
                quantityText: (e) =>
                    '${formatQuantity(e.quantity)}${e.unit == null ? '' : ' ${e.unit}'}',
              ),
              const SizedBox(height: AppSpacing.s16),
              BiSectionCard(
                title: 'Ventas por tipo de precio',
                subtitle: 'Cuánto se vendió con Precio A y con Precio B',
                child: BiPriceTypeChart(entries: report.salesByPriceType),
              ),
              const SizedBox(height: AppSpacing.s16),
              BiSectionCard(
                title: 'Evolución en el tiempo',
                subtitle: report.timeSeries.isEmpty
                    ? 'Ingresos y gastos'
                    : 'Ingresos y gastos · vista ${report.timeSeries.granularity.label.toLowerCase()}',
                child: BiTimeSeriesChart(series: report.timeSeries),
              ),
              const SizedBox(height: AppSpacing.s16),
              BiRankingSection(
                title: 'Ventas por evento',
                subtitle: 'Ingresos de las ventas vinculadas a cada evento',
                entries: report.salesByEvent,
                amountLabel: 'Ingresos',
                quantityText: (e) {
                  final n = e.quantity.round();
                  return n == 1 ? '1 venta' : '$n ventas';
                },
              ),
              const SizedBox(height: AppSpacing.s16),
              _LowStockCard(entries: report.lowStock),
            ],
          ),
        ),
      ],
    );
  }
}

// Ingresos, gastos y balance del periodo, con el estilo del resumen de
// Reportes.
class _SummaryCards extends StatelessWidget {
  final BiSummary summary;

  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final balanceColor = summary.balance < 0
        ? AppColors.error
        : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Ingresos',
              value: formatMoney(summary.ingresos),
              valueColor: AppColors.primary,
            ),
          ),
          Expanded(
            child: _SummaryTile(
              label: 'Gastos',
              value: formatMoney(summary.gastos),
              valueColor: AppColors.error,
            ),
          ),
          Expanded(
            child: _SummaryTile(
              label: 'Balance',
              value: formatMoney(summary.balance),
              valueColor: balanceColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// Aclara qué periodo cubren los indicadores y qué filtros no afectan a todo:
// categoría, producto y tipo de precio solo existen en las ventas, y el tipo
// de operación solo en las compras.
class _PeriodNote extends StatelessWidget {
  final ReportFilters filters;

  const _PeriodNote({required this.filters});

  String get _period {
    final start = filters.startDate;
    final end = filters.endDate;
    if (start == null && end == null) return 'Todo el historial hasta hoy';
    // Con solo "Desde" se filtra ese único día (igual que en Reportes).
    if (end == null || start == end) return formatDate((start ?? end)!);
    if (start == null) return 'Hasta ${formatDate(end)}';
    return '${formatDate(start)} – ${formatDate(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final notes = [
      'Periodo: $_period. No incluye ventas canceladas ni registros con fecha '
          'posterior a hoy.',
      if (filters.categoryId != null ||
          filters.productId != null ||
          filters.priceType != null)
        'Categoría, producto y tipo de precio solo filtran las ventas.',
      if (filters.purchaseKind != PurchaseKind.all)
        'El tipo de operación solo filtra las compras.',
    ];
    return Text(
      notes.join('\n'),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
    );
  }
}

// Productos activos con stock bajo: estado actual del inventario, no
// depende de las fechas ni de los filtros.
class _LowStockCard extends StatelessWidget {
  final List<LowStockEntry> entries;

  const _LowStockCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return BiSectionCard(
      title: 'Productos con bajo stock',
      subtitle:
          'Stock de $lowStockThreshold o menos · estado actual, sin filtros',
      child: entries.isEmpty
          ? const BiEmptyState(message: 'Ningún producto con stock bajo')
          : Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  _LowStockRow(
                    entry: entries[i],
                    isLast: i == entries.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  final LowStockEntry entry;
  final bool isLast;

  const _LowStockRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.categoryName,
                  style: style.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            entry.isOutOfStock ? 'Agotado' : '${entry.product.stock} en stock',
            style: style.labelMedium?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
