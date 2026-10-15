import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读进度存储：
/// - `read.<courseSlug>`：已读章节 slug 列表
/// - `last.<courseSlug>`：最后阅读的章节 slug
/// - `lastTitle.<courseSlug>`：最后阅读的章节标题（首页“继续阅读”卡展示用）
class ProgressStore extends ChangeNotifier {
  ProgressStore(this._prefs);

  final SharedPreferences _prefs;

  static String _readKey(String courseSlug) => 'read.$courseSlug';
  static String _lastKey(String courseSlug) => 'last.$courseSlug';
  static String _lastTitleKey(String courseSlug) => 'lastTitle.$courseSlug';

  Set<String> readChapters(String courseSlug) =>
      (_prefs.getStringList(_readKey(courseSlug)) ?? const <String>[]).toSet();

  String? lastChapter(String courseSlug) =>
      _prefs.getString(_lastKey(courseSlug));

  String? lastChapterTitle(String courseSlug) =>
      _prefs.getString(_lastTitleKey(courseSlug));

  bool isRead(String courseSlug, String chapterSlug) =>
      readChapters(courseSlug).contains(chapterSlug);

  int readCount(String courseSlug) => readChapters(courseSlug).length;

  /// 进度 = 已读章数 / 总章数；总章数为 0 时返回 0。
  double progress(String courseSlug, int totalChapters) {
    if (totalChapters <= 0) return 0;
    return (readCount(courseSlug) / totalChapters).clamp(0.0, 1.0);
  }

  /// 进入章节即调用：写已读标记 + 最后阅读章节。
  Future<void> markRead(
    String courseSlug,
    String chapterSlug,
    String chapterTitle,
  ) async {
    final read = readChapters(courseSlug);
    final changed = read.add(chapterSlug);
    await _prefs.setStringList(_readKey(courseSlug), read.toList());
    await _prefs.setString(_lastKey(courseSlug), chapterSlug);
    await _prefs.setString(_lastTitleKey(courseSlug), chapterTitle);
    if (changed) notifyListeners();
  }
}
