import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/sale_provider.dart';
import '../../models/sale_model.dart';
import '../../theme/app_theme.dart';

class ReportSaleCard extends ConsumerStatefulWidget {
  final SaleModel sale;
  final String clientName;
  final String? locationName;
  final String? eventName;

  const ReportSaleCard({
    super.key,
    required this.sale,
    required this.clientName,
    this.locationName,
    this.eventName,
  });

  @override
  ConsumerState<ReportSaleCard> createState() => _ReportSaleCardState();
}

class _ReportSaleCardState extends ConsumerState<ReportSaleCard> {
  bool _expanded = false;

  String _formatDate(DateTime date) {
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
                          widget.clientName,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          _formatDate(widget.sale.date),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        if (widget.locationName != null ||
                            widget.eventName != null)
                          Wrap(
                            spacing: 4,
                            children: [
                              if (widget.locationName != null)
                                _MiniPill(
                                  label: widget.locationName!,
                                  color: AppColors.primary,
                                ),
                              if (widget.eventName != null)
                                _MiniPill(
                                  label: widget.eventName!,
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
                        'Bs. ${widget.sale.finalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                      if (widget.sale.discount > 0)
                        Text(
                          '-Bs. ${widget.sale.discount.toStringAsFixed(2)}',
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
            if (_expanded)
              FutureBuilder(
                future: ref
                    .read(saleProvider.notifier)
                    .getItemsForSale(widget.sale.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    );
                  }
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Column(
                      children: snapshot.data!
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s14,
                                vertical: AppSpacing.s6,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.productName} × ${item.quantity}',
                                      style: Theme.of(context).textTheme
                                          .labelMedium?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    'Bs. ${item.subtotal.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme
                                        .labelMedium?.copyWith(
                                          color: AppColors.primary,
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
                },
              ),
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
