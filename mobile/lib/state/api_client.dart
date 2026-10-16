import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// API 路径集中定义（缓存 key 也按这些路径生成）。
abstract final class ApiPaths {
  static const meta = '/api/v1/meta';
  static const courses = '/api/v1/courses';
  static String courseDetail(String slug) => '/api/v1/courses/$slug';
  static String chapter(String courseSlug, String chapterSlug) =>
      '/api/v1/courses/$courseSlug/chapters/$chapterSlug';

  static const register = '/api/v1/auth/register';
  static const login = '/api/v1/auth/login';
  static const me = '/api/v1/auth/me';
  static const records = '/api/v1/records';
  static String record(String courseSlug, String chapterSlug) =>
      '/api/v1/records/$courseSlug/$chapterSlug';
  static const appLatest = '/api/v1/app/latest';

  // —— 头像与章节互动（对应冻结契约） ——
  static const meAvatar = '/api/v1/me/avatar';
  static String chapterView(String courseSlug, String chapterSlug) =>
      '/api/v1/courses/$courseSlug/chapters/$chapterSlug/view';
  static String chapterStats(String courseSlug, String chapterSlug) =>
      '/api/v1/courses/$courseSlug/chapters/$chapterSlug/stats';
  static String chapterLike(String courseSlug, String chapterSlug) =>
      '/api/v1/courses/$courseSlug/chapters/$chapterSlug/like';
  static String chapterComments(String courseSlug, String chapterSlug) =>
      '/api/v1/courses/$courseSlug/chapters/$chapterSlug/comments';
  static String comment(Object id) => '/api/v1/comments/$id';
}

/// 业务错误：信封 code 非 OK，或 HTTP 状态异常。
class ApiException implements Exception {
  ApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message.isEmpty ? code : '$code: $message';
}

/// Golang 后端 API 客户端。
///
/// 响应信封 `{"code":"OK","message":"ok","data":...}`；
/// code 非 OK（含 404/500 的 NOT_FOUND/INTERNAL）一律抛 [ApiException]，
/// 网络层失败抛 SocketException/TimeoutException 等原始异常，由调用方兜底。
///
/// 认证：[setToken] 注入 Bearer Token（有 token 的请求自动带
/// `Authorization` 头）；收到 401 且 code=AUTH_UNAUTHORIZED 时触发
/// [onUnauthorized] 回调（main 里清登录态并引导重新登录），随后照常抛
/// [ApiException]。
class ApiClient {
  ApiClient(String serverUrl, {http.Client? client, this.onUnauthorized})
    : _serverUrl = serverUrl,
      _client = client ?? http.Client();

  String _serverUrl;
  final http.Client _client;

  /// 401（AUTH_UNAUTHORIZED）回调：本地登录态已失效。
  /// main 在创建 AuthStore 后注入（回调里要清登录态，构造时 AuthStore
  /// 尚未存在，故设为可变字段）。
  void Function()? onUnauthorized;

  /// 当前 Bearer Token；null/空 表示未登录（请求不带认证头）。
  String? bearerToken;

  /// 登录成功 / 退出登录后由 AuthStore 调用。
  void setToken(String? token) =>
      bearerToken = (token == null || token.isEmpty) ? null : token;

  void updateServerUrl(String url) => _serverUrl = url;

