import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// API 路径集中定义（缓存 key 也按这些路径生成）。
abstract final class ApiPaths {
  static const meta = '/api/v1/meta';
  static const courses = '/api/v1/courses';
  static String courseDetail(String slug) => '/api/v1/courses/$slug';
  static String chapter(String courseSlug, String chapterSlug) =>
      '/api/v1/courses/$courseSlug/chapters/$chapterSlug';
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
class ApiClient {
  ApiClient(String serverUrl, {http.Client? client})
    : _serverUrl = serverUrl,
      _client = client ?? http.Client();

  String _serverUrl;
  final http.Client _client;

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

  static const Duration _timeout = Duration(seconds: 10);

  Future<Object?> get(String path) async {
    final uri = Uri.parse('$_serverUrl$path');
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw ApiException('TIMEOUT', '请求超时');
    }
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
    if (response.statusCode == 200 && code == 'OK') {
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
}
