import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/theme_choice_store.dart';
import '../data/repositories/theme_preference_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final themePreferenceRepositoryProvider = Provider<ThemePreferenceRepository>(
  (ref) => ThemePreferenceRepository(ref.watch(databaseProvider)),
);

final themeChoiceStoreProvider = Provider<ThemeChoiceStore>(
  (ref) => ThemeChoiceStore(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final ThemePreferenceRepository repository;
  final ThemeChoiceStore store;
  final int? userId;

  ThemeModeNotifier(
    this.repository,
    this.store, {
    this.userId,
    bool darkMode = false,
  }) : super(resolve(store, userId: userId, darkMode: darkMode));

  static ThemeMode resolve(
    ThemeChoiceStore store, {
    int? userId,
    bool darkMode = false,
  }) {
    if (userId == null) return ThemeMode.system;
    return switch (store.choiceOf(userId)) {
      ThemeChoice.light => ThemeMode.light,
      ThemeChoice.dark => ThemeMode.dark,
      null => darkMode ? ThemeMode.dark : ThemeMode.system,
    };
  }

  bool get isDark => state == ThemeMode.dark;

  Future<void> setMode(ThemeMode mode) async {
    final id = userId;
    if (id == null) return;
    final previous = state;
    state = mode;
    final saved = store.save(id, switch (mode) {
      ThemeMode.light => ThemeChoice.light,
      ThemeMode.dark => ThemeChoice.dark,
      ThemeMode.system => null,
    });
    await repository.setDarkMode(
      id,
      mode == ThemeMode.dark,
      previousTheme: previous.name,
      theme: mode.name,
    );
    await saved;
  }

  Future<void> setDarkMode(bool dark) =>
      setMode(dark ? ThemeMode.dark : ThemeMode.light);
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final user = ref.watch(
    authProvider.select(
      (s) => s.user == null ? null : (s.user!.id, s.user!.darkMode),
    ),
  );
  return ThemeModeNotifier(
    ref.watch(themePreferenceRepositoryProvider),
    ref.watch(themeChoiceStoreProvider),
    userId: user?.$1,
    darkMode: user?.$2 ?? false,
  );
});