  /// 绝对 http/https URL 原样返回；否则视为相对路径（如 markdown 正文里的
  /// `images/xx/yy.png`），拼到当前服务器地址下。
  /// 每次按当前 [_serverUrl] 现拼、不缓存结果，用户改设置后自然跟随；
  /// base 尾斜杠与入参前导斜杠的四种组合均归一处理。
  String resolve(String pathOrUrl) {
    final uri = Uri.tryParse(pathOrUrl);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return pathOrUrl;
    }
    final base = _serverUrl.endsWith('/')
        ? _serverUrl.substring(0, _serverUrl.length - 1)
        : _serverUrl;
    final path = pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
    return '$base$path';
  }

  // 局域网/正常公网 4 秒足够；服务器失联时尽快回退缓存，别让每步操作都卡满超时。
  static const Duration _timeout = Duration(seconds: 4);

  Future<Object?> get(String path) => _send('GET', path);

  Future<Object?> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<Object?> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<Object?> delete(String path) => _send('DELETE', path);

  Future<Object?> _send(String method, String path, {Object? body}) async {
    final uri = Uri.parse('$_serverUrl$path');
    final headers = <String, String>{
      if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
      if (body != null) 'content-type': 'application/json; charset=utf-8',
    };
    final http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_timeout);
    } on TimeoutException {
      throw ApiException('TIMEOUT', '请求超时');
    }
    return _parseEnvelope(response);
  }

  /// 信封解析（[uploadAvatar] 的 multipart 发送与 [_send] 共用）：
  /// 空/非 JSON 响应、HTTP 异常、code 非 OK 均抛 [ApiException]；
  /// 401（AUTH_UNAUTHORIZED）触发 [onUnauthorized]；2xx + OK 返回 data
  /// （POST 评论等创建接口成功状态码为 201）。
  Object? _parseEnvelope(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      throw ApiException('HTTP_${response.statusCode}', '空响应');
    }
    final Map<String, dynamic> envelope;
    try {
      envelope =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException('BAD_JSON', '响应不是合法 JSON');
    }
    final code = envelope['code'] as String? ?? 'HTTP_${response.statusCode}';
    if (response.statusCode == 401 && code == 'AUTH_UNAUTHORIZED') {
      // Token 过期/被顶下线：通知上层清登录态并引导重新登录。
      onUnauthorized?.call();
    }
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        code == 'OK') {
      return envelope['data'];
    }
    throw ApiException(code, envelope['message'] as String? ?? '请求失败');
  }

  Future<MetaInfo> fetchMeta() async {
    final data = await get(ApiPaths.meta);
    return MetaInfo.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<List<CourseSummary>> fetchCourses() async {
    final data = await get(ApiPaths.courses);
    return CourseSummary.listFromJson(data);
  }

  Future<CourseDetail> fetchCourseDetail(String slug) async {
    final data = await get(ApiPaths.courseDetail(slug));
    return CourseDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<ChapterContent> fetchChapter(
    String courseSlug,
    String chapterSlug,
  ) async {
    final data = await get(ApiPaths.chapter(courseSlug, chapterSlug));
    return ChapterContent.fromJson((data as Map).cast<String, dynamic>());
  }

  // —— 认证 ——

  Future<AuthSession> register(String username, String password) =>
      _auth(ApiPaths.register, username, password);

  Future<AuthSession> login(String username, String password) =>
      _auth(ApiPaths.login, username, password);

  Future<AuthSession> _auth(
    String path,
    String username,
    String password,
  ) async {
    final data = await post(path, body: {
      'username': username,
      'password': password,
    });
    final map = (data as Map).cast<String, dynamic>();
    return AuthSession(
      token: map['token'] as String? ?? '',
      user: AuthUser.fromJson(
        (map['user'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  Future<AuthUser> fetchMe() async {
    final data = await get(ApiPaths.me);
    return AuthUser.fromJson(
      ((data as Map)['user'] as Map).cast<String, dynamic>(),
    );
  }

  // —— 云端观看历史 ——

  Future<void> putRecord(
    String courseSlug,
    String chapterSlug,
    String chapterTitle,
  ) => put(ApiPaths.records, body: {
    'courseSlug': courseSlug,
    'chapterSlug': chapterSlug,
    'chapterTitle': chapterTitle,
  }).then((_) {});

  Future<List<ReadRecord>> fetchRecords() async {
    final data = await get(ApiPaths.records);
    return ReadRecord.listFromJson((data as Map)['records']);
  }

  Future<void> clearRecords() => delete(ApiPaths.records).then((_) {});

  Future<void> deleteRecord(String courseSlug, String chapterSlug) =>
      delete(ApiPaths.record(courseSlug, chapterSlug)).then((_) {});

  // —— 头像 ——

  /// 头像上传超时单独放宽：移动网络上传 5MB 级图片 4 秒不够。
  static const Duration _uploadTimeout = Duration(seconds: 15);

  /// POST /api/v1/me/avatar（Bearer，multipart 字段 file）。
  /// 走独立的 MultipartRequest 发送，信封解析复用 [_parseEnvelope]。
  Future<AuthUser> uploadAvatar(Uint8List bytes, String filename) async {
    final uri = Uri.parse('$_serverUrl${ApiPaths.meAvatar}');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      )
      ..headers.addAll({
        if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
      });
    final http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_uploadTimeout);
    } on TimeoutException {
      throw ApiException('TIMEOUT', '请求超时');
    }
    final data = _parseEnvelope(response);
    return AuthUser.fromJson(
      ((data as Map)['user'] as Map).cast<String, dynamic>(),
    );
  }

  // —— 章节互动（阅读量 / 点赞 / 评论） ——

  /// 阅读量上报（无需登录）。fire-and-forget：内部吞掉异常，调用方
  /// 直接 unawaited 即可，离线/失败静默不影响阅读。
  Future<void> recordView(String courseSlug, String chapterSlug) =>
      post(ApiPaths.chapterView(courseSlug, chapterSlug))
          .then((_) {})
          .catchError((Object _) {});

  Future<ChapterStats> fetchChapterStats(
    String courseSlug,
    String chapterSlug,
  ) async {
    final data = await get(ApiPaths.chapterStats(courseSlug, chapterSlug));
    return ChapterStats.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 点赞 / 取消点赞（POST / DELETE .../like），返回服务端确认值。
  Future<({bool liked, int likeCount})> setLike(
    String courseSlug,
    String chapterSlug,
    bool liked,
  ) async {
    final path = ApiPaths.chapterLike(courseSlug, chapterSlug);
    final data = await (liked ? post(path) : delete(path));
    final map = (data as Map).cast<String, dynamic>();
    return (
      liked: map['liked'] as bool? ?? liked,
      likeCount: (map['likeCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<CommentPage> fetchComments(
    String courseSlug,
    String chapterSlug, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final path =
        '${ApiPaths.chapterComments(courseSlug, chapterSlug)}'
        '?page=$page&pageSize=$pageSize';
    final data = await get(path);
    return CommentPage.fromJson((data as Map).cast<String, dynamic>());
  }

  /// POST .../comments（Bearer，1..1000 字）；成功状态码 201。
  Future<ChapterComment> addComment(
    String courseSlug,
    String chapterSlug,
    String content,
  ) async {
    final data = await post(
      ApiPaths.chapterComments(courseSlug, chapterSlug),
      body: {'content': content},
    );
    return ChapterComment.fromJson(
      ((data as Map)['comment'] as Map).cast<String, dynamic>(),
    );
  }

  /// DELETE /api/v1/comments/{id}（Bearer，仅作者）。
  Future<void> deleteComment(int id) =>
      delete(ApiPaths.comment(id)).then((_) {});

  // —— 版本检查 ——

  /// 拉最新版本信息；404（后端未发布任何版本）返回 null。
  Future<AppRelease?> fetchLatestRelease() async {
    try {
      final data = await get(ApiPaths.appLatest);
      return AppRelease.fromJson((data as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      if (error.code.contains('404') || error.code.contains('NOT_FOUND')) {
        return null;
      }
      rethrow;
    }
  }
}
