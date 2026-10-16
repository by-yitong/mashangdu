import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/reading_theme.dart';

/// 阅读偏好：字号三档 / 阅读主题（auto + 亮暗记忆槽）/ 行距 / 翻页模式 /
/// 章节内进度，全部持久化到 shared_preferences（key 前缀 `reader.`）。
class ReaderPrefs extends ChangeNotifier {
  ReaderPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'reader.font_scale';
  static const String _themeKey = 'reader.reading_theme';
  static const String _themeLightKey = 'reader.reading_theme_light';
  static const String _themeDarkKey = 'reader.reading_theme_dark';
  static const String _lineHeightKey = 'reader.line_height';
  static const String _pageModeKey = 'reader.page_mode';
  static const String _coachKey = 'reader.coach_shown';

  /// 档位缩放倍率（持久化值）。
  static const List<double> scales = [1.0, 1.125, 1.25];

  /// 行距三档（持久化值）：紧凑 / 标准 / 宽松。
  static const List<double> lineHeights = [1.4, 1.6, 1.8];

  /// 翻页模式：'tap' 点击翻页（默认）/ 'scroll' 自由滚动。
  static const List<String> pageModes = ['tap', 'scroll'];

  double _scale = scales[0];
  double _lineHeight = 1.4;
  String _pageMode = 'tap';

  /// 首次阅读指引是否已展示过（展示一次后永久记录）。
  bool get coachShown => _prefs.getBool(_coachKey) ?? false;

  Future<void> markCoachShown() async {
    await _prefs.setBool(_coachKey, true);
    notifyListeners();
  }

  // —— 字号三档（原有行为，保留不动） ——

  /// 当前正文缩放倍率。
  double get scale => _scale;

  int get _index {
    final i = scales.indexOf(_scale);
    return i < 0 ? 0 : i;
  }

  /// 正文 / 列表字号：16 / 18 / 20。
  double get bodyFontSize => 16 * _scale;

  /// 标题按正文比例缩放：h1 ×1.5。
  double get h1FontSize => bodyFontSize * 1.5;

  /// h2 ×1.3。
  double get h2FontSize => bodyFontSize * 1.3;

  /// h3 ×1.15。
  double get h3FontSize => bodyFontSize * 1.15;

  /// 代码块字号：13 / 14 / 15。
  double get codeFontSize => 13.0 + _index;

  /// 档位名（字号面板展示用）。
  String get label => const ['标准', '大', '特大'][_index];

  /// 切换档位并持久化。传入未定义倍率时忽略。
  Future<void> setScale(double scale) async {
    if (!scales.contains(scale) || scale == _scale) return;
    _scale = scale;
    await _prefs.setDouble(_key, scale);
    notifyListeners();
  }

  // —— 阅读主题 ——

  /// 'auto'：主题选择里的自动档（跟随 App 深浅色取记忆槽）。
  static const String autoTheme = 'auto';

  String _readingTheme = autoTheme;
  String _readingThemeLight = ReadingTheme.paper.id;
  String _readingThemeDark = ReadingTheme.night.id;

  /// 当前主题档位：'auto'（默认）或固定主题 id。
  String get readingTheme => _readingTheme;

  /// auto 档在 App 浅色下使用的记忆槽主题 id。
  String get readingThemeLight => _readingThemeLight;

  /// auto 档在 App 深色下使用的记忆槽主题 id。
  String get readingThemeDark => _readingThemeDark;

  /// 实际生效的主题 id：'auto' → 按 [appBrightness] 取记忆槽；
  /// 固定 → 返回固定 id（非法值回退 paper）。
  String effectiveReadingTheme(Brightness appBrightness) {
    if (_readingTheme != autoTheme) {
      return ReadingTheme.ids.contains(_readingTheme)
          ? _readingTheme
          : ReadingTheme.paper.id;
    }
    final slot = appBrightness == Brightness.dark
        ? _readingThemeDark
        : _readingThemeLight;
    return ReadingTheme.ids.contains(slot) ? slot : ReadingTheme.paper.id;
  }

