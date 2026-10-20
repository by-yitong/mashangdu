import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// 启动恢复阅读的记录存储：
/// - `resume.course_json`：CourseSummary.toJson() 经 jsonEncode 的字符串
/// - `resume.chapter_slug`：停留章节 slug
///
/// 语义（与 ReaderPage / HomeShell 协作）：
/// - 进入阅读页写入、页内切章时更新；
/// - 正常退出阅读页（ReaderPage.dispose）即清除——因此"从首页/其他页退出
///   app"天然不恢复；
/// - 进程被杀时 dispose 不会执行 → 记录留存，下次启动由 HomeShell 据此
///   直接推回 ReaderPage。
class ResumeStore extends ChangeNotifier {
  ResumeStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _courseKey = 'resume.course_json';
  static const String _chapterKey = 'resume.chapter_slug';

  /// 进入阅读页 / 页内切章时写入课程与当前章。
  /// 返回 Future 便于调用方按需 await（如测试）；ReaderPage 内 fire-and-forget。
  Future<void> enterReading(CourseSummary course, String chapterSlug) async {
    await _prefs.setString(_courseKey, jsonEncode(course.toJson()));
    await _prefs.setString(_chapterKey, chapterSlug);
  }

  /// 退出阅读页清除记录。ReaderPage.dispose 同步路径调用时不 await，
  /// 平台侧异步落盘即可（进程随后被杀也以最后一次成功写入为准）。
  Future<void> exitReading() async {
    await _prefs.remove(_courseKey);
    await _prefs.remove(_chapterKey);
  }

  /// 待恢复目标；两个 key 任一缺失 / JSON 非法（或非对象）→ null。
  ({CourseSummary course, String chapterSlug})? pendingResume() {
    final courseJson = _prefs.getString(_courseKey);
    final chapterSlug = _prefs.getString(_chapterKey);
    if (courseJson == null || chapterSlug == null) return null;
    try {
      final decoded = jsonDecode(courseJson);
      if (decoded is! Map<String, dynamic>) return null;
      return (
        course: CourseSummary.fromJson(decoded),
        chapterSlug: chapterSlug,
      );
    } catch (_) {
      // 坏 JSON（半截写入、手工改动等）：视为无记录，启动正常进首页。
      return null;
    }
  }
}
