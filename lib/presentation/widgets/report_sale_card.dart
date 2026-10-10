import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sale_provider.dart';
import '../../models/report_models.dart';
import '../../theme/app_theme.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';

class ReportSaleCard extends ConsumerStatefulWidget {
  // Venta del reporte. Sus montos y su detalle se limitan a las líneas que
  // cumplen los filtros activos (ver SaleReportRow.lines).
  final SaleReportRow row;

  const ReportSaleCard({super.key, required this.row});

  @override
  ConsumerState<ReportSaleCard> createState() => _ReportSaleCardState();
}

class _ReportSaleCardState extends ConsumerState<ReportSaleCard> {
  bool _expanded = false;

  String _formatDate(DateTime date) => formatDateTime(date);

  // Detalle de la venta: solo las líneas incluidas en el reporte (todas las
  // líneas de la venta cuando no hay filtros por línea).
  Widget _buildItems(BuildContext context) {
    final lines = widget.row.lines;
    if (lines != null) return _itemsList(context, lines);
    return FutureBuilder(
      future: ref
          .read(saleProvider.notifier)
          .getItemsForSale(widget.row.sale.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          );
        }
        return _itemsList(context, [
          for (final item in snapshot.data!)
            SaleLineReport(item: item, categoryId: null, categoryName: ''),
        ]);
      },
    );
  }

  Widget _itemsList(BuildContext context, List<SaleLineReport> lines) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: lines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s14,
                  vertical: AppSpacing.s6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${line.item.productName} × ${line.item.quantity}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      'Bs. ${fixed2(line.subtotal)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.cyanDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.row.clientName,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          _formatDate(widget.row.sale.date),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        if (widget.row.locationName != null ||
                            widget.row.eventName != null)
                          Wrap(
                            spacing: 4,
                            children: [
                              if (widget.row.locationName != null)
                                _MiniPill(
                                  label: widget.row.locationName!,
                                  color: AppColors.cyanDark,
                                ),
                              if (widget.row.eventName != null)
                                _MiniPill(
                                  label: widget.row.eventName!,
                                  color: AppColors.success,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Bs. ${fixed2(widget.row.netAmount)}',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cyanDark,
                            ),
                      ),
                      if (widget.row.discountAmount > 0)
                        Text(
                          '-Bs. ${fixed2(widget.row.discountAmount)}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                    ],
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
            if (_expanded) _buildItems(context),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s6,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
