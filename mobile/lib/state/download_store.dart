import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'content_cache.dart';
import 'image_cache_store.dart';
import 'library_store.dart';

/// 课程下载状态取值（CourseDownloadState.status）。
abstract final class DownloadStatus {
  static const idle = 'idle';
  static const downloading = 'downloading';
  static const done = 'done';
  static const failed = 'failed';
}

/// 单课程离线下载进度状态（全部 int/字符串，UI 直接读）。
class CourseDownloadState {
  CourseDownloadState({
    this.status = DownloadStatus.idle,
    this.chaptersDone = 0,
    this.chaptersTotal = 0,
    this.imagesDone = 0,
    this.imagesTotal = 0,
    this.bytesReceived = 0,
    this.error,
  });

  String status;
  int chaptersDone;
  int chaptersTotal;
  int imagesDone;
  int imagesTotal;
  int bytesReceived;
  String? error;

  /// 统一进度口径：(章节完成数 + 图片完成数) / (章节总数 + 图片总数)。
  double get progress {
    final total = chaptersTotal + imagesTotal;
    if (total == 0) return 0;
    return ((chaptersDone + imagesDone) / total).clamp(0.0, 1.0);
  }
}

/// 课程级离线下载：目录与章节正文按 LibraryStore 相同的缓存 key / JSON 格式
/// 写入 ContentCache（离线阅读时 loadChapter 的 网络→缓存 兜底链路原样生效），
/// 正文图片下载到本地文档目录（路径规则见 ImageCacheStore）。
class DownloadStore extends ChangeNotifier {
  DownloadStore(this._api, this._cache) {
    // main.dart 已在 runApp 前 await 过 getInstance()，这里取回同一实例，
    // 让 isDownloaded 可以同步读 flag。
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      notifyListeners();
    });
  }

  static const String _flagPrefix = 'downloads.';

  final ApiClient _api;
  final ContentCache _cache;

  SharedPreferences? _prefs;
  final Map<String, CourseDownloadState> _states =
      <String, CourseDownloadState>{};

  CourseDownloadState? stateOf(String slug) => _states[slug];

  /// 是否已整课下载（存在 `downloads.<slug>` flag）。
  bool isDownloaded(String slug) =>
      _prefs?.getString('$_flagPrefix$slug')?.isNotEmpty ?? false;

  /// 整课下载：done 后再点 = 重新下载更新；下载中重复调用直接返回（幂等）。
  Future<void> downloadCourse(String slug) async {
    final existing = _states[slug];
    if (existing != null && existing.status == DownloadStatus.downloading) {
      return;
    }

    final state = CourseDownloadState(status: DownloadStatus.downloading);
    _states[slug] = state;
    notifyListeners();

    // 1. 目录：强制走网络拿最新并写缓存（key/格式与 loadCourseDetail 完全一致）。
    final CourseDetail detail;
    try {
      detail = await _api.fetchCourseDetail(slug);
      await _cache.put(
        ApiPaths.courseDetail(slug),
        LibraryStore.detailToJson(detail),
      );
    } catch (error) {
      state
        ..status = DownloadStatus.failed
        ..error = '目录拉取失败：$error';
      notifyListeners();
      return;
    }

    // 2. 顺序逐章拉取并写缓存（key/格式与 loadChapter 完全一致）；
    //    单章失败记录并继续；同时收集正文图片 URL 全集。
    state.chaptersTotal = detail.chapters.length;
    notifyListeners();

    final imageUrls = <String>{};
    var failedChapters = 0;
    for (final chapter in detail.chapters) {
      try {
        final content = await _api.fetchChapter(slug, chapter.slug);
        await _cache.put(
          ApiPaths.chapter(slug, chapter.slug),
          LibraryStore.chapterToJson(content),
        );
        imageUrls.addAll(extractImageUrls(content.contentMd));
      } catch (_) {
        failedChapters++;
      }
      state.chaptersDone++;
      notifyListeners();
    }

    // 3. 逐张下载图片；文件已存在的直接跳过；单张失败记录并继续。
    state.imagesTotal = imageUrls.length;
    notifyListeners();

    var failedImages = 0;
    for (final raw in imageUrls) {
      try {
        state.bytesReceived += await ImageCacheStore.ensureDownloaded(
          raw,
          _api.resolve(raw),
        );
      } catch (_) {
        failedImages++;
      }
      state.imagesDone++;
      notifyListeners();
    }

    // 4. 收尾：无论成败都写下载 flag；有跳过项时在 error 里注明。
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(
      '$_flagPrefix$slug',
      DateTime.now().toIso8601String(),
    );
    state.status = DownloadStatus.done;
    final skipped = failedChapters + failedImages;
    if (skipped > 0) state.error = '跳过 $skipped 项';
    notifyListeners();
  }

  /// 从 markdown 提取图片地址：先整段剔除 ``` 围栏代码块，
  /// 再扫 `![alt](url)`，收 http/https 绝对地址与相对路径图片，
  /// 统一存 raw 原文（文件名按原文 md5），去重。
  static Set<String> extractImageUrls(String markdown) {
    final urls = <String>{};
    var inFence = false;
    for (final line in markdown.split('\n')) {
      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        continue;
      }
      if (inFence) continue;
      for (final match in _imageRegExp.allMatches(line)) {
        final raw = match.group(1);
        if (raw == null) continue;
        if (ImageCacheStore.isDownloadable(raw)) urls.add(raw);
      }
    }
    return urls;
  }

  static final RegExp _imageRegExp = RegExp(r'!\[[^\]]*\]\(\s*([^)\s]+)');
}
