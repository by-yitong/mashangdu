import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 离线图片共享工具：目录 / md5 文件名 / 已存在跳过的下载逻辑，
/// DownloadStore（整课批量）与 OfflineImage（阅读时按需）共用，
/// 保证只有一套路径规则。
abstract final class ImageCacheStore {
  ImageCacheStore._();

  static const String _dirName = 'offline_images';

  /// 单张图片下载超时。
  static const Duration _timeout = Duration(seconds: 30);

  /// 共享 keep-alive 连接（app 生命周期），避免逐图建连。
  static final http.Client _client = http.Client();

  static Directory? _cachedDir;

  /// `<应用文档目录>/offline_images`。
  static Future<Directory> directory() async {
    final cached = _cachedDir;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_dirName');
    await dir.create(recursive: true);
    return _cachedDir = dir;
  }

  /// 是否为可下载的 http/https 绝对地址。
  static bool isRemoteHttp(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// 是否可下载：http/https 绝对地址，或相对路径
  /// （无 scheme、非 `#` 开头、非空；`data:`/`file:` 等其他 scheme 不可下载）。
  static bool isDownloadable(String raw) {
    if (raw.isEmpty || raw.startsWith('#')) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    if (uri.scheme.isEmpty) return true; // 相对路径原文（如 images/a/b.png）。
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  /// 原始字符串（markdown 里的相对路径原文或绝对 URL 原文）→ 文件名：
  /// md5hex(原文) + 路径后缀（无后缀默认 .png）。
  /// 按原文而非拼接后的完整 URL 做 key：用户换服务器地址后离线缓存仍命中。
  static String fileName(String raw) {
    final name = md5.convert(utf8.encode(raw)).toString();
    return '$name${_extensionOf(raw)}';
  }

  static String _extensionOf(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot > path.lastIndexOf('/')) {
      final ext = path.substring(dot + 1).toLowerCase();
      if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)) return '.$ext';
    }
    return '.png';
  }

  /// 原始字符串对应的本地文件（文件未必已存在）。
  static Future<File> fileFor(String raw) async {
    final dir = await directory();
    return File('${dir.path}${Platform.pathSeparator}${fileName(raw)}');
  }

  /// 确保图片已落盘：文件名按 [raw] 原文计算，下载地址用调用方先 resolve 好的
  /// [resolvedUrl]；文件已存在直接跳过（返回 0 字节），否则下载写入
  /// （30 秒超时）。返回本次写入字节数，失败抛原始异常。
  static Future<int> ensureDownloaded(String raw, String resolvedUrl) async {
    final file = await fileFor(raw);
    if (await file.exists()) return 0;
    final uri = Uri.parse(resolvedUrl);
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return response.bodyBytes.length;
  }
}
