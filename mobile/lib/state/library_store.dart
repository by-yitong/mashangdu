import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'content_cache.dart';

/// 内容同步状态。
enum SyncStatus { initial, syncing, synced, offline }

/// 内容仓库：网络优先、缓存兜底。
///
/// - courses 列表：refresh() 拉取 /meta 与 /courses，成功则 [SyncStatus.synced]，
///   任一失败回退缓存并置 [SyncStatus.offline]。
/// - 课程详情 / 章节正文：先内存，再网络（成功写缓存），失败读缓存。
class LibraryStore extends ChangeNotifier {
  LibraryStore(this._api, this._cache);

  final ApiClient _api;
  final ContentCache _cache;

  SyncStatus status = SyncStatus.initial;
  MetaInfo? meta;
  List<CourseSummary> courses = const [];
  String? lastError;

  final Map<String, CourseDetail> _details = <String, CourseDetail>{};
  final Map<String, ChapterContent> _chapters = <String, ChapterContent>{};

  bool get isOffline => status == SyncStatus.offline;

  CourseDetail? cachedDetail(String slug) => _details[slug];

  ChapterContent? cachedChapter(String courseSlug, String chapterSlug) =>
      _chapters['$courseSlug/$chapterSlug'];

  /// 手动同步 / 首次加载：拉 meta + courses，失败回退缓存。
  Future<void> refresh() async {
    status = SyncStatus.syncing;
    lastError = null;
    notifyListeners();

    MetaInfo? newMeta;
    List<CourseSummary>? newCourses;
    Object? networkError;
    try {
      newMeta = await _api.fetchMeta();
      await _cache.put(ApiPaths.meta, newMeta.toJson());
      newCourses = await _api.fetchCourses();
      await _cache.put(
        ApiPaths.courses,
        newCourses.map((c) => c.toJson()).toList(),
      );
    } catch (error) {
      networkError = error;
    }

    if (newCourses != null) {
      meta = newMeta;
      courses = newCourses;
      status = SyncStatus.synced;
      notifyListeners();
      return;
    }

    // 网络失败 → 读缓存。
    final cachedMetaJson = _cache.get(ApiPaths.meta);
    final cachedCoursesJson = _cache.get(ApiPaths.courses);
    meta = cachedMetaJson == null
        ? null
        : MetaInfo.fromJson((cachedMetaJson as Map).cast<String, dynamic>());
    courses = cachedCoursesJson == null
        ? const []
        : CourseSummary.listFromJson(cachedCoursesJson);
    status = SyncStatus.offline;
    lastError = networkError.toString();
    notifyListeners();
  }

  /// 课程详情：内存 → 网络 → 缓存。全部未命中返回 null（页面显示空态）。
  Future<CourseDetail?> loadCourseDetail(String slug) async {
    final inMemory = _details[slug];
    if (inMemory != null) return inMemory;

    final path = ApiPaths.courseDetail(slug);
    try {
      final detail = await _api.fetchCourseDetail(slug);
      _details[slug] = detail;
      await _cache.put(path, detailToJson(detail));
      return detail;
    } catch (_) {
      final cached = _cache.get(path);
      if (cached == null) return null;
      final detail = CourseDetail.fromJson(
        (cached as Map).cast<String, dynamic>(),
      );
      _details[slug] = detail;
      return detail;
    }
  }

  /// 课程页下拉刷新：强制重新拉取课程详情（不走内存缓存，网络失败保留旧值），
  /// 并补拉尚未缓存的章节正文（单章失败不阻塞其余）。
  Future<CourseDetail?> refreshCourse(String slug) async {
    CourseDetail? detail;
    try {
      detail = await _api.fetchCourseDetail(slug);
      _details[slug] = detail;
      await _cache.put(ApiPaths.courseDetail(slug), detailToJson(detail));
    } catch (_) {
      detail = _details[slug];
    }
    if (detail == null) return null;

    for (final chapter in detail.chapters) {
      final key = '$slug/${chapter.slug}';
      final path = ApiPaths.chapter(slug, chapter.slug);
      if (_chapters.containsKey(key) || _cache.has(path)) continue;
      try {
        final content = await _api.fetchChapter(slug, chapter.slug);
        _chapters[key] = content;
        await _cache.put(path, chapterToJson(content));
      } catch (_) {
        // 单章拉取失败不阻塞刷新，需要时阅读页会再走 网络 → 缓存 链路。
      }
    }
    return detail;
  }

  /// 章节正文：内存 → 网络 → 缓存。全部未命中返回 null（页面显示空态）。
  Future<ChapterContent?> loadChapter(
    String courseSlug,
    String chapterSlug,
  ) async {
    final key = '$courseSlug/$chapterSlug';
    final inMemory = _chapters[key];
    if (inMemory != null) return inMemory;

    final path = ApiPaths.chapter(courseSlug, chapterSlug);
    try {
      final chapter = await _api.fetchChapter(courseSlug, chapterSlug);
      _chapters[key] = chapter;
      await _cache.put(path, chapterToJson(chapter));
      return chapter;
    } catch (_) {
      final cached = _cache.get(path);
      if (cached == null) return null;
      final chapter = ChapterContent.fromJson(
        (cached as Map).cast<String, dynamic>(),
      );
      _chapters[key] = chapter;
      return chapter;
    }
  }

  static Map<String, dynamic> detailToJson(CourseDetail d) => <String, dynamic>{
    'slug': d.slug,
    'title': d.title,
    'summary': d.summary,
    'language': d.language,
    'color': d.color,
    'updated_at': d.updatedAt?.toIso8601String(),
    'chapters': d.chapters
        .map(
          (c) => <String, dynamic>{
            'slug': c.slug,
            'title': c.title,
            'order': c.order,
          },
        )
        .toList(),
  };

  static Map<String, dynamic> chapterToJson(ChapterContent c) =>
      <String, dynamic>{
        'slug': c.slug,
        'course_slug': c.courseSlug,
        'title': c.title,
        'content_md': c.contentMd,
        'updated_at': c.updatedAt?.toIso8601String(),
      };
}
