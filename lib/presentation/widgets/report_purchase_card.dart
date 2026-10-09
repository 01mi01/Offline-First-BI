import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/purchase_provider.dart';
import '../../models/purchase_model.dart';
import '../../theme/app_theme.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';

class ReportPurchaseCard extends ConsumerStatefulWidget {
  final PurchaseModel purchase;
  final String supplierName;
  final String? locationName;
  final String? eventName;

  const ReportPurchaseCard({
    super.key,
    required this.purchase,
    required this.supplierName,
    this.locationName,
    this.eventName,
  });

  @override
  ConsumerState<ReportPurchaseCard> createState() => _ReportPurchaseCardState();
}

class _ReportPurchaseCardState extends ConsumerState<ReportPurchaseCard> {
  bool _expanded = false;

  String _formatDate(DateTime date) => formatDateTime(date);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.purchase.isMaterial
          ? () => setState(() => _expanded = !_expanded)
          : null,
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.supplierName,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                            ),
                            _MiniPill(
                              label: widget.purchase.isMaterial
                                  ? 'Material'
                                  : 'Gasto',
                              color: widget.purchase.isMaterial
                                  ? AppColors.primaryDark
                                  : AppColors.textPrimary,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          _formatDate(widget.purchase.date),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        if (widget.purchase.description != null &&
                            widget.purchase.description!.isNotEmpty)
                          Text(
                            widget.purchase.description!,
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.s4),
                        Wrap(
                          spacing: 4,
                          children: [
                            if (widget.locationName != null)
                              _MiniPill(
                                label: widget.locationName!,
                                color: AppColors.primaryDark,
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
                  Text(
                    'Bs. ${fixed2(widget.purchase.totalAmount)}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  if (widget.purchase.isMaterial)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                ],
              ),
            ),
            if (_expanded && widget.purchase.isMaterial)
              FutureBuilder(
                future: ref
                    .read(purchaseProvider.notifier)
                    .getItemsForPurchase(widget.purchase.id),
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
                                      '${item.materialName} × ${formatMaterialQuantity(item.quantity, unitType: item.unitType, unitName: item.unitName)}',
                                      style: Theme.of(context).textTheme
                                          .labelMedium?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    'Bs. ${fixed2(item.subtotal)}',
                                    style: Theme.of(context).textTheme
                                        .labelMedium?.copyWith(
                                          color: AppColors.primaryDark,
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
