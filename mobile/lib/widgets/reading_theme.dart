import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 阅读页专属主题 token（独立于全局亮暗设置）。
///
/// 四套主题全部 token 化：bg/text/textSecondary/divider/accent/codeBg；
/// 阅读页内的颜色一律从 [ReadingTheme] 取，禁止散落硬编码色值。
class ReadingTheme {
  const ReadingTheme._({
    required this.id,
    required this.label,
    required this.bg,
    required this.text,
    required this.textSecondary,
    required this.divider,
    required this.accent,
    required this.codeBg,
    required this.brightness,
  });

  /// 纸白。
  static const ReadingTheme paper = ReadingTheme._(
    id: 'paper',
    label: '纸白',
    bg: Color(0xFFFFFFFF),
    text: Color(0xFF1F2623),
    textSecondary: Color(0xFF5F6B66),
    divider: Color(0xFFE8ECEA),
    accent: Color(0xFF0D9488),
    codeBg: Color(0xFF0C0F0E),
    brightness: Brightness.light,
  );

  /// 米白。
  static const ReadingTheme cream = ReadingTheme._(
    id: 'cream',
    label: '米白',
    bg: Color(0xFFF7F2E7),
    text: Color(0xFF3A352A),
    textSecondary: Color(0xFF7A7260),
    divider: Color(0xFFE6DFCE),
    accent: Color(0xFF0D9488),
    codeBg: Color(0xFF0C0F0E),
    brightness: Brightness.light,
  );

  /// 护眼绿。
  static const ReadingTheme green = ReadingTheme._(
    id: 'green',
    label: '护眼',
    bg: Color(0xFFE2EFE2),
    text: Color(0xFF2A3A2C),
    textSecondary: Color(0xFF5F7361),
    divider: Color(0xFFCFE2CF),
    accent: Color(0xFF0D9488),
    codeBg: Color(0xFF0C0F0E),
    brightness: Brightness.light,
  );

  /// 夜间。
  static const ReadingTheme night = ReadingTheme._(
    id: 'night',
    label: '夜间',
    bg: Color(0xFF101312),
    text: Color(0xFFC9D1CD),
    textSecondary: Color(0xFF8A938E),
    divider: Color(0xFF2A2F2C),
    accent: Color(0xFF14B8A6),
    codeBg: Color(0xFF0A0D0C),
    brightness: Brightness.dark,
  );

  static const List<ReadingTheme> all = [paper, cream, green, night];

  /// 全部主题 id（prefs 持久化值校验用）。
  static const List<String> ids = ['paper', 'cream', 'green', 'night'];

  final String id;
  final String label;
  final Color bg;
  final Color text;
  final Color textSecondary;
  final Color divider;

  /// teal 系强调色：浅色三主题 #0D9488 / 夜间 #14B8A6。
  final Color accent;

  /// 代码块底色（阅读主题内保持深底）。
  final Color codeBg;

  /// 浅色三主题为 light（状态栏黑 icon）/ 夜间为 dark（白 icon）。
  final Brightness brightness;

  /// 按 id 取主题；非法 id 回退纸白。
  static ReadingTheme of(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => paper);

  /// 状态栏/导航栏透明 + 图标亮度按主题（浅色主题黑 icon / 夜间白 icon）。
  SystemUiOverlayStyle get overlayStyle {
    final iconBrightness = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      // iOS：状态栏文字颜色随背景亮度反转。
      statusBarBrightness: brightness,
      systemNavigationBarIconBrightness: iconBrightness,
    );
  }

  /// 菜单顶/底栏的半透明沉浸条底色。
  Color get surfaceBarrier => bg.withValues(alpha: 0.94);

  /// accent 按 [alpha] 混入 bg（引用块底/选中胶囊底）。
  Color accentTint(double alpha) =>
      Color.alphaBlend(accent.withValues(alpha: alpha), bg);
}
