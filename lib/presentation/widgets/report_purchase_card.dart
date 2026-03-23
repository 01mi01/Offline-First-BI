import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/purchase_provider.dart';
import '../../models/purchase_model.dart';
import '../../theme/app_theme.dart';

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
      onTap: widget.purchase.isMaterial
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            _MiniPill(
                              label: widget.purchase.isMaterial
                                  ? 'Material'
                                  : 'Gasto',
                              color: widget.purchase.isMaterial
                                  ? AppColors.primary
                                  : AppColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(widget.purchase.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (widget.purchase.description != null &&
                            widget.purchase.description!.isNotEmpty)
                          Text(
                            widget.purchase.description!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
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
                  Text(
                    'Bs. ${widget.purchase.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                      fontSize: 14,
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
                                horizontal: 14,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.materialName} × ${formatNumber(item.quantity)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Bs. ${item.subtotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
