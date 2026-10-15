import 'package:flutter/material.dart';

/// design.md 冻结 token。深浅两套同构配色，跟随系统。
class AppColors {
  const AppColors._({
    required this.brightness,
    required this.paper,
    required this.card,
    required this.ink,
    required this.inkMuted,
    required this.accent,
    required this.track,
    required this.onAccent,
  });

  static const Color _seed = Color(0xFF0D9488);

  static const AppColors dark = AppColors._(
    brightness: Brightness.dark,
    paper: Color(0xFF101312),
    card: Color(0xFF1D211F),
    ink: Color(0xFFF2F5F3),
    inkMuted: Color(0xFF8A938E),
    accent: Color(0xFF14B8A6),
    track: Color(0xFF313734),
    onAccent: Color(0xFF062925),
  );

  static const AppColors light = AppColors._(
    brightness: Brightness.light,
    paper: Color(0xFFF4F6F5),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1A1F1D),
    inkMuted: Color(0xFF6D7773),
    accent: Color(0xFF0D9488),
    track: Color(0xFFE3E8E6),
    onAccent: Color(0xFFFFFFFF),
  );

  final Brightness brightness;
  final Color paper;
  final Color card;
  final Color ink;
  final Color inkMuted;
  final Color accent;
  final Color track;
  final Color onAccent;

  /// accent 14%（深色）/ 12%（浅色）混入 card，用于选中胶囊/状态底色。
  Color get accentDim => Color.alphaBlend(
    accent.withValues(alpha: brightness == Brightness.dark ? 0.14 : 0.12),
    card,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// 主题种子色（Material 3 ColorScheme.fromSeed）。
  static const Color seedColor = _seed;
}

/// design.md 语言标签块固定配色（不随主题反色）。
class LanguageTagStyle {
  const LanguageTagStyle({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  static LanguageTagStyle forLanguage(String language, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (language) {
      case 'Go':
        return isDark
            ? const LanguageTagStyle(
                background: Color(0xFF1D2B2E),
                foreground: Color(0xFF7DD3C8),
              )
            : const LanguageTagStyle(
                background: Color(0xFFE6F5F3),
                foreground: Color(0xFF0F766E),
              );
      case 'Python':
        return isDark
            ? const LanguageTagStyle(
                background: Color(0xFF232936),
                foreground: Color(0xFF9DB4E8),
              )
            : const LanguageTagStyle(
                background: Color(0xFFEDF1FA),
                foreground: Color(0xFF4C6BB0),
              );
      default:
        // 其他语言：语言主色低饱和深底 + 亮字（深色）/ 浅底 + 深字（浅色），
        // 无既有主色时以主题 accent 同思路兜底。
        {
          final colors = isDark ? AppColors.dark : AppColors.light;
          return LanguageTagStyle(
            background: colors.accentDim,
            foreground: colors.accent,
          );
        }
    }
  }
}

/// 等宽数字文本（进度/百分比，13 mono tabular）。
class MonoText extends StatelessWidget {
  const MonoText(this.text, {super.key, this.color, this.fontSize = 13});

  final String text;
  final Color? color;
  final double fontSize;

  static const TextStyle monoBase = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: MonoText.monoBase.copyWith(
        fontSize: fontSize,
        color: color,
        height: 1.2,
      ),
    );
  }
}

/// 4px 进度条（圆角 2，track 底 + accent 填充）。
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value});

  /// 0.0 - 1.0
  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: colors.track)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: colors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// 语言标签块（12px 字 + 固定底色）。
class LanguageTag extends StatelessWidget {
  const LanguageTag({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final style = LanguageTagStyle.forLanguage(
      language,
      Theme.of(context).brightness,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        language,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color: style.foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// design.md 课程卡容器：圆角 22，内边距 18（底部 16）。
class DesignCard extends StatelessWidget {
  const DesignCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 首页课程卡状态。
enum CourseStatus { notStarted, learning, finished }

CourseStatus courseStatusFor(int readCount, int totalChapters) {
  if (totalChapters > 0 && readCount >= totalChapters) {
    return CourseStatus.finished;
  }
  if (readCount > 0) return CourseStatus.learning;
  return CourseStatus.notStarted;
}

String courseStatusLabel(CourseStatus status) => switch (status) {
  CourseStatus.notStarted => '未开始',
  CourseStatus.learning => '学习中',
  CourseStatus.finished => '已读完',
};
