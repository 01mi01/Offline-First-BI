import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/user_repository.dart';
import '../models/app_role.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'user_validation.dart';

const String adminOnlyMessage =
    'Solo el administrador puede gestionar usuarios';
const String selfBlockMessage = 'No puedes bloquear tu propio usuario';
const String selfRoleMessage = 'No puedes cambiar tu propio rol';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UserRepository(
    db,
    failedAttempts: ref.watch(failedLoginAttemptsProvider),
  );
});

final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).user?.isAdmin ?? false,
);

class UserManagementState {
  final List<UserModel> users;
  final bool isLoading;
  final String? error;

  UserManagementState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  UserManagementState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? error,
  }) {
    return UserManagementState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UserManagementNotifier extends StateNotifier<UserManagementState> {
  final UserRepository repository;
  final UserModel? Function() currentUser;
  final Future<void> Function() onCurrentUserChanged;

  UserManagementNotifier(
    this.repository, {
    required this.currentUser,
    required this.onCurrentUserChanged,
  }) : super(UserManagementState()) {
    load();
  }

  bool get _isAdmin => currentUser()?.isAdmin ?? false;

  Future<void> load() async {
    if (!_isAdmin) {
      state = UserManagementState(error: adminOnlyMessage);
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final users = await repository.getAll();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<String?> _run(Future<void> Function() action) async {
    if (!_isAdmin) return adminOnlyMessage;
    try {
      await action();
      await load();
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<String?> create({
    required String username,
    required String email,
    required String password,
    required AppRole role,
  }) {
    final error =
        validateUsername(username) ??
        validateEmail(email) ??
        validatePassword(password);
    if (error != null) return Future.value(error);
    return _run(
      () => repository.create(
        username: username,
        email: email,
        password: password,
        role: role,
      ),
    );
  }

  Future<String?> update({
    required int id,
    required String username,
    required String email,
    required AppRole role,
  }) async {
    final error = validateUsername(username) ?? validateEmail(email);
    if (error != null) return error;
    final self = currentUser()?.id == id;
    if (self && currentUser()?.appRole != role) return selfRoleMessage;
    final result = await _run(
      () => repository.update(
        id: id,
        username: username,
        email: email,
        role: role,
      ),
    );
    if (result == null && self) await onCurrentUserChanged();
    return result;
  }

  Future<String?> setBlocked(int id, bool blocked) {
    if (blocked && currentUser()?.id == id) {
      return Future.value(selfBlockMessage);
    }
    return _run(() => repository.setBlocked(id, blocked));
  }

  Future<String?> resetPassword(int id, String newPassword) {
    final error = validatePassword(newPassword);
    if (error != null) return Future.value(error);
    return _run(() => repository.resetPassword(id, newPassword));
  }
}

final userManagementProvider =
    StateNotifierProvider.autoDispose<
      UserManagementNotifier,
      UserManagementState
    >((ref) {
      final repository = ref.watch(userRepositoryProvider);
      return UserManagementNotifier(
        repository,
        currentUser: () => ref.read(authProvider).user,
        onCurrentUserChanged: () =>
            ref.read(authProvider.notifier).refreshUser(),
      );
    });
