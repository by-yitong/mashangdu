import 'dart:convert';

import 'package:code_tutorials/models/models.dart';
import 'package:code_tutorials/state/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 新增 API（头像上传 / 阅读量 / 点赞 / 评论）的请求与解析回归。
///
/// MockClient 的 String 构造按 latin1 编码，中文会抛
/// "Contains invalid characters"——必须走 UTF-8 字节。
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

const _userData = {
  'id': 7,
  'username': '码上读用户',
  'avatar': '/avatars/2026/10/abc.jpg',
  'createdAt': '2026-10-01T08:00:00Z',
};

void main() {
  test('uploadAvatar：POST /api/v1/me/avatar，multipart 字段 file + Bearer，解析 user', () async {
    // MockClient 会把 MultipartRequest 重组为普通 Request（multipart 字段
    // 结构无法用 is 判断），改从 content-type 与原始 body 验证。
    String? method;
    Uri? uri;
    String? auth;
    String? contentType;
    String? body;
    final api = ApiClient(
      'http://test',
      client: MockClient((http.BaseRequest baseRequest) async {
        method = baseRequest.method;
        uri = baseRequest.url;
        auth = baseRequest.headers['Authorization'];
        final plain = baseRequest;
        if (plain is http.Request) {
          contentType = plain.headers['content-type'];
          body = plain.body;
        }
        return _envelope({
          'user': _userData,
        });
      }),
    )..setToken('tok123');

    final user = await api.uploadAvatar(
      utf8.encode('fake-jpeg-bytes'),
      'avatar.jpg',
    );

    expect(method, 'POST');
    expect(uri!.path, '/api/v1/me/avatar');
    expect(auth, 'Bearer tok123');
    expect(contentType, startsWith('multipart/form-data; boundary='));
    expect(body, contains('name="file"'), reason: 'multipart 字段名必须是 file');
    expect(body, contains('filename="avatar.jpg"'));
    expect(body, contains('fake-jpeg-bytes'));
    expect(user.id, 7);
    expect(user.username, '码上读用户');
    expect(user.avatar, '/avatars/2026/10/abc.jpg');
  });

  test('uploadAvatar：400 AVATAR_INVALID 抛 ApiException', () async {
    final api = ApiClient(
      'http://test',
      client: MockClient(
        (request) async => _envelope(
          null,
          code: 'AVATAR_INVALID',
          status: 400,
          message: '图片格式或大小不符合要求',
        ),
      ),
    )..setToken('tok123');

    await expectLater(
      api.uploadAvatar(utf8.encode('x'), 'avatar.jpg'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'AVATAR_INVALID'),
      ),
    );
  });

  test('recordView：POST view 路径、未登录不带认证头、异常吞掉不抛', () async {
    Uri? uri;
    String? method;
    String? auth;
    var failNext = false;
    final api = ApiClient(
      'http://test',
      client: MockClient((request) async {
        if (failNext) {
          throw Exception('网络断开');
        }
        uri = request.url;
        method = request.method;
        auth = request.headers['Authorization'];
        return _envelope({
          'viewCount': 3,
        });
      }),
    );

    await api.recordView('go-basics', 'hello-world');
    expect(method, 'POST');
    expect(uri!.path, '/api/v1/courses/go-basics/chapters/hello-world/view');
    expect(auth, isNull, reason: 'view 上报无需登录，未登录不带 Bearer');

    // 网络异常也必须静默完成（fire-and-forget）。
    failNext = true;
    await api.recordView('go-basics', 'hello-world');
  });

  test('fetchChapterStats：解析 camelCase 字段', () async {
    final api = ApiClient(
      'http://test',
      client: MockClient(
        (request) async => _envelope({
          'viewCount': 12,
          'likeCount': 3,
          'commentCount': 5,
          'liked': true,
        }),
      ),
    );
    final stats = await api.fetchChapterStats('go-basics', 'hello-world');
    expect(stats.viewCount, 12);
    expect(stats.likeCount, 3);
    expect(stats.commentCount, 5);
    expect(stats.liked, isTrue);
  });

  test('setLike(true)：POST like 并解析；setLike(false)：DELETE like', () async {
    String? method;
    Uri? uri;
    String? auth;
    final requests = <String>[];
    final api = ApiClient(
      'http://test',
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        method = request.method;
        uri = request.url;
        auth = request.headers['Authorization'];
        return _envelope({
          'liked': request.method == 'POST',
          'likeCount': request.method == 'POST' ? 4 : 3,
        });
      }),
    )..setToken('tok123');

    final liked = await api.setLike('go-basics', 'hello-world', true);
    expect(method, 'POST');
    expect(uri!.path, '/api/v1/courses/go-basics/chapters/hello-world/like');
    expect(auth, 'Bearer tok123');
    expect(liked.liked, isTrue);
    expect(liked.likeCount, 4);

    final unliked = await api.setLike('go-basics', 'hello-world', false);
    expect(unliked.liked, isFalse);
    expect(unliked.likeCount, 3);
    expect(requests, [
      'POST /api/v1/courses/go-basics/chapters/hello-world/like',
      'DELETE /api/v1/courses/go-basics/chapters/hello-world/like',
    ]);
  });

  test('fetchComments：带分页参数并解析分页信封（最新在前）', () async {
    Uri? uri;
    final api = ApiClient(
      'http://test',
      client: MockClient((request) async {
        uri = request.url;
        return _envelope({
          'comments': [
            {
              'id': 2,
              'userId': 8,
              'username': '张三',
              'avatar': '/avatars/z3.jpg',
              'content': '写得真好，图解很清楚！',
              'createdAt': '2026-10-16T09:00:00Z',
            },
            {
              'id': 1,
              'userId': 7,
              'username': '李四',
              'avatar': '',
              'content': '沙发',
              'createdAt': '2026-10-15T09:00:00Z',
            },
          ],
          'total': 25,
          'page': 2,
          'pageSize': 20,
          'pageCount': 2,
        });
      }),
    );

    final page = await api.fetchComments(
      'go-basics',
      'hello-world',
      page: 2,
      pageSize: 20,
    );

    expect(uri!.path, '/api/v1/courses/go-basics/chapters/hello-world/comments');
    expect(uri!.queryParameters['page'], '2');
    expect(uri!.queryParameters['pageSize'], '20');
    expect(page.total, 25);
    expect(page.page, 2);
    expect(page.pageCount, 2);
    expect(page.comments.length, 2);
    expect(page.comments.first.id, 2);
    expect(page.comments.first.username, '张三');
    expect(page.comments.first.content, '写得真好，图解很清楚！');
    expect(page.comments.first.createdAt, DateTime.parse('2026-10-16T09:00:00Z'));
    expect(page.comments.last.avatar, '');
  });

  test('addComment：POST JSON {content}，201 解析单条评论', () async {
    String? method;
    Uri? uri;
    String? auth;
    String? body;
    final api = ApiClient(
      'http://test',
      client: MockClient((request) async {
        method = request.method;
        uri = request.url;
        auth = request.headers['Authorization'];
        body = request.body;
        return _envelope(
          {
            'comment': {
              'id': 26,
              'userId': 7,
              'username': '码上读用户',
              'avatar': '/avatars/me.jpg',
              'content': '新评论',
              'createdAt': '2026-10-16T10:30:00Z',
            },
          },
          status: 201,
        );
      }),
    )..setToken('tok123');

    final comment = await api.addComment('go-basics', 'hello-world', '新评论');

    expect(method, 'POST');
    expect(uri!.path, '/api/v1/courses/go-basics/chapters/hello-world/comments');
    expect(auth, 'Bearer tok123');
    expect(jsonDecode(body!), {'content': '新评论'});
    expect(comment.id, 26);
    expect(comment.content, '新评论');
  });

  test('addComment：429 COMMENT_TOO_FAST 抛 ApiException', () async {
    final api = ApiClient(
      'http://test',
      client: MockClient(
        (request) async => _envelope(
          null,
          code: 'COMMENT_TOO_FAST',
          status: 429,
          message: '评论太快啦',
        ),
      ),
    )..setToken('tok123');

    await expectLater(
      api.addComment('go-basics', 'hello-world', '又一条'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'COMMENT_TOO_FAST'),
      ),
    );
  });

  test('deleteComment：DELETE /api/v1/comments/{id}', () async {
    String? method;
    Uri? uri;
    final api = ApiClient(
      'http://test',
      client: MockClient(
        (request) async {
          method = request.method;
          uri = request.url;
          return _envelope({'deleted': 1});
        },
      ),
    )..setToken('tok123');

    await api.deleteComment(9);

    expect(method, 'DELETE');
    expect(uri!.path, '/api/v1/comments/9');
  });

  test('AuthUser：avatar 字段 fromJson/toJson 往返，缺省为空串', () {
    final user = AuthUser.fromJson(_userData);
    expect(user.avatar, '/avatars/2026/10/abc.jpg');
    final json = user.toJson();
    expect(json['avatar'], '/avatars/2026/10/abc.jpg');
    expect(AuthUser.fromJson(json).avatar, user.avatar);

    final legacy = AuthUser.fromJson({
      'id': 1,
      'username': '旧数据',
      'createdAt': '2026-01-01T00:00:00Z',
    });
    expect(legacy.avatar, '');
  });

  test('CommentPage/ChapterComment：防御式列表解析跳过脏元素', () {
    final page = CommentPage.fromJson({
      'comments': [
        {
          'id': 1,
          'userId': 7,
          'username': 'a',
          'avatar': '',
          'content': 'ok',
          'createdAt': '2026-10-16T09:00:00Z',
        },
        '不是 map 的脏元素',
        null,
      ],
      'total': 1,
      'page': 1,
      'pageSize': 20,
      'pageCount': 1,
    });
    expect(page.comments.length, 1);
    expect(page.comments.single.username, 'a');
  });
}
