import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 服务器地址设置（Base URL 用户可配，默认模拟器宿主机）。
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  /// 默认服务器地址：debug 构建直连局域网部署机；release 指向线上域名。
  static String get defaultServerUrl =>
      kReleaseMode ? 'https://study.phpcurl.cn' : 'http://192.168.31.169:8090';
  static const String _serverUrlKey = 'settings.server_url';

  String _serverUrl = defaultServerUrl;

  String get serverUrl => _serverUrl;

  /// 启动时从本地读回已保存的地址。
  void load() {
    final saved = _prefs.getString(_serverUrlKey);
    if (saved != null && saved.isNotEmpty) _serverUrl = saved;
  }

  /// 校验 + 保存。返回 false 表示格式不合法（必须以 http:// 或 https:// 开头）。
  Future<bool> setServerUrl(String url) async {
    final trimmed = url.trim();
    if (!_isValidUrl(trimmed)) return false;
    final normalized = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    if (normalized == _serverUrl) return true;
    _serverUrl = normalized;
    await _prefs.setString(_serverUrlKey, normalized);
    notifyListeners();
    return true;
  }

  static bool _isValidUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');
}
