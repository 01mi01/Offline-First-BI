import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const String themeChoiceFileName = 'theme_choices.json';

enum ThemeChoice { light, dark }

class ThemeChoiceStore {
  final Future<Directory> Function() _directory;
  final Map<int, ThemeChoice> _choices = {};

  ThemeChoiceStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  ThemeChoice? choiceOf(int userId) => _choices[userId];

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return;
      _choices.clear();
      data.forEach((key, value) {
        final id = int.tryParse('$key');
        final choice = ThemeChoice.values
            .where((c) => c.name == value)
            .firstOrNull;
        if (id != null && choice != null) _choices[id] = choice;
      });
    } catch (_) {}
  }

  Future<void> save(int userId, ThemeChoice? choice) async {
    if (choice == null) {
      _choices.remove(userId);
    } else {
      _choices[userId] = choice;
    }
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({
          for (final entry in _choices.entries)
            '${entry.key}': entry.value.name,
        }),
      );
    } catch (_) {}
  }

  Future<File> _file() async => File(
    '${(await _directory()).path}${Platform.pathSeparator}$themeChoiceFileName',
  );
}
