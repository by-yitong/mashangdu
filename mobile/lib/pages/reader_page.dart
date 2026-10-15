import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/library_store.dart';
import '../state/progress_store.dart';
import '../widgets/code_block.dart';
import '../widgets/design.dart';

/// 阅读页：Markdown 正文 + 代码块复制 + 底部上一章/下一章；打开即记已读。
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.course,
    required this.chapterSlug,
  });

  final CourseSummary course;
  final String chapterSlug;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  ChapterContent? _chapter;
  List<ChapterRef> _chapters = const [];
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load(widget.chapterSlug, markRead: true);
  }

  Future<void> _load(String chapterSlug, {required bool markRead}) async {
    final library = context.read<LibraryStore>();
    setState(() {
      _loading = true;
      _notFound = false;
    });

    // 课程详情（拿章节顺序做上一章/下一章），失败不阻塞正文展示。
    final detail = await library.loadCourseDetail(widget.course.slug);
    final chapter = await library.loadChapter(widget.course.slug, chapterSlug);

    if (!mounted) return;
    setState(() {
      _chapters = detail?.chapters ?? _chapters;
      _chapter = chapter;
      _loading = false;
      _notFound = chapter == null;
    });

    if (chapter != null && markRead) {
      await context.read<ProgressStore>().markRead(
            widget.course.slug,
            chapter.slug,
            chapter.title,
          );
    }
  }

  void _switchTo(String chapterSlug) {
    // 替换当前路由：返回键回到课程页。
    Navigator.of(context).pushReplacement(
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
    final title = _chapter?.title ?? widget.course.title;

    final currentIndex = _chapters
        .indexWhere((c) => c.slug == (_chapter?.slug ?? widget.chapterSlug));
    final prev = currentIndex > 0 ? _chapters[currentIndex - 1] : null;
    final next = currentIndex >= 0 && currentIndex < _chapters.length - 1
        ? _chapters[currentIndex + 1]
        : null;

    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _NavButton(
                  label: '上一章',
                  target: prev?.title,
                  enabled: prev != null,
                  onTap: prev == null ? null : () => _switchTo(prev.slug),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NavButton(
                  label: '下一章',
                  target: next?.title,
                  enabled: next != null,
                  primary: true,
                  onTap: next == null ? null : () => _switchTo(next.slug),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(context, colors),
    );
  }

  Widget _buildBody(BuildContext context, AppColors colors) {
    if (_loading && _chapter == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notFound || _chapter == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: colors.inkMuted),
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
                '网络不可用且本地没有缓存，请稍后重试。',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, height: 1.5, color: colors.inkMuted),
              ),
            ],
          ),
        ),
      );
    }
    final styleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(fontSize: 16, height: 1.7, color: colors.ink),
      h1: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: colors.ink),
      h2: TextStyle(
          fontSize: 21, fontWeight: FontWeight.w700, color: colors.ink),
      h3: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: colors.ink),
      h1Padding: const EdgeInsets.only(top: 8, bottom: 8),
      h2Padding: const EdgeInsets.only(top: 8, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 6, bottom: 4),
      listBullet: TextStyle(fontSize: 16, height: 1.6, color: colors.ink),
      blockquote: TextStyle(
          fontSize: 15, height: 1.6, color: colors.inkMuted),
      blockquoteDecoration: BoxDecoration(
        color: colors.accentDim,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      code: MonoText.monoBase.copyWith(
        fontSize: 13.5,
        color: colors.accent,
        backgroundColor: colors.accentDim,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.track)),
      ),
      tableHead: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink),
      tableBody: TextStyle(fontSize: 14, color: colors.ink),
      tableBorder: TableBorder.all(color: colors.track),
    );
    return Markdown(
      data: _chapter!.contentMd,
      styleSheet: styleSheet,
      builders: {'pre': CodeBlockBuilder()},
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      softLineBreak: true,
    );
  }
}

/// 上一章/下一章按钮。
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.target,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final String? target;
  final bool enabled;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bg = enabled
        ? (primary ? colors.accent : colors.card)
        : colors.card;
    final titleColor = enabled
        ? (primary ? colors.onAccent : colors.inkMuted)
        : colors.inkMuted.withValues(alpha: 0.5);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: primary && enabled ? titleColor : colors.inkMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  target ?? '没有了',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: titleColor,
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
