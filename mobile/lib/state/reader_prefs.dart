import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读字号偏好：三档（标准 16 / 大 18 / 特大 20），
/// 持久化正文缩放倍率 1.0 / 1.125 / 1.25（16 × 倍率 = 正文字号）。
class ReaderPrefs extends ChangeNotifier {
  ReaderPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'reader.font_scale';

  /// 档位缩放倍率（持久化值）。
  static const List<double> scales = [1.0, 1.125, 1.25];

  double _scale = scales[0];

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

  /// 档位名（字号选择面板展示用）。
  String get label => const ['标准', '大', '特大'][_index];

  /// 启动时读回上次档位；非法值回退标准。
  void load() {
    final saved = _prefs.getDouble(_key);
    if (saved != null && scales.contains(saved)) _scale = saved;
  }

  /// 切换档位并持久化。传入未定义倍率时忽略。
  Future<void> setScale(double scale) async {
    if (!scales.contains(scale) || scale == _scale) return;
    _scale = scale;
    await _prefs.setDouble(_key, scale);
    notifyListeners();
  }
}
