import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/library_store.dart';
import '../state/progress_store.dart';
import '../widgets/course_card.dart';
import '../widgets/design.dart';
import 'course_page.dart';

enum HomeFilter { all, learning, notStarted }

/// 首页：大标题 + 同步行 → 筛选胶囊 → 课程卡列表（继续阅读置顶）→ 没有更多了。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onGoSettings});

  final VoidCallback onGoSettings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeFilter _filter = HomeFilter.all;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final library = context.watch<LibraryStore>();
    final progress = context.watch<ProgressStore>();

    final courses = library.courses;
    final visibleCourses = courses.where((course) {
      final status = courseStatusFor(
        progress.readCount(course.slug),
        course.chapterCount,
      );
      return switch (_filter) {
        HomeFilter.all => true,
        HomeFilter.learning => status == CourseStatus.learning,
        HomeFilter.notStarted => status == CourseStatus.notStarted,
      };
    }).toList();

    // 继续阅读目标：列表顺序下第一个“学习中”的课程。
    CourseSummary? continueCourse;
    for (final course in courses) {
      final status = courseStatusFor(
        progress.readCount(course.slug),
        course.chapterCount,
      );
      if (status == CourseStatus.learning) {
        continueCourse = course;
        break;
      }
    }

    // 顶部预留 safeArea + 12；底部预留玻璃胶囊导航净空（≥104）。
    final topPadding = MediaQuery.paddingOf(context).top + 12;
    const bottomPadding = 120.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      children: [
        Text(
          '码上读',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 4),
        _SyncLine(library: library),
        const SizedBox(height: 16),
        _FilterPills(
          selected: _filter,
          onSelected: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 16),
        if (library.status == SyncStatus.offline && courses.isEmpty)
          _EmptyState(onGoSettings: widget.onGoSettings)
        else if (courses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (continueCourse != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ContinueCardTarget(
                course: continueCourse,
                progress: progress,
              ),
            ),
          for (final course in visibleCourses)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: CourseCard(
                course: course,
                readCount: progress.readCount(course.slug),
                progress:
                    progress.progress(course.slug, course.chapterCount),
                onTap: () => _openCourse(course),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                '没有更多了',
                style: TextStyle(fontSize: 13, color: colors.inkMuted),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openCourse(CourseSummary course) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoursePage(course: course),
      ),
    );
  }
}

/// 同步行：已同步 · N 门课程 · 日期 / 离线 · 显示缓存 / 正在同步…
class _SyncLine extends StatelessWidget {
  const _SyncLine({required this.library});

  final LibraryStore library;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final String text;
    switch (library.status) {
      case SyncStatus.syncing:
      case SyncStatus.initial:
        text = '正在同步…';
      case SyncStatus.synced:
        final date = library.meta?.versionDate ?? '';
        text =
            '已同步 · ${library.courses.length} 门课程${date.isEmpty ? '' : ' · $date'}';
      case SyncStatus.offline:
        text = library.courses.isEmpty ? '离线 · 暂无缓存' : '离线 · 显示缓存';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.3, color: colors.inkMuted),
      ),
    );
  }
}

/// 筛选胶囊组：选中 = accentDim 底 + accent 字 w600；未选 = card 底 + inkMuted。
class _FilterPills extends StatelessWidget {
  const _FilterPills({required this.selected, required this.onSelected});

  final HomeFilter selected;
  final ValueChanged<HomeFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final items = {
      HomeFilter.all: '全部',
      HomeFilter.learning: '学习中',
      HomeFilter.notStarted: '未开始',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in items.entries)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelected(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected == entry.key ? colors.accentDim : colors.card,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight:
                      selected == entry.key ? FontWeight.w600 : FontWeight.w400,
                  color:
                      selected == entry.key ? colors.accent : colors.inkMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 继续阅读卡目标：读取 last 章节标题与进度。
class _ContinueCardTarget extends StatelessWidget {
  const _ContinueCardTarget({required this.course, required this.progress});

  final CourseSummary course;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    final chapterTitle =
        progress.lastChapterTitle(course.slug) ?? course.title;
    final percent =
        (progress.progress(course.slug, course.chapterCount) * 100).round();
    return ContinueCard(
      courseTitle: course.title,
      chapterTitle: chapterTitle,
      percent: percent,
      progress: progress.progress(course.slug, course.chapterCount),
      onTap: () {
        final lastSlug = progress.lastChapter(course.slug);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CoursePage(
              course: course,
              openChapterSlug: lastSlug,
            ),
          ),
        );
      },
    );
  }
}

/// 离线且无缓存空态。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGoSettings});

  final VoidCallback onGoSettings;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: colors.inkMuted),
          const SizedBox(height: 12),
          Text(
            '暂无内容',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '网络不可用，且本地没有缓存。\n请检查网络，或到设置页确认服务器地址。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: colors.inkMuted),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onGoSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('前往设置'),
            style: TextButton.styleFrom(foregroundColor: colors.accent),
          ),
        ],
      ),
    );
  }
}
