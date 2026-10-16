import 'dart:convert';

import 'package:code_tutorials/state/api_client.dart';
import 'package:code_tutorials/state/auth_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _envelope(
  Object? data, {
  String code = 'OK',
  int status = 200,
  String message = 'ok',
}) => http.Response.bytes(
  utf8.encode(jsonEncode({'code': code, 'message': message, 'data': data})),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _sessionData = {
  'token': 'tok123',
  'user': {
    'id': 7,
    'username': 'alice',
    'createdAt': '2026-10-01T08:00:00Z',
  },
};

void main() {
  test('login 成功：保存会话、同步 Bearer Token 并持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    String? capturedAuthHeader;
    final api = ApiClient(
      'http://test',
      client: MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        if (request.url.path == '/api/v1/auth/me') {
          return _envelope({
            'user': _sessionData['user'],
          });
        }
        return _envelope(_sessionData);
      }),
    );
    final auth = AuthStore(prefs, api);

    await auth.login('alice', 'secret123');

    expect(auth.isLoggedIn, isTrue);
    expect(auth.token, 'tok123');
    expect(auth.user?.id, 7);
    expect(auth.user?.username, 'alice');
    expect(api.bearerToken, 'tok123');
    expect(prefs.getString('auth.token'), 'tok123');

    // 登录后的后续请求自动带 Bearer 头。
    await api.fetchMe();
    expect(capturedAuthHeader, 'Bearer tok123');
  });

  test('register 409 AUTH_USERNAME_TAKEN：抛 ApiException 且不落登录态', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(
      'http://test',
      client: MockClient(
        (request) async => _envelope(
          null,
          code: 'AUTH_USERNAME_TAKEN',
          status: 409,
          message: '用户名已存在',
        ),
      ),
    );
    final auth = AuthStore(prefs, api);

    await expectLater(
      auth.register('alice', 'secret123'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'AUTH_USERNAME_TAKEN'),
      ),
    );
    expect(auth.isLoggedIn, isFalse);
    expect(prefs.getString('auth.token'), isNull);
  });

  test('logout：清空内存态、prefs 与 ApiClient Token', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(
      'http://test',
      client: MockClient((request) async => _envelope(_sessionData)),
    );
    final auth = AuthStore(prefs, api);
    await auth.login('alice', 'secret123');
    expect(auth.isLoggedIn, isTrue);

    await auth.logout();

    expect(auth.isLoggedIn, isFalse);
    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(api.bearerToken, isNull);
    expect(prefs.getString('auth.token'), isNull);
    expect(prefs.getString('auth.user'), isNull);
  });

  test('load：从持久化恢复会话并恢复 Bearer Token', () async {
    SharedPreferences.setMockInitialValues({
      'auth.token': 'saved-token',
      'auth.user': jsonEncode({
        'id': 9,
        'username': 'bob',
        'createdAt': '2026-10-02T09:30:00Z',
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(
      'http://test',
      client: MockClient((request) async => _envelope(null)),
    );
    final auth = AuthStore(prefs, api)..load();

    expect(auth.isLoggedIn, isTrue);
    expect(auth.token, 'saved-token');
    expect(auth.user?.username, 'bob');
    expect(api.bearerToken, 'saved-token');
  });

  test('401 AUTH_UNAUTHORIZED：触发 onUnauthorized 回调并抛 ApiException', () async {
    var unauthorizedCount = 0;
    final api = ApiClient(
      'http://test',
      client: MockClient(
        (request) async => _envelope(
          null,
          code: 'AUTH_UNAUTHORIZED',
          status: 401,
          message: '未登录或登录已失效',
        ),
      ),
    );
    api.onUnauthorized = () => unauthorizedCount++;
    api.setToken('expired-token');

    await expectLater(
      api.fetchMe(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'AUTH_UNAUTHORIZED'),
      ),
    );
    expect(unauthorizedCount, 1);
  });
}
