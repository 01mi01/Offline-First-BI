import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/failed_login_attempts.dart';
import '../models/user_model.dart';
import 'database_provider.dart';

const String blockedUserMessage =
    'Tu usuario está bloqueado. Comunícate con el administrador.';

const String inactivityLogoutMessage = 'Tu sesión se cerró por inactividad.';

const String dataUnavailableMessage =
    'No se pudo abrir la información guardada en este dispositivo.';

const String wrongCodeMessage = 'El código de verificación es incorrecto.';

final failedLoginAttemptsProvider = Provider<FailedLoginAttempts>(
  (ref) => FailedLoginAttempts(),
);

final failedCodeAttemptsProvider = Provider<FailedLoginAttempts>(
  (ref) => FailedLoginAttempts(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AuthRepository(
    db,
    failedAttempts: ref.watch(failedLoginAttemptsProvider),
    failedCodeAttempts: ref.watch(failedCodeAttemptsProvider),
  );
});

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final TwoFactorChallenge? twoFactor;

  AuthState({this.user, this.isLoading = false, this.error, this.twoFactor});

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      twoFactor: twoFactor,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository repository;

  AuthNotifier(this.repository) : super(AuthState(isLoading: true)) {
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final user = await repository.getSesionActual();
      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false);
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final user = await repository.login(username, password);
    final challenge = user == null
        ? repository.takeTwoFactorChallenge(username)
        : null;
    if (user != null) {
      state = state.copyWith(user: user, isLoading: false);
    } else if (challenge != null) {
      state = AuthState(twoFactor: challenge);
    } else {
      try {
        final blocked =
            repository.takeJustLocked(username) ||
            await repository.isBlocked(username, password);
        state = state.copyWith(
          isLoading: false,
          error: blocked
              ? blockedUserMessage
              : 'Usuario o contraseña incorrectos',
        );
      } catch (_) {
        state = state.copyWith(isLoading: false, error: dataUnavailableMessage);
      }
    }
  }

  Future<void> verifyCode(String code) async {
    final challenge = state.twoFactor;
    if (challenge == null) return;
    state = state.copyWith(isLoading: true, error: null);
    final user = await repository.verifyCode(challenge.userId, code);
    if (user != null) {
      state = AuthState(user: user);
    } else if (repository.takeJustLocked(challenge.username)) {
      state = AuthState(error: blockedUserMessage);
    } else {
      state = AuthState(twoFactor: challenge, error: wrongCodeMessage);
    }
  }

  void cancelTwoFactor() {
    state = AuthState();
  }

  Future<void> refreshUser() async {
    if (state.user == null) return;
    final user = await repository.getSesionActual();
    if (user != null) state = state.copyWith(user: user);
  }

  void clearError() {
    if (state.error != null) state = state.copyWith();
  }

  Future<void> logout() async {
    await repository.logout();
    state = AuthState();
  }

  Future<void> logoutForInactivity() async {
    if (state.user == null) return;
    await repository.logout();
    state = AuthState(error: inactivityLogoutMessage);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});