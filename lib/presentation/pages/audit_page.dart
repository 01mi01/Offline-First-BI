import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/audit_labels.dart';
import '../../application/audit_provider.dart';
import '../../config/date_formatters.dart';
import '../../data/db/audit_log.dart';
import '../../data/repositories/audit_repository.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_panel.dart';
import '../widgets/profile_button.dart';
import '../widgets/record_list.dart';
import '../widgets/screen_header.dart';

const String auditTitle = 'Auditoría';
const String auditUnknownUser = 'Usuario desconocido';

class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canViewAuditProvider)) {
      return const ScreenScaffold(
        title: auditTitle,
        body: AppEmptyState.hint(
          icon: Icons.lock_rounded,
          text: auditRoleOnlyMessage,
        ),
      );
    }
    return const _AuditListBody();
  }
}

String auditEntryTitle(AuditEntry entry) {
  final label = entry.recordLabel;
  final record = label == null || label.isEmpty ? '' : ': $label';
  return '${auditActionLabel(entry.action)} · '
      '${auditEntityLabel(entry.entity)}$record';
}

class _AuditListBody extends ConsumerWidget {
  const _AuditListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(auditEntriesProvider);
    final users = ref.watch(auditUsersProvider).valueOrNull ?? const [];
    final fields = <FilterField>[
      FilterDropdown<int?>(
        label: 'Usuario',
        options: [
          const FilterOption<int?>(null, 'Todos los usuarios'),
          for (final user in users) FilterOption<int?>(user.id, user.username),
        ],
        current: ref.watch(auditUserFilterProvider),
        defaultValue: null,
        onApply: (value) =>
            ref.read(auditUserFilterProvider.notifier).state = value,
      ),
      FilterDropdown<String?>(
        label: 'Módulo',
        options: [
          const FilterOption<String?>(null, 'Todos los módulos'),
          for (final module in AuditModule.all)
            FilterOption<String?>(module, auditModuleLabel(module)),
        ],
        current: ref.watch(auditModuleFilterProvider),
        defaultValue: null,
        onApply: (value) =>
            ref.read(auditModuleFilterProvider.notifier).state = value,
      ),
      FilterDropdown<String?>(
        label: 'Acción',
        options: [
          const FilterOption<String?>(null, 'Todas las acciones'),
          for (final action in AuditAction.all)
            FilterOption<String?>(action, auditActionLabel(action)),
        ],
        current: ref.watch(auditActionFilterProvider),
        defaultValue: null,
        onApply: (value) =>
            ref.read(auditActionFilterProvider.notifier).state = value,
      ),
      FilterDates(
        current: ref.watch(auditDateFilterProvider),
        onApply: (value) =>
            ref.read(auditDateFilterProvider.notifier).state = value,
      ),
    ];

    return ScreenScaffold.slivers(
      title: auditTitle,
      actions: const [ProfileButton()],
      slivers: [
        SliverToBoxAdapter(child: FilterArea(fields: fields)),
        ...page.when(
          loading: () => const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState.hint(
                icon: Icons.error_outline_rounded,
                text: error.toString(),
              ),
            ),
          ],
          data: (data) => [
            if (data.entries.isEmpty)
              const SliverToBoxAdapter(
                child: AppEmptyState.hint(
                  icon: Icons.history_rounded,
                  text: 'No hay registros de auditoría para mostrar.',
                ),
              )
            else
              AppSliverGroup(
                itemCount: data.entries.length,
                itemBuilder: (context, index) {
                  final entry = data.entries[index];
                  return RecordRow(
                    key: ValueKey('audit_row_${entry.id}'),
                    title: auditEntryTitle(entry),
                    details: [
                      RecordLine(
                        '${entry.username ?? auditUnknownUser} · '
                        '${auditModuleLabel(entry.module)}',
                        maxLines: 1,
                      ),
                      RecordLine(formatDateTime(entry.createdAt), maxLines: 1),
                    ],
                    onTap: () => showAuditDetail(context, entry),
                  );
                },
              ),
            if (data.hasMore)
              SliverToBoxAdapter(
                child: AppActionButton(
                  label: 'Mostrar más',
                  kind: AppButtonKind.neutral,
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  onPressed: () =>
                      ref.read(auditLimitProvider.notifier).state +=
                          auditPageSize,
                ),
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.s24 + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

void showAuditDetail(BuildContext context, AuditEntry entry) {
  showAppSheet<void>(
    context,
    heightFactor: 0.9,
    builder: (_) => AuditDetailSheet(entry: entry),
  );
}

List<Widget> _valueRows(Map<String, Object?> values) => [
  for (final entry in values.entries)
    if (entry.value is! List && !isHiddenAuditField(entry.key))
      AppValueRow(
        label: auditFieldLabel(entry.key),
        value: entry.value is Map
            ? (entry.value as Map).entries
                  .map(
                    (e) =>
                        '${auditFieldLabel('${e.key}')}: '
                        '${auditValueText('${e.key}', e.value)}',
                  )
                  .join(' · ')
            : auditValueText(entry.key, entry.value),
      ),
];

List<Widget> _valueSections(String header, Map<String, Object?> values) {
  final items = values['items'];
  return [
    AppSection(header: header, children: _valueRows(values)),
    if (items is List)
      for (var i = 0; i < items.length; i++)
        if (items[i] is Map)
          AppSection(
            header: '$header · ${auditFieldLabel('items')} ${i + 1}',
            children: _valueRows(Map<String, Object?>.from(items[i] as Map)),
          ),
  ];
}

String _plain(Object? value) =>
    value is Map || value is List ? jsonEncode(value) : '$value';

class AuditDetailSheet extends StatelessWidget {
  final AuditEntry entry;

  const AuditDetailSheet({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final before = entry.before;
    final after = entry.after;
    final changed = <String>[
      if (before != null && after != null)
        for (final key in {...before.keys, ...after.keys})
          if (!isHiddenAuditField(key) &&
              _plain(before[key]) != _plain(after[key]))
            key,
    ];

    return AppSheetScaffold(
      title: 'Detalle del registro',
      actions: AppActionButton(
        label: 'Cerrar',
        kind: AppButtonKind.neutral,
        onPressed: () => Navigator.pop(context),
      ),
      child: ListView(
        padding: const EdgeInsets.only(
          top: AppSpacing.s8,
          bottom: AppSpacing.s16,
        ),
        children: [
          AppSection(
            header: 'Registro',
            children: [
              AppValueRow(
                label: 'Usuario',
                value: entry.username ?? auditUnknownUser,
              ),
              AppValueRow(
                label: 'Módulo',
                value: auditModuleLabel(entry.module),
              ),
              AppValueRow(
                label: 'Acción',
                value: auditActionLabel(entry.action),
              ),
              AppValueRow(
                label: 'Entidad',
                value: auditEntityLabel(entry.entity),
              ),
              AppValueRow(label: 'Registro', value: entry.recordLabel ?? '—'),
              AppValueRow(
                label: 'Fecha y hora',
                value: formatDateTime(entry.createdAt),
              ),
            ],
          ),
          if (changed.isNotEmpty)
            AppSection(
              header: 'Cambios',
              children: [
                for (final key in changed)
                  AppValueRow(
                    label: auditFieldLabel(key),
                    value: before![key] is List || after![key] is List
                        ? 'Modificado'
                        : '${auditValueText(key, before[key])} → '
                              '${auditValueText(key, after[key])}',
                  ),
              ],
            ),
          if (before != null) ..._valueSections('Valores anteriores', before),
          if (after != null) ..._valueSections('Valores posteriores', after),
        ],
      ),
    );
  }
}
