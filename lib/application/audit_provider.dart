import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/audit_repository.dart';
import '../models/access_control.dart';
import '../models/app_role.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'date_range_filter.dart';

const String auditRoleOnlyMessage =
    'Solo el administrador y el propietario pueden consultar la auditoría.';

const int auditPageSize = 50;

bool canViewAudit(UserModel? user) =>
    user != null &&
    (user.appRole == AppRole.administrador ||
        user.appRole == AppRole.propietario);

final canViewAuditProvider = Provider<bool>(
  (ref) => canViewAudit(ref.watch(authProvider).user),
);

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(ref.watch(databaseProvider)),
);

final auditUserFilterProvider = StateProvider.autoDispose<int?>((ref) => null);

final auditModuleFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final auditActionFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final auditDateFilterProvider = StateProvider.autoDispose<DateRangeFilter>(
  (ref) => const DateRangeFilter(),
);

final auditQueryProvider = Provider.autoDispose<AuditQuery>((ref) {
  final dates = ref.watch(auditDateFilterProvider);
  final to = dates.effectiveTo;
  return AuditQuery(
    userId: ref.watch(auditUserFilterProvider),
    module: ref.watch(auditModuleFilterProvider),
    action: ref.watch(auditActionFilterProvider),
    from: dates.from == null ? null : dateOnly(dates.from!),
    to: to == null ? null : dateOnly(to).add(const Duration(days: 1)),
  );
});

final auditLimitProvider = StateProvider.autoDispose<int>((ref) {
  ref.watch(auditQueryProvider);
  return auditPageSize;
});

class AuditResultPage {
  final List<AuditEntry> entries;
  final bool hasMore;

  const AuditResultPage(this.entries, {required this.hasMore});
}

final auditEntriesProvider = FutureProvider.autoDispose<AuditResultPage>((ref) async {
  if (!ref.watch(canViewAuditProvider)) throw const AccessDeniedException();
  final query = ref.watch(auditQueryProvider);
  final limit = ref.watch(auditLimitProvider);
  final rows = await ref
      .watch(auditRepositoryProvider)
      .query(query, limit: limit + 1);
  return AuditResultPage(rows.take(limit).toList(), hasMore: rows.length > limit);
});

final auditUsersProvider = FutureProvider.autoDispose<List<AuditUser>>((
  ref,
) async {
  if (!ref.watch(canViewAuditProvider)) return const [];
  return ref.watch(auditRepositoryProvider).users();
});
