import 'dart:convert';

import 'package:code_tutorials/pages/history_page.dart';
import 'package:code_tutorials/state/api_client.dart';
import 'package:code_tutorials/state/auth_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回归：登录态打开观看历史页，必须自动发出 GET /api/v1/records 并
/// 渲染结果——曾经 _loading 初始为 true 导致请求发不出去、转圈死锁。
void main() {
  testWidgets('登录态进入历史页自动请求并渲染记录', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.token': 'test-token',
      'auth.user': '{"id":1,"username":"u","createdAt":"2026-01-01T00:00:00Z"}',
    });
    final prefs = await SharedPreferences.getInstance();

    var requested = 0;
    final stacks = <StackTrace>[];
    Uri? lastUri;
    String? lastAuth;
    final api = ApiClient(
      'http://127.0.0.1:1',
      client: MockClient((request) async {
        requested++;
        stacks.add(StackTrace.current);
        lastUri = request.url;
        lastAuth = request.headers['authorization'];
        // MockClient 的 String 构造按 latin1 编码，中文会抛
        // "Contains invalid characters"——必须走 UTF-8 字节。
        return http.Response.bytes(
          utf8.encode(
            '{"code":"OK","message":"ok","data":{"records":['
            '{"courseSlug":"go-basics","courseTitle":"Go 语言入门",'
            '"chapterSlug":"hello-world","chapterTitle":"Hello World",'
            '"readAt":"2026-10-16T10:00:00Z"}]}}',
          ),
          200,
        );
      }),
    );
    final auth = AuthStore(prefs, api)..load();
    expect(auth.isLoggedIn, isTrue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthStore>.value(value: auth),
          Provider<ApiClient>.value(value: api),
        ],
        child: const MaterialApp(home: HistoryPage()),
      ),
    );
    await tester.pump(); // 首帧回调发起 _load
    await tester.pump(const Duration(milliseconds: 100));

    debugPrint('最终 requested=$requested');
    for (final e in tester.allElements) {
      final w = e.widget;
      if (w is Text) debugPrint('TEXT: ${w.data}');
    }
    expect(
      requested,
      1,
      reason: '进入页面应自动请求一次 records，实际 $requested 次。调用栈：\n'
          '${stacks.join('\n================\n')}',
    );
    expect(lastUri!.path, '/api/v1/records');
    expect(lastAuth, 'Bearer test-token');
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: '请求完成后不应停留在转圈');
    expect(find.text('Hello World'), findsOneWidget);
  });
}
