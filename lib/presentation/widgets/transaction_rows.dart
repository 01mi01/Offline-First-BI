import 'package:flutter/material.dart';
import '../../config/date_formatters.dart';
import '../../config/rounding.dart';
import '../../theme/app_theme.dart';
import 'record_list.dart';
import 'status_badge.dart';

String? _moreLabel(int count) => count > 1 ? '+${count - 1} más' : null;

RecordRow saleRecordRow({
  required List<String> productNames,
  required String clientName,
  required DateTime date,
  required double discount,
  required double amount,
  bool canceled = false,
  List<String> extraLines = const [],
  VoidCallback? onTap,
}) {
  final hasProducts = productNames.isNotEmpty;
  return RecordRow(
    title: hasProducts ? productNames.first : clientName,
    titleSuffix: _moreLabel(productNames.length),
    titleColor: canceled ? AppColors.textSecondary : null,
    details: [
      if (hasProducts) RecordLine(clientName),
      RecordLine(formatDateTime(date)),
      for (final line in extraLines) RecordLine(line),
      if (discount > 0)
        RecordLine('Desc. Bs. ${fixed2(discount)}', color: AppColors.cyanDeep),
    ],
    pill: canceled ? const StatusBadge.canceled() : null,
    trailing: RecordValue('Bs. ${fixed2(amount)}', canceled: canceled),
    onTap: onTap,
  );
}

RecordRow purchaseRecordRow({
  required List<String> materialNames,
  required String? description,
  required bool isMaterial,
  required String supplierName,
  required DateTime date,
  required double amount,
  bool canceled = false,
  List<String> extraLines = const [],
  VoidCallback? onTap,
}) {
  final text = description != null && description.isNotEmpty
      ? description
      : null;
  final String title;
  if (isMaterial && materialNames.isNotEmpty) {
    title = materialNames.first;
  } else {
    title = text ?? supplierName;
  }
  final showDescription = isMaterial && text != null;
  return RecordRow(
    title: title,
    titleSuffix: isMaterial ? _moreLabel(materialNames.length) : null,
    titleColor: canceled ? AppColors.textSecondary : null,
    details: [
      if (title != supplierName) RecordLine(supplierName),
      RecordLine(formatDateTime(date)),
      if (showDescription) RecordLine(text, maxLines: 1),
      for (final line in extraLines) RecordLine(line),
    ],
    pill: Wrap(
      spacing: AppSpacing.s6,
      runSpacing: AppSpacing.s4,
      children: [
        StatusBadge.purchaseType(isMaterial: isMaterial),
        if (canceled) const StatusBadge.canceled(),
      ],
    ),
    trailing: RecordValue('Bs. ${fixed2(amount)}', canceled: canceled),
    onTap: onTap,
  );
}
