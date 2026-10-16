import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_client.dart';

/// 账号状态：token + 用户信息，持久化到 SharedPreferences。
///
/// - login/register 成功 → 保存会话并同步 ApiClient 的 Bearer Token；
/// - logout / 401 失效 → 清空本地与 ApiClient；
/// - [load]：启动时从本地恢复（prefs 读是同步的，main 里 runApp 前调用）。
class AuthStore extends ChangeNotifier {
  AuthStore(this._prefs, this._api);

  final SharedPreferences _prefs;
  final ApiClient _api;

  static const String _tokenKey = 'auth.token';
  static const String _userKey = 'auth.user';

  String? _token;
  AuthUser? _user;

  String? get token => _token;
  AuthUser? get user => _user;

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// 启动时从本地读回会话，并恢复 ApiClient 的 Bearer Token。
  void load() {
    _token = _prefs.getString(_tokenKey);
    final userJson = _prefs.getString(_userKey);
    if (userJson != null) {
      try {
        _user = AuthUser.fromJson(
          (jsonDecode(userJson) as Map).cast<String, dynamic>(),
        );
      } on FormatException {
        _user = null;
      }
    }
    _api.setToken(_token);
  }

  Future<void> login(String username, String password) async {
    final session = await _api.login(username, password);
    await _applySession(session);
  }

  Future<void> register(String username, String password) async {
    final session = await _api.register(username, password);
    await _applySession(session);
  }

  Future<void> _applySession(AuthSession session) async {
    _token = session.token;
    _user = session.user;
    _api.setToken(session.token);
    await _prefs.setString(_tokenKey, session.token);
    await _prefs.setString(_userKey, jsonEncode(session.user.toJson()));
    notifyListeners();
  }

  /// 主动退出：清本地会话与 ApiClient Token。
  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  /// 401（AUTH_UNAUTHORIZED）被动失效：只清状态，不额外触发通知 UI 逻辑
  /// 由 ApiClient.onUnauthorized 的 main 层回调负责导航提示。
  Future<void> handleUnauthorized() async {
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    _api.setToken(null);
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
  }

  /// 刷新当前用户信息（GET /auth/me）；未登录时为空操作。
  Future<void> fetchMe() async {
    if (!isLoggedIn) return;
    _user = await _api.fetchMe();
    await _prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  /// 采用服务端返回的最新 user（如头像上传响应）并持久化。
  Future<void> applyUser(AuthUser user) async {
    _user = user;
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
    notifyListeners();
  }
}
