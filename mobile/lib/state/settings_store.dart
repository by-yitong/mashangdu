import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 服务器地址设置（Base URL 用户可配，默认模拟器宿主机）。
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  /// 默认服务器地址：debug 连局域网部署机联调，release 指向线上域名。
  static String get defaultServerUrl =>
      kDebugMode ? 'http://192.168.31.169:8090' : 'https://studio.phpcurl.cn';
  static const String _serverUrlKey = 'settings.server_url';

  /// `settings.resume_on_launch`：打开 app 时继续上一次阅读（默认开）。
  static const String _resumeOnLaunchKey = 'settings.resume_on_launch';

  String _serverUrl = defaultServerUrl;
  bool _resumeOnLaunch = true;

  String get serverUrl => _serverUrl;

  bool get resumeOnLaunch => _resumeOnLaunch;

  /// 启动时从本地读回已保存的地址与设置项。
  void load() {
    final saved = _prefs.getString(_serverUrlKey);
    if (saved != null && saved.isNotEmpty) _serverUrl = saved;
    _resumeOnLaunch = _prefs.getBool(_resumeOnLaunchKey) ?? true;
  }

  /// 切换「打开时继续上次阅读」。同值直接返回（不重复落盘/通知）。
  Future<void> setResumeOnLaunch(bool value) async {
    if (value == _resumeOnLaunch) return;
    _resumeOnLaunch = value;
    await _prefs.setBool(_resumeOnLaunchKey, value);
    notifyListeners();
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