  /// 切换主题档位并持久化：'auto' 只改档位；固定主题 id 同时按该主题
  /// 亮暗写入对应记忆槽（auto 档切回时沿用最近一次的手动选择）。
  /// 非法 id 忽略。
  Future<void> setReadingTheme(String id) async {
    if (id != autoTheme && !ReadingTheme.ids.contains(id)) return;
    if (id == _readingTheme) return;
    _readingTheme = id;
    await _prefs.setString(_themeKey, id);
    if (id != autoTheme) {
      final theme = ReadingTheme.of(id);
      if (theme.isDark) {
        _readingThemeDark = id;
        await _prefs.setString(_themeDarkKey, id);
      } else {
        _readingThemeLight = id;
        await _prefs.setString(_themeLightKey, id);
      }
    }
    notifyListeners();
  }

  // —— 行距 ——

  /// 正文行距：1.4（默认）/ 1.6 / 1.8。
  double get lineHeight => _lineHeight;

  /// 切换行距档位并持久化；未定义值忽略。
  Future<void> setLineHeight(double value) async {
    if (!lineHeights.contains(value) || value == _lineHeight) return;
    _lineHeight = value;
    await _prefs.setDouble(_lineHeightKey, value);
    notifyListeners();
  }

  // —— 翻页模式 ——

  /// 当前翻页模式：'tap'（点击翻页，默认）| 'scroll'（自由滚动）。
  String get pageMode => _pageMode;

  /// 是否点击翻页模式（手势层用）。
  bool get tapPaging => _pageMode == 'tap';

  /// 切换翻页模式并持久化；非法值忽略。
  Future<void> setPageMode(String mode) async {
    if (!pageModes.contains(mode) || mode == _pageMode) return;
    _pageMode = mode;
    await _prefs.setString(_pageModeKey, mode);
    notifyListeners();
  }

  // —— 章节内进度（按比例记忆） ——

  static String _posKey(String courseSlug, String chapterSlug) =>
      'reader.pos.$courseSlug/$chapterSlug';

  /// 章节内已存进度比例（0~1）；未存过返回 null。
  double? positionOf(String courseSlug, String chapterSlug) =>
      _prefs.getDouble(_posKey(courseSlug, chapterSlug));

  /// 保存章节内进度比例（0~1，越界按边界截断）。
  Future<void> savePosition(
    String courseSlug,
    String chapterSlug,
    double ratio0to1,
  ) {
    return _prefs.setDouble(
      _posKey(courseSlug, chapterSlug),
      ratio0to1.clamp(0.0, 1.0).toDouble(),
    );
  }

  /// 删除章节内进度（预留：清除进度类功能可用）。
  Future<void> removePosition(String courseSlug, String chapterSlug) =>
      _prefs.remove(_posKey(courseSlug, chapterSlug));

  /// 启动时读回全部偏好；非法值回退默认。
  void load() {
    final saved = _prefs.getDouble(_key);
    if (saved != null && scales.contains(saved)) _scale = saved;
    final theme = _prefs.getString(_themeKey);
    if (theme == autoTheme) {
      _readingTheme = autoTheme;
    } else if (theme != null && ReadingTheme.ids.contains(theme)) {
      // 兼容旧版（只存过 paper/cream/green/night 固定主题）：
      // 直接沿用为固定主题，无需写回。
      _readingTheme = theme;
    }
    final themeLight = _prefs.getString(_themeLightKey);
    if (themeLight != null && ReadingTheme.ids.contains(themeLight)) {
      _readingThemeLight = themeLight;
    }
    final themeDark = _prefs.getString(_themeDarkKey);
    if (themeDark != null && ReadingTheme.ids.contains(themeDark)) {
      _readingThemeDark = themeDark;
    }
    final lineHeight = _prefs.getDouble(_lineHeightKey);
    if (lineHeight != null && lineHeights.contains(lineHeight)) {
      _lineHeight = lineHeight;
    }
    final pageMode = _prefs.getString(_pageModeKey);
    if (pageMode != null && pageModes.contains(pageMode)) {
      _pageMode = pageMode;
    }
  }
}
