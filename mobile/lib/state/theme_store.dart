import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 外观模式（跟随系统/浅色/深色），持久化到本地。
class ThemeStore extends ChangeNotifier {
  ThemeStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'settings.theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void load() {
    final saved = _prefs.getString(_key);
    if (saved == null) return;
    for (final value in ThemeMode.values) {
      if (value.name == saved) _mode = value;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    await _prefs.setString(_key, mode.name);
    notifyListeners();
  }
}
