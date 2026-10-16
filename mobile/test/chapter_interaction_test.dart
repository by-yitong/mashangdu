import 'dart:async';
import 'dart:convert';

import 'package:code_tutorials/state/api_client.dart';
import 'package:code_tutorials/state/auth_store.dart';
import 'package:code_tutorials/widgets/chapter_interaction.dart';
import 'package:code_tutorials/widgets/reading_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _envelope(Object? data, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode({'code': 'OK', 'message': 'ok', 'data': data})),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object> _commentJson(
  int id,
  String username,
  String content, {
  int userId = 7,
}) => {
  'id': id,
  'userId': userId,
  'username': username,
  'avatar': '',
  'content': content,
  'createdAt': '2026-10-16T09:00:00Z',
};

void main() {
  /// 组装被测件：登录态（userId=7）+ Mock ApiClient + 互动区。
  Widget harness(ApiClient api, AuthStore auth) => MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthStore>.value(value: auth),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ListView(
          children: const [
            Padding(
              padding: EdgeInsets.all(16),
              child: ChapterInteraction(
                courseSlug: 'go-basics',
                chapterSlug: 'hello-world',
                theme: ReadingTheme.paper,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('点赞：乐观置灰翻转 + 服务端确认计数；发送评论插入头部并 total+1；删除自己的评论本地移除', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.token': 'test-token',
      'auth.user': '{"id":7,"username":"me","avatar":"","createdAt":"2026-01-01T00:00:00Z"}',
    });
    final prefs = await SharedPreferences.getInstance();

    var likeCalls = 0;
    var commentPosted = 0;
    var commentDeleted = 0;
    var nextCommentId = 100;
    final api = ApiClient(
      'http://test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/view')) {
          return _envelope({'viewCount': 13});
        }
        if (path.endsWith('/stats')) {
          return _envelope({
            'viewCount': 12,
            'likeCount': 3,
            'commentCount': 2,
            'liked': false,
          });
        }
        if (path.endsWith('/like')) {
          likeCalls++;
          return _envelope({'liked': true, 'likeCount': 4});
        }
        if (path.endsWith('/comments') && request.method == 'POST') {
          commentPosted++;
          return _envelope({
            'comment': _commentJson(nextCommentId++, 'me', '第一条新评论'),
          }, status: 201);
        }
        if (path.startsWith('/api/v1/comments/')) {
          commentDeleted++;
          return _envelope({'deleted': 1});
        }
        return _envelope({
          'comments': [
            _commentJson(2, '张三', '其他人写的', userId: 8),
            _commentJson(1, 'me', '我自己的旧评论'),
          ],
          'total': 2,
          'page': 1,
          'pageSize': 20,
          'pageCount': 1,
        });
      }),
    );
    final auth = AuthStore(prefs, api)..load();

    await tester.pumpWidget(harness(api, auth));
    await tester.pumpAndSettle();

    // 初始：数据行 + 未点赞描边态 + 评论区标题带 total。
    expect(find.text('阅读 12 次 · 3 人觉得有用 · 2 条评论'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_outline_rounded), findsOneWidget);
    expect(find.text('评论 (2)'), findsOneWidget);
    expect(find.text('我自己的旧评论'), findsOneWidget);

    // —— 点赞：乐观更新（立即变实心、计数+1），服务端确认后保持 4 ——
    await tester.tap(find.byIcon(Icons.favorite_outline_rounded));
    await tester.pump(); // 乐观 setState 先生效
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget,
        reason: '点赞后应立即翻转成实心（乐观更新）');
    expect(find.text('阅读 12 次 · 4 人觉得有用 · 2 条评论'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(likeCalls, 1);
    expect(find.text('阅读 12 次 · 4 人觉得有用 · 2 条评论'), findsOneWidget,
        reason: '服务端确认 likeCount=4，与乐观值一致');

    // —— 发评论：插入头部、total+1、输入清空 ——
    await tester.enterText(find.byType(TextField), '第一条新评论');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(commentPosted, 1);
    expect(find.text('第一条新评论'), findsOneWidget);
    // 头部插入：新评论应在“其他人写的”之前。
    expect(
      tester.getTopLeft(find.text('第一条新评论')).dy,
      lessThan(tester.getTopLeft(find.text('其他人写的')).dy),
      reason: '新评论应插到列表头部',
    );
    expect(find.text('评论 (3)'), findsOneWidget, reason: 'total 应 +1');
    expect(find.widgetWithText(TextField, '第一条新评论'), findsNothing,
        reason: '发送成功后输入框应清空');

    // —— 删除自己的评论：确认后本地移除、total-1 ——
    // 新评论（mine）+ 旧评论（mine）两条带删除入口，删“我自己的旧评论”。
    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2),
        reason: '自己的评论（新发的 + 旧的）各带删除入口，别人的没有');
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('删除评论'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(commentDeleted, 1);
    expect(find.text('我自己的旧评论'), findsNothing, reason: '删除后本地移除');
    expect(find.text('其他人写的'), findsOneWidget, reason: '别人的评论不受影响');
    expect(find.text('第一条新评论'), findsOneWidget, reason: '其余自己的评论不受影响');
    expect(find.text('评论 (2)'), findsOneWidget, reason: 'total 应 -1');
  });

  testWidgets('点赞失败回滚到原状态', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.token': 'test-token',
      'auth.user': '{"id":7,"username":"me","avatar":"","createdAt":"2026-01-01T00:00:00Z"}',
    });
    final prefs = await SharedPreferences.getInstance();

    // /like 挡在 Completer 后面：先观察到乐观态，再放行 500 看回滚。
    final likeGate = Completer<http.Response>();
    final api = ApiClient(
      'http://test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/like')) {
          return likeGate.future;
        }
        if (path.endsWith('/stats')) {
          return _envelope({
            'viewCount': 1,
            'likeCount': 5,
            'commentCount': 0,
            'liked': false,
          });
        }
        return _envelope({
          'comments': const [],
          'total': 0,
          'page': 1,
          'pageSize': 20,
          'pageCount': 1,
        });
      }),
    );
    final auth = AuthStore(prefs, api)..load();

    await tester.pumpWidget(harness(api, auth));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_outline_rounded));
    await tester.pump(); // 乐观态（请求还挂在 likeGate 上）
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget,
        reason: '请求未返回前应先看到乐观点赞态');
    expect(find.text('阅读 1 次 · 6 人觉得有用 · 0 条评论'), findsOneWidget);

    // 放行失败响应：回滚。
    likeGate.complete(
      http.Response.bytes(
        utf8.encode(
          jsonEncode({'code': 'INTERNAL', 'message': '服务器开小差了', 'data': null}),
        ),
        500,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_outline_rounded), findsOneWidget,
        reason: '失败后应回滚到未点赞');
    expect(find.text('阅读 1 次 · 5 人觉得有用 · 0 条评论'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsOneWidget, reason: '失败应有提示');
  });

  testWidgets('未登录：显示登录引导卡，无输入框', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(
      'http://test',
      client: MockClient(
        (request) async => _envelope({
          'viewCount': 0,
          'likeCount': 0,
          'commentCount': 0,
          'liked': false,
        }),
      ),
    );
    final auth = AuthStore(prefs, api)..load();

    await tester.pumpWidget(harness(api, auth));
    await tester.pumpAndSettle();

    expect(find.text('登录后参与评论'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('还没有评论，点击下方输入框抢沙发'), findsOneWidget);
  });
}
