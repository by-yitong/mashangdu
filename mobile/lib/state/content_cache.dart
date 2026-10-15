import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 内容缓存：每个接口的 data JSON 按“接口路径”为 key 写入
/// shared_preferences，网络失败时回退读取。
class ContentCache {
  ContentCache(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String path) => 'cache$path';

  Future<void> put(String path, Object? data) async {
    await _prefs.setString(_key(path), jsonEncode(data));
  }

  /// 无缓存或数据损坏时返回 null。
  Object? get(String path) {
    final raw = _prefs.getString(_key(path));
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  bool has(String path) => _prefs.getString(_key(path))?.isNotEmpty ?? false;
}
