import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/library_store.dart';
import '../state/progress_store.dart';
import '../widgets/design.dart';
import 'reader_page.dart';

/// 课程页：顶部整体进度 + 章节列表（已读打勾）。
class CoursePage extends StatefulWidget {
  const CoursePage({super.key, required this.course, this.openChapterSlug});

  final CourseSummary course;

  /// 从“继续阅读卡”进入时，自动打开上次读到的章节。
  final String? openChapterSlug;

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  CourseDetail? _detail;
  bool _loading = true;
  bool _openedLastChapter = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail =
        await context.read<LibraryStore>().loadCourseDetail(widget.course.slug);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
    final openSlug = widget.openChapterSlug;
    if (openSlug != null &&
        !_openedLastChapter &&
        detail != null &&
        detail.chapters.any((c) => c.slug == openSlug)) {
      _openedLastChapter = true;
      _openChapter(openSlug);
    }
  }

  void _openChapter(String chapterSlug) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          course: widget.course,
          chapterSlug: chapterSlug,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final progress = context.watch<ProgressStore>();
    final chapters = _detail?.chapters ?? const <ChapterRef>[];
    final total = chapters.isNotEmpty ? chapters.length : widget.course.chapterCount;
    final readCount = progress.readCount(widget.course.slug);
    final ratio = progress.progress(widget.course.slug, total);

    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(title: Text(widget.course.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _ProgressHeader(
                  summary: widget.course,
                  readCount: readCount,
                  total: total,
                  ratio: ratio,
                ),
                const SizedBox(height: 16),
                if (chapters.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 40, color: colors.inkMuted),
                        const SizedBox(height: 12),
                        Text(
                          '章节内容加载失败',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '网络不可用且没有缓存，请稍后重试，或到设置页检查服务器地址。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < chapters.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ChapterTile(
                        index: i + 1,
                        chapter: chapters[i],
                        isRead:
                            progress.isRead(widget.course.slug, chapters[i].slug),
                        onTap: () => _openChapter(chapters[i].slug),
                      ),
                    ),
              ],
            ),
    );
  }
}

/// 课程整体进度：mono 数字 + 百分比 + 4px 进度条。
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.summary,
    required this.readCount,
    required this.total,
    required this.ratio,
  });

  final CourseSummary summary;
  final int readCount;
  final int total;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final percent = (ratio * 100).round();
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MonoText(
                '$readCount/$total',
                color: colors.ink,
                fontSize: 20,
              ),
              const Spacer(),
              MonoText('$percent%', color: colors.accent, fontSize: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.4, color: colors.inkMuted),
          ),
          const SizedBox(height: 12),
          ProgressBar(value: ratio),
        ],
      ),
    );
  }
}

/// 章节行：已读打勾图标。
class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.index,
    required this.chapter,
    required this.isRead,
    required this.onTap,
  });

  final int index;
  final ChapterRef chapter;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DesignCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            isRead ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 20,
            color: isRead ? colors.accent : colors.inkMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              chapter.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isRead ? colors.inkMuted : colors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          MonoText(
            chapter.order.toString().padLeft(2, '0'),
            color: colors.inkMuted,
            fontSize: 12,
          ),
        ],
      ),
    );
  }
}
