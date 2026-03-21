import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/auth_repository.dart';
import '../models/user_model.dart';
import 'database_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AuthRepository(db);
});

// Estado de autenticación
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository repository;

  AuthNotifier(this.repository) : super(AuthState(isLoading: true)) {
    _checkSession();
  }

  // Verifica si hay una sesión activa al iniciar la app
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
    if (user != null) {
      state = state.copyWith(user: user, isLoading: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        error: 'Usuario o contraseña incorrectos',
      );
    }
  }

  Future<void> logout() async {
    await repository.logout();
    state = AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});