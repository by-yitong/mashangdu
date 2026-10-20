import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/design.dart';

/// 状态行：8px 色点 + 状态词；右侧 13px 次要文字。
class StatusRow extends StatelessWidget {
  const StatusRow({
    super.key,
    required this.dotColor,
    required this.label,
    required this.trailing,
  });

  final Color dotColor;
  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 14, height: 1.2, color: colors.inkMuted),
        ),
        const Spacer(),
        Text(
          trailing,
          style: TextStyle(fontSize: 13, height: 1.2, color: colors.inkMuted),
        ),
      ],
    );
  }
}

DateTime? _updatedOf(CourseSummary course) => course.updatedAt;

String _dateLabel(DateTime? time) {
  if (time == null) return '';
  return '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';
}

/// 课程卡：状态行 → 20/w700 标题 → 底部行（语言标签 + mono 进度 + 离线标）→ 4px 进度条。
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.readCount,
    required this.progress,
    required this.onTap,
    this.offline = false,
  });

  final CourseSummary course;
  final int readCount;
  final double progress;
  final VoidCallback onTap;

  /// 已整课离线下载时在底部行尾显示“离线”小标。
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final status = courseStatusFor(readCount, course.chapterCount);
    return DesignCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusRow(
            dotColor: status == CourseStatus.notStarted
                ? colors.inkMuted
                : colors.accent,
            label: courseStatusLabel(status),
            trailing: _dateLabel(_updatedOf(course)),
          ),
          const SizedBox(height: 8),
          Text(
            course.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              LanguageTag(language: course.language),
              const Spacer(),
              MonoText(
                '$readCount/${course.chapterCount}',
                color: colors.inkMuted,
              ),
              if (offline) ...[
                const SizedBox(width: 10),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                MonoText('离线', color: colors.inkMuted, fontSize: 11),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ProgressBar(value: progress),
        ],
      ),
    );
  }
}

/// 继续阅读卡（hero 卡）：与普通白底课程卡明确区分——accentDim 底 +
/// accent 28% 描边（自建容器，不用 DesignCard 的 card 底色），圆角 22、
/// 内边距同课程卡。横向布局：左列「继续阅读」标签（accent 12/w600）+
/// 课程名（12 inkMuted 省略）→ 章节标题 20/w700 ink（最多 2 行）→ 底部行
/// 进度条 + mono accent 百分比；右列 52px accent 圆形播放钮（onAccent 图标）。
/// 点击跳转上次读到章节。
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.courseTitle,
    required this.chapterTitle,
    required this.percent,
    required this.progress,
    required this.onTap,
  });

  final String courseTitle;
  final String chapterTitle;
  final int percent;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // 描边画在外层 Container（decoration），Material 只负责水波纹：
    // 透明色 + 22 圆角 + antiAlias 裁切，波纹不会溢出圆角。
    return Container(
      decoration: BoxDecoration(
        color: colors.accentDim,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.accent.withValues(alpha: 0.28)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            '继续阅读',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              courseTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        chapterTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: ProgressBar(value: progress)),
                          const SizedBox(width: 8),
                          MonoText('$percent%', color: colors.accent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 30,
                    color: colors.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
