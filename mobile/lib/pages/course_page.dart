import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/download_store.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final detail = await context.read<LibraryStore>().loadCourseDetail(
      widget.course.slug,
    );
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
        builder: (_) =>
            ReaderPage(course: widget.course, chapterSlug: chapterSlug),
      ),
    );
  }

  /// 下拉刷新：重新拉取课程详情 + 未缓存章节。
  Future<void> _refresh() async {
    final detail = await context
        .read<LibraryStore>()
        .refreshCourse(widget.course.slug);
    if (!mounted || detail == null) return;
    setState(() => _detail = detail);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final progress = context.watch<ProgressStore>();
    final downloads = context.watch<DownloadStore>();
    final downloadState = downloads.stateOf(widget.course.slug);
    final downloading = downloadState?.status == DownloadStatus.downloading;
    final chapters = _detail?.chapters ?? const <ChapterRef>[];
    final total = chapters.isNotEmpty
        ? chapters.length
        : widget.course.chapterCount;
    final readCount = progress.readCount(widget.course.slug);
    final ratio = progress.progress(widget.course.slug, total);

    // 「继续观看/开始阅读」目标章：有进度跳上次读到的章，无进度跳第 1 章；
    // 详情未加载出章节时为 null（隐藏操作行）。
    final lastSlug = progress.lastChapter(widget.course.slug);
    final continueSlug = lastSlug ??
        (chapters.isNotEmpty ? chapters.first.slug : null);

    // 章节标题过滤（大小写不敏感）；搜索为空时显示全部。
    final keyword = _query.trim().toLowerCase();
    final visibleChapters = keyword.isEmpty
        ? chapters
        : chapters
              .where((c) => c.title.toLowerCase().contains(keyword))
              .toList();

    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: Text(widget.course.title),
        actions: [_DownloadButton(slug: widget.course.slug)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: colors.accent,
              backgroundColor: colors.card,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  if (downloading && downloadState != null) ...[
                    _DownloadProgressCard(state: downloadState),
                    const SizedBox(height: 16),
                  ],
                  _ProgressHeader(
                    summary: widget.course,
                    readCount: readCount,
                    total: total,
                    ratio: ratio,
                    continueTitle: progress.lastChapterTitle(
                      widget.course.slug,
                    ),
                    onContinue: continueSlug == null
                        ? null
                        : () => _openChapter(continueSlug),
                  ),
                  const SizedBox(height: 16),
                  _SearchField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () => setState(() {
                      _searchController.clear();
                      _query = '';
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (chapters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 40,
                            color: colors.inkMuted,
                          ),
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
                  else if (visibleChapters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          '没有匹配的章节',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.inkMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < visibleChapters.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ChapterTile(
                          // 无搜索词时序号 = 列表位置；过滤时用真实章节 order。
                          index: keyword.isEmpty
                              ? i + 1
                              : visibleChapters[i].order,
                          chapter: visibleChapters[i],
                          isRead: progress.isRead(
                            widget.course.slug,
                            visibleChapters[i].slug,
                          ),
                          onTap: () => _openChapter(visibleChapters[i].slug),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

/// 字节数展示：< 1 KB / x KB / x.x MB。
String _formatBytes(int bytes) {
  if (bytes < 1024) return '< 1 KB';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.round()} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

/// 课程页 appbar 下载按钮：idle=下载图标 / downloading=小菊花 / done=对勾。
/// done 再点 = 重新下载更新；下载中禁点。
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final store = context.watch<DownloadStore>();
    final state = store.stateOf(slug);
    final downloading = state?.status == DownloadStatus.downloading;
    final done = store.isDownloaded(slug);
    return IconButton(
      tooltip: downloading
          ? '正在下载'
          : done
          ? '已离线可用'
          : '下载离线包',
      onPressed: downloading ? null : () => _start(context),
      icon: downloading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            )
          : Icon(done ? Icons.check : Icons.download_outlined),
    );
  }

  Future<void> _start(BuildContext context) async {
    // await 前抓引用，避免异步后再碰 context。
    final messenger = ScaffoldMessenger.of(context);
    final store = context.read<DownloadStore>();
    await store.downloadCourse(slug);
    if (store.stateOf(slug)?.status != DownloadStatus.done) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('已下载，无网络也能看'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }
}

/// 下载中插在列表顶部的进度卡：标题 + mono 明细 + 细进度条。
class _DownloadProgressCard extends StatelessWidget {
  const _DownloadProgressCard({required this.state});

  final CourseDownloadState state;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '离线下载',
            style: TextStyle(
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 8),
          MonoText(
            '章节 ${state.chaptersDone}/${state.chaptersTotal}'
            ' · 图片 ${state.imagesDone}/${state.imagesTotal}'
            ' · ${_formatBytes(state.bytesReceived)}',
            color: colors.inkMuted,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 4,
              color: colors.accent,
              backgroundColor: colors.track,
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
    required this.continueTitle,
    required this.onContinue,
  });

  final CourseSummary summary;
  final int readCount;
  final int total;
  final double ratio;

  /// 上次阅读章节标题；null = 无进度（显示「开始阅读」）。
  final String? continueTitle;

  /// 操作行回调；null = 隐藏整行（如章节列表未加载）。
  final VoidCallback? onContinue;

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
              MonoText('$readCount/$total', color: colors.ink, fontSize: 20),
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
          if (onContinue != null) ...[
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onContinue,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        continueTitle == null
                            ? '开始阅读'
                            : '继续观看 · ${continueTitle!}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 章节搜索框：card 底圆角容器 + 搜索图标 + 清除按钮。
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: colors.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: colors.accent,
              style: TextStyle(fontSize: 15, color: colors.ink),
              decoration: InputDecoration(
                hintText: '搜索章节',
                hintStyle: TextStyle(fontSize: 15, color: colors.inkMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: '清除',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.cancel_rounded, size: 18, color: colors.inkMuted),
                onPressed: onClear,
              );
            },
          ),
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
