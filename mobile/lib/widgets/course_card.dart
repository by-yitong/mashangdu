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

/// 课程卡：状态行 → 20/w700 标题 → 底部行（语言标签 + mono 进度）→ 4px 进度条。
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.readCount,
    required this.progress,
    required this.onTap,
  });

  final CourseSummary course;
  final int readCount;
  final double progress;
  final VoidCallback onTap;

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
            ],
          ),
          const SizedBox(height: 10),
          ProgressBar(value: progress),
        ],
      ),
    );
  }
}

/// 继续阅读卡：accent 色点 + “继续阅读”，标题为章节名，
/// 底部行左侧播放章块 + 右侧 mono 百分比。置顶展示，点击跳转上次读到章节。
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
    return DesignCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusRow(
            dotColor: colors.accent,
            label: '继续阅读 · $courseTitle',
            trailing: '',
          ),
          const SizedBox(height: 8),
          Text(
            chapterTitle,
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
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: colors.accentDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 18,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '上次读到',
                  style: TextStyle(fontSize: 12, color: colors.inkMuted),
                ),
              ),
              MonoText('$percent%', color: colors.accent),
            ],
          ),
          const SizedBox(height: 10),
          ProgressBar(value: progress),
        ],
      ),
    );
  }
}
