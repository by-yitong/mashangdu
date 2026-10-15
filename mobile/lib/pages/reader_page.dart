import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/api_client.dart';
import '../state/library_store.dart';
import '../state/progress_store.dart';
import '../state/reader_prefs.dart';
import '../widgets/code_block.dart';
import '../widgets/design.dart';
import '../widgets/offline_image.dart';

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
        builder: (_) =>
            ReaderPage(course: widget.course, chapterSlug: chapterSlug),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // watch：字号档位变化时正文即时重排（含弹层后的预览）。
    context.watch<ReaderPrefs>();
    final title = _chapter?.title ?? widget.course.title;

    final currentIndex = _chapters.indexWhere(
      (c) => c.slug == (_chapter?.slug ?? widget.chapterSlug),
    );
    final prev = currentIndex > 0 ? _chapters[currentIndex - 1] : null;
    final next = currentIndex >= 0 && currentIndex < _chapters.length - 1
        ? _chapters[currentIndex + 1]
        : null;
    // 当前章 order（后端缺失时为 0）拿不到就整行隐藏。
    final currentChapter = currentIndex >= 0 ? _chapters[currentIndex] : null;

    return Scaffold(
      backgroundColor: colors.paper,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentChapter != null &&
                  currentChapter.order > 0 &&
                  _chapters.isNotEmpty) ...[
                ProgressBar(value: currentChapter.order / _chapters.length),
                const SizedBox(height: 6),
                Center(
                  child: MonoText(
                    '第 ${currentChapter.order} / ${_chapters.length} 章',
                    color: colors.inkMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
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
            ],
          ),
        ),
      ),
      // 阅读沉浸:下滑正文时标题栏滚出屏幕,上滑立即浮回(floating+snap)。
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: '字号',
                icon: const Icon(Icons.format_size_rounded),
                onPressed: _showFontSizeSheet,
              ),
            ],
            floating: true,
            snap: true,
            pinned: false,
          ),
          _buildBody(context, colors),
        ],
      ),
    );
  }

  /// 字号选择面板：液态玻璃底部弹层，三档即时生效并持久化。
  void _showFontSizeSheet() {
    GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.4,
      builder: (sheetContext) => const _FontSizeSheet(),
    );
  }

  Widget _buildBody(BuildContext context, AppColors colors) {
    if (_loading && _chapter == null) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_notFound || _chapter == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colors.inkMuted,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _load(widget.chapterSlug, markRead: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accent,
                  side: BorderSide(color: colors.accent),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final prefs = context.watch<ReaderPrefs>();
    final styleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(fontSize: prefs.bodyFontSize, height: 1.7, color: colors.ink),
      h1: TextStyle(
        fontSize: prefs.h1FontSize,
        fontWeight: FontWeight.w700,
        color: colors.ink,
      ),
      h2: TextStyle(
        fontSize: prefs.h2FontSize,
        fontWeight: FontWeight.w700,
        color: colors.ink,
      ),
      h3: TextStyle(
        fontSize: prefs.h3FontSize,
        fontWeight: FontWeight.w700,
        color: colors.ink,
      ),
      h1Padding: const EdgeInsets.only(top: 8, bottom: 8),
      h2Padding: const EdgeInsets.only(top: 8, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 6, bottom: 4),
      listBullet: TextStyle(
        fontSize: prefs.bodyFontSize,
        height: 1.6,
        color: colors.ink,
      ),
      blockquote: TextStyle(
        fontSize: prefs.bodyFontSize - 1,
        height: 1.6,
        color: colors.inkMuted,
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.accentDim,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      code: MonoText.monoBase.copyWith(
        fontSize: prefs.codeFontSize,
        color: colors.accent,
        backgroundColor: colors.accentDim,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.track)),
      ),
      tableHead: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: colors.ink,
      ),
      tableBody: TextStyle(fontSize: 14, color: colors.ink),
      tableBorder: TableBorder.all(color: colors.track),
    );
    // Markdown 组件自带滚动容器，不能嵌进 CustomScrollView 的 sliver；
    // 用非滚动的 MarkdownBody，滚动统一交给外层 SliverAppBar + 列表。
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: MarkdownBody(
          data: _chapter!.contentMd,
          styleSheet: styleSheet,
          builders: {
            'pre': CodeBlockBuilder(fontSize: prefs.codeFontSize),
          },
          // 图片：优先读离线缓存，缺失时按需下载（与整课下载同一落盘规则）；
          // 相对路径经 ApiClient.resolve 拼到当前服务器地址。
          imageBuilder: (uri, title, alt) => OfflineImage(
            url: uri.toString(),
            alt: alt ?? '',
            resolver: (raw) => context.read<ApiClient>().resolve(raw),
          ),
          softLineBreak: true,
        ),
      ),
    );
  }
}

/// 字号选择面板（GlassModalSheet 内容）：三档胶囊行 + 右侧字号样张。
class _FontSizeSheet extends StatelessWidget {
  const _FontSizeSheet();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefs = context.watch<ReaderPrefs>();
    // GlassModalSheet 不提供 Material 祖先，InkWell 需自垫；
    // sheet 内容自垫 padding ≥ (20, 20, 20, 24)。
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读字号',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < ReaderPrefs.scales.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FontSizeOption(
                  label: const ['标准', '大', '特大'][i],
                  sampleFontSize: 16 * ReaderPrefs.scales[i],
                  selected: prefs.scale == ReaderPrefs.scales[i],
                  onTap: () => context
                      .read<ReaderPrefs>()
                      .setScale(ReaderPrefs.scales[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 单档字号行：选中 = accentDim 底 + accent 字；未选 = 透明底 + ink 字。
class _FontSizeOption extends StatelessWidget {
  const _FontSizeOption({
    required this.label,
    required this.sampleFontSize,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double sampleFontSize;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.accentDim : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.accent : colors.track,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? colors.accent : colors.ink,
                ),
              ),
            ),
            Text(
              'Aa',
              style: TextStyle(
                fontSize: sampleFontSize,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: selected ? colors.accent : colors.inkMuted,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: selected ? colors.accent : colors.inkMuted,
            ),
          ],
        ),
      ),
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
    final bg = enabled ? (primary ? colors.accent : colors.card) : colors.card;
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
