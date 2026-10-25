import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'app_group.dart';
import 'app_sheet.dart';
import 'app_style.dart';
import 'protected_record_icon.dart';
import 'record_detail.dart';
import 'record_list.dart';
import 'status_badge.dart';

class ContactRow extends StatelessWidget {
  final String name;
  final String? contactInfo;
  final bool isActive;
  final String? protectedMessage;
  final VoidCallback onTap;

  const ContactRow({
    super.key,
    required this.name,
    required this.contactInfo,
    required this.isActive,
    required this.onTap,
    this.protectedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final info = contactInfo;
    return RecordRow(
      title: name,
      details: [if (info != null && info.isNotEmpty) RecordLine(info, maxLines: 1)],
      pill: StatusBadge.forState(isActive: isActive),
      trailing: protectedMessage == null
          ? null
          : ProtectedRecordIcon(message: protectedMessage!),
      onTap: onTap,
    );
  }
}

void showContactDetail(
  BuildContext context, {
  required String title,
  required String name,
  required String? contactInfo,
  required bool isActive,
  String? protectedMessage,
  VoidCallback? onEdit,
}) {
  showAppSheet<void>(
    context,
    builder: (_) => RecordDetailSheet(
      title: title,
      onEdit: protectedMessage == null ? onEdit : null,
      children: [
        RecordHeadline(
          title: name,
          pill: StatusBadge.forState(isActive: isActive),
          note: protectedMessage,
        ),
        AppSection(
          header: 'Información de contacto',
          children: [_ContactInfo(info: contactInfo)],
        ),
      ],
    ),
  );
}

class _ContactInfo extends StatefulWidget {
  final String? info;

  const _ContactInfo({required this.info});

  @override
  State<_ContactInfo> createState() => _ContactInfoState();
}

class _ContactInfoState extends State<_ContactInfo> {
  bool _copied = false;

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.info;
    if (text == null || text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Text(
          'Sin información de contacto',
          style: AppText.rowTitle(context, color: AppColors.textSecondary),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Text(
              text,
              style: AppText.rowTitle(context, color: AppColors.textSecondary),
            ),
          ),
        ),
        IconButton(
          tooltip: _copied ? 'Copiado' : 'Copiar',
          icon: Icon(
            _copied ? Icons.check_rounded : Icons.copy_rounded,
            color: AppColors.cyanDark,
            size: AppIconSize.s20,
          ),
          onPressed: () => _copy(text),
        ),
      ],
    );
  }
}
