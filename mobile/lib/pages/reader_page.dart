import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/api_client.dart';
import '../state/library_store.dart';
import '../state/progress_store.dart';
import '../state/reader_prefs.dart';
import '../widgets/code_block.dart';
import '../widgets/design.dart';
import '../widgets/offline_image.dart';
import '../widgets/reading_theme.dart';

/// 阅读页：小说 App 式沉浸阅读。
///
/// Stack 分层：内容层（CustomScrollView，外层包全屏 translucent 手势层）
/// → 菜单层（顶/底半透明沉浸条，200ms 动画）→ 目录抽屉（Scaffold.drawer）。
///
/// 翻页为纵向平滑滚屏（非横向真分页，代码块永不被切断）：
/// - tap 模式：点右 1/3 或左滑 = 下一屏（末屏进下一章）；点左 1/3 或右滑 = 上一屏
///   （首页进上一章）；点中间 1/3 = 切换菜单层；
/// - scroll 模式：自由滚动，点中间 1/3 同样切换菜单层；
/// - 菜单层可见时，点任意处收起菜单。
///
/// 阅读主题/字号/行距/翻页模式走 [ReaderPrefs] + [ReadingTheme]；
/// 章节内进度按 offset/maxExtent 比例记忆（节流 500ms + 离页/切章兜底）。
/// 手势层是内容的手势祖先（translucent）：代码块复制按钮等子组件点击
/// 在手势竞技场中先于翻页手势加入，天然优先，不会被吞。
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scroll = ScrollController();

  /// 当前阅读进度比例（0~1），驱动菜单 Slider 与百分比（避免整页 setState）。
  final ValueNotifier<double> _ratio = ValueNotifier<double>(0);

  ChapterContent? _chapter;
  List<ChapterRef> _chapters = const [];
  bool _loading = true;
  bool _notFound = false;
  bool _menuVisible = false;

  /// Slider 拖动中：滚动监听暂不回写比例显示（拖动值优先）。
  bool _sliderActive = false;

  /// 章节加载序号：连续切章时丢弃过期加载结果。
  int _loadSeq = 0;

  /// 进度节流保存时间戳。
  int _lastSaveMs = 0;
  String _currentSlug = '';

  /// dispose 恢复系统栏用的全局样式（build 时按全局主题记录）。
  SystemUiOverlayStyle _globalOverlay = SystemUiOverlayStyle.light;

  /// 偏好引用：dispose 阶段不能用 context.read，didChangeDependencies 里抓一份。
  ReaderPrefs? _prefsRef;

  /// 进度节流保存间隔。
  static const int _saveIntervalMs = 500;

  /// 翻页边界判定容差（逻辑像素）。
  static const double _pageEpsilon = 2;

  /// 横滑翻页的释放速度阈值（px/s）。
  static const double _swipeVelocity = 300;

  /// 菜单条动画时长。
  static const Duration _menuDuration = Duration(milliseconds: 200);

  /// Slider 整数细分数（0~10000）。
  static const double _sliderSteps = 10000;

  @override
  void initState() {
    super.initState();
    _currentSlug = widget.chapterSlug;
    _scroll.addListener(_onScroll);
    _load(_currentSlug, markRead: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefsRef ??= context.read<ReaderPrefs>();
  }

  @override
  void dispose() {
    // 离开页面兜底保存一次进度，再释放资源。
    _savePositionNow();
    _scroll.dispose();
    _ratio.dispose();
    // 恢复全局主题样式（返回后各页 AppBar 也会自行声明，这里兜底）。
    SystemChrome.setSystemUIOverlayStyle(_globalOverlay);
    super.dispose();
  }

  // —— 数据加载与章节切换 ——

  Future<void> _load(String chapterSlug, {required bool markRead}) async {
    final library = context.read<LibraryStore>();
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _notFound = false;
    });

    // 课程详情（章节顺序做上一章/下一章/目录），失败不阻塞正文展示。
    final detail = await library.loadCourseDetail(widget.course.slug);
    final chapter = await library.loadChapter(widget.course.slug, chapterSlug);

    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _chapters = detail?.chapters ?? _chapters;
      _chapter = chapter;
      _loading = false;
      _notFound = chapter == null;
    });

    if (chapter == null) return;

    // 恢复该章上次保存的位置（无则到顶）；等首帧排版完成后 jumpTo。
    final ratio = context
        .read<ReaderPrefs>()
        .positionOf(widget.course.slug, chapter.slug);
    _scheduleRestore(ratio ?? 0);

    if (markRead) {
      await context.read<ProgressStore>().markRead(
        widget.course.slug,
        chapter.slug,
        chapter.title,
      );
    }
  }

  /// 首帧排版后按比例恢复位置；比例越界（内容变短等）按 0 处理。
  void _scheduleRestore(double ratio) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      var target = ratio <= 0 ? 0.0 : ratio * max;
      if (target.isNaN || target > max) target = 0;
      _scroll.jumpTo(target);
      _ratio.value = max <= 0 ? 0 : target / max;
    });
  }

  /// 页内切章（上一章/下一章/目录跳章）：不留路由记录，返回键仍回课程页。
  void _goChapter(String slug) {
    if (slug == _currentSlug) return;
    _savePositionNow();
    setState(() {
      _currentSlug = slug;
      _loading = true;
      _notFound = false;
    });
    _load(slug, markRead: true);
  }

  ChapterRef? get _prevChapter {
    final i = _chapters.indexWhere((c) => c.slug == _currentSlug);
    return i > 0 ? _chapters[i - 1] : null;
  }

  ChapterRef? get _nextChapter {
    final i = _chapters.indexWhere((c) => c.slug == _currentSlug);
    if (i < 0 || i >= _chapters.length - 1) return null;
    return _chapters[i + 1];
  }

  // —— 进度记忆 ——

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final max = position.maxScrollExtent;
    final ratio = max <= 0
        ? 0.0
        : (position.pixels / max).clamp(0.0, 1.0).toDouble();
    if (!_sliderActive) _ratio.value = ratio;

    // 节流保存（500ms 一次）；离页/切章另有兜底保存。
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSaveMs < _saveIntervalMs) return;
    _lastSaveMs = now;
    _savePosition(ratio);
  }

  void _savePositionNow() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final ratio = max <= 0
        ? 0.0
        : (_scroll.offset / max).clamp(0.0, 1.0).toDouble();
    _savePosition(ratio);
  }

  void _savePosition(double ratio) {
    final chapter = _chapter;
    final prefs = _prefsRef;
    if (chapter == null || prefs == null) return;
    prefs.savePosition(widget.course.slug, chapter.slug, ratio);
  }

  // —— 手势（tap 翻页 / 切换菜单） ——

  void _handleTapUp(TapUpDetails details) {
    if (_menuVisible) {
      _toggleMenu();
      return;
    }
    final prefs = context.read<ReaderPrefs>();
    final width = MediaQuery.sizeOf(context).width;
    final x = details.localPosition.dx;
    if (!prefs.tapPaging) {
      // 自由滚动模式：仅中间 1/3 切换菜单。
      if (x >= width / 3 && x <= width * 2 / 3) _toggleMenu();
      return;
    }
    if (x > width * 2 / 3) {
      _pageForward();
    } else if (x < width / 3) {
      _pageBackward();
    } else {
      _toggleMenu();
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_menuVisible) return;
    if (!context.read<ReaderPrefs>().tapPaging) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -_swipeVelocity) {
      _pageForward(); // 左滑 → 下一屏
    } else if (velocity > _swipeVelocity) {
      _pageBackward(); // 右滑 → 上一屏
    }
  }

  /// 下一屏（Kindle 平滑滚屏）；已到末屏则进下一章。
  void _pageForward() {
    if (_loading || _chapter == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    final max = position.maxScrollExtent;
    if (position.pixels >= max - _pageEpsilon) {
      final next = _nextChapter;
      if (next != null) _goChapter(next.slug);
      return;
    }
    _scroll.animateTo(
      math.min(position.pixels + position.viewportDimension, max),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 上一屏；已在首页则进上一章。
  void _pageBackward() {
    if (_loading || _chapter == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels <= _pageEpsilon) {
      final prev = _prevChapter;
      if (prev != null) _goChapter(prev.slug);
      return;
    }
    _scroll.animateTo(
      math.max(position.pixels - position.viewportDimension, 0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleMenu() => setState(() => _menuVisible = !_menuVisible);

  // —— 构建 ——

  @override
  Widget build(BuildContext context) {
    // watch：主题/字号/行距/翻页模式变化即时生效。
    final prefs = context.watch<ReaderPrefs>();
    final progress = context.watch<ProgressStore>();
    final theme = ReadingTheme.of(prefs.readingTheme);
    final title = _chapter?.title ?? widget.course.title;

    // 记录全局主题样式，dispose 时恢复（阅读页 overlay 见 AnnotatedRegion）。
    final globalColors = AppColors.of(context);
    _globalOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          globalColors.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarIconBrightness:
          globalColors.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.overlayStyle,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.bg,
        drawer: _buildDrawer(theme, progress),
        body: Stack(
          children: [
            // 内容层 + 手势层：GestureDetector 是内容的全屏手势祖先
            // （translucent），子组件点击（代码块复制等）在竞技场中优先。
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: _handleTapUp,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
                child: SafeArea(
                  bottom: false,
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      // 切章加载中：旧内容保持可见，顶部细进度条提示。
                      if (_loading && _chapter != null)
                        SliverToBoxAdapter(
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: theme.accent,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      _buildBody(theme, prefs),
                    ],
                  ),
                ),
              ),
            ),
            // 菜单层：顶栏 + 底栏，200ms 滑入滑出。
            _buildTopBar(theme, title),
            _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ReadingTheme theme, ReaderPrefs prefs) {
    if (_loading && _chapter == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: theme.accent)),
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
              Icon(Icons.cloud_off_rounded, size: 40, color: theme.textSecondary),
              const SizedBox(height: 12),
              Text(
                '章节内容加载失败',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '网络不可用且本地没有缓存，请稍后重试。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _load(_currentSlug, markRead: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.accent,
                  side: BorderSide(color: theme.accent),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final styleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(
        fontSize: prefs.bodyFontSize,
        height: prefs.lineHeight,
        color: theme.text,
      ),
      h1: TextStyle(
        fontSize: prefs.h1FontSize,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: theme.text,
      ),
      h2: TextStyle(
        fontSize: prefs.h2FontSize,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: theme.text,
      ),
      h3: TextStyle(
        fontSize: prefs.h3FontSize,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: theme.text,
      ),
      h1Padding: const EdgeInsets.only(top: 8, bottom: 8),
      h2Padding: const EdgeInsets.only(top: 8, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 6, bottom: 4),
      listBullet: TextStyle(
        fontSize: prefs.bodyFontSize,
        height: prefs.lineHeight,
        color: theme.text,
      ),
      blockquote: TextStyle(
        fontSize: prefs.bodyFontSize - 1,
        height: prefs.lineHeight,
        color: theme.textSecondary,
      ),
      blockquoteDecoration: BoxDecoration(
        color: theme.accentTint(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      code: MonoText.monoBase.copyWith(
        fontSize: prefs.codeFontSize,
        color: theme.accent,
        backgroundColor: theme.codeBg,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.divider)),
      ),
      tableHead: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: theme.text,
      ),
      tableBody: TextStyle(fontSize: 14, color: theme.text),
      tableBorder: TableBorder.all(color: theme.divider),
    );
    // Markdown 组件自带滚动容器，不能嵌进 CustomScrollView 的 sliver；
    // 用非滚动的 MarkdownBody，滚动统一交给外层列表 + 手势层。
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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

  /// 菜单顶栏：返回 / 章节标题（居中省略）/ 目录（开抽屉）。
  Widget _buildTopBar(ReadingTheme theme, String title) {
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedSlide(
        offset: _menuVisible ? Offset.zero : const Offset(0, -1),
        duration: _menuDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _menuVisible ? 1 : 0,
          duration: _menuDuration,
          child: IgnorePointer(
            ignoring: !_menuVisible,
            child: SafeArea(
              bottom: false,
              child: GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: theme.surfaceBarrier,
                    border: Border(bottom: BorderSide(color: theme.divider)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        icon: Icon(Icons.arrow_back_rounded, color: theme.text),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: theme.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '目录',
                        icon: Icon(
                          Icons.menu_book_rounded,
                          color: theme.text,
                        ),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 菜单底栏：行1 = 进度 Slider + mono 百分比；行2 = 上一章/目录/Aa 设置/下一章；
  /// Slider 下方 mono 小字显示“第 X / Y 章”。
  Widget _buildBottomBar(ReadingTheme theme) {
    final prev = _prevChapter;
    final next = _nextChapter;
    final currentIndex = _chapters.indexWhere((c) => c.slug == _currentSlug);
    final currentChapter = currentIndex >= 0 ? _chapters[currentIndex] : null;
    final disabledColor = theme.textSecondary.withValues(alpha: 0.45);

    TextButton navButton(
      String label, {
      required bool enabled,
      required VoidCallback? onTap,
    }) {
      return TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: enabled ? theme.text : disabledColor,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedSlide(
        offset: _menuVisible ? Offset.zero : const Offset(0, 1),
        duration: _menuDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _menuVisible ? 1 : 0,
          duration: _menuDuration,
          child: IgnorePointer(
            ignoring: !_menuVisible,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  decoration: BoxDecoration(
                    color: theme.surfaceBarrier,
                    border: Border(top: BorderSide(color: theme.divider)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<double>(
                        valueListenable: _ratio,
                        builder: (context, ratio, _) => Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: (ratio * _sliderSteps).clamp(
                                  0,
                                  _sliderSteps,
                                ),
                                max: _sliderSteps,
                                activeColor: theme.accent,
                                inactiveColor: theme.divider,
                                thumbColor: theme.accent,
                                onChanged: _onSliderChanged,
                                onChangeStart: (_) => _sliderActive = true,
                                onChangeEnd: (_) {
                                  _sliderActive = false;
                                  _savePositionNow();
                                },
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: MonoText(
                                  '${(ratio * 100).round()}%',
                                  color: theme.text,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          navButton(
                            '上一章',
                            enabled: prev != null,
                            onTap: prev == null ? null : () => _goChapter(prev.slug),
                          ),
                          navButton(
                            '目录',
                            enabled: true,
                            onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          ),
                          navButton(
                            'Aa 设置',
                            enabled: true,
                            onTap: _showSettingsSheet,
                          ),
                          navButton(
                            '下一章',
                            enabled: next != null,
                            onTap: next == null ? null : () => _goChapter(next.slug),
                          ),
                        ],
                      ),
                      if (currentChapter != null &&
                          currentChapter.order > 0 &&
                          _chapters.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: MonoText(
                            '第 ${currentChapter.order} / ${_chapters.length} 章',
                            color: theme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Slider 拖动：0~10000 整数细分，拖动即滚动到对应位置。
  void _onSliderChanged(double value) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final ratio = value / _sliderSteps;
    _scroll.jumpTo((ratio * max).clamp(0.0, max).toDouble());
    _ratio.value = ratio;
  }

  /// 目录抽屉：整课章节列表（详情缺失时占位），当前章 accent 高亮 + 已读打勾，
  /// 点击跳章并恢复该章保存位置（无则到顶）。
  Widget _buildDrawer(ReadingTheme theme, ProgressStore progress) {
    final detail = context.read<LibraryStore>().cachedDetail(widget.course.slug);
    final chapters = detail?.chapters ?? _chapters;
    return Drawer(
      backgroundColor: theme.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                '目录',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                ),
              ),
            ),
            Divider(height: 1, color: theme.divider),
            Expanded(
              child: chapters.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          '章节列表暂不可用',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: chapters.length,
                      itemBuilder: (context, i) {
                        final chapter = chapters[i];
                        final isCurrent = chapter.slug == _currentSlug;
                        final isRead = progress.isRead(
                          widget.course.slug,
                          chapter.slug,
                        );
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            _goChapter(chapter.slug);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isRead
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: isCurrent
                                      ? theme.accent
                                      : theme.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    chapter.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isCurrent
                                          ? theme.accent
                                          : theme.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 阅读设置面板：翻页模式 / 字号步进 / 行距 / 背景主题，改动即时生效并持久化。
  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _ReadingSettingsSheet(),
    );
  }
}

/// 阅读设置面板（showModalBottomSheet 内容）：背景色/圆角 22 自绘，
/// watch ReaderPrefs 使主题切换在面板内也即时生效。
class _ReadingSettingsSheet extends StatelessWidget {
  const _ReadingSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<ReaderPrefs>();
    final theme = ReadingTheme.of(prefs.readingTheme);
    var scaleIndex = ReaderPrefs.scales.indexOf(prefs.scale);
    if (scaleIndex < 0) scaleIndex = 0;
    final segStyle = SegmentedButton.styleFrom(
      backgroundColor: Colors.transparent,
      selectedBackgroundColor: theme.accentTint(0.12),
      foregroundColor: theme.textSecondary,
      selectedForegroundColor: theme.accent,
      side: BorderSide(color: theme.divider),
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '阅读设置',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                ),
              ),
              _SectionLabel('翻页', theme),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'scroll', label: Text('自由滚动')),
                  ButtonSegment(value: 'tap', label: Text('点击翻页')),
                ],
                selected: {prefs.pageMode},
                showSelectedIcon: false,
                style: segStyle,
                onSelectionChanged: (selection) =>
                    context.read<ReaderPrefs>().setPageMode(selection.first),
              ),
              _SectionLabel('字号', theme),
              Row(
                children: [
                  _StepButton(
                    icon: Icons.text_decrease_rounded,
                    tooltip: '减小字号',
                    enabled: scaleIndex > 0,
                    theme: theme,
                    onTap: () => context
                        .read<ReaderPrefs>()
                        .setScale(ReaderPrefs.scales[scaleIndex - 1]),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${prefs.label} · ${prefs.bodyFontSize.round()}',
                        style: TextStyle(fontSize: 15, color: theme.text),
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.text_increase_rounded,
                    tooltip: '增大字号',
                    enabled: scaleIndex < ReaderPrefs.scales.length - 1,
                    theme: theme,
                    onTap: () => context
                        .read<ReaderPrefs>()
                        .setScale(ReaderPrefs.scales[scaleIndex + 1]),
                  ),
                ],
              ),
              _SectionLabel('行距', theme),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 1.4, label: Text('紧凑')),
                  ButtonSegment(value: 1.6, label: Text('标准')),
                  ButtonSegment(value: 1.8, label: Text('宽松')),
                ],
                selected: {prefs.lineHeight},
                showSelectedIcon: false,
                style: segStyle,
                onSelectionChanged: (selection) => context
                    .read<ReaderPrefs>()
                    .setLineHeight(selection.first),
              ),
              _SectionLabel('背景', theme),
              Row(
                children: [
                  for (final t in ReadingTheme.all)
                    Expanded(
                      child: _ThemeSwatch(
                        swatch: t,
                        selected: prefs.readingTheme == t.id,
                        selectedColor: theme.accent,
                        ringColor: theme.divider,
                        onTap: () =>
                            context.read<ReaderPrefs>().setReadingTheme(t.id),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置面板分区标签。
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.theme);

  final String text;
  final ReadingTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.textSecondary,
        ),
      ),
    );
  }
}

/// 字号步进按钮（A− / A+ 圆形描边）。
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final ReadingTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? theme.text
        : theme.textSecondary.withValues(alpha: 0.4);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled
                  ? theme.divider
                  : theme.divider.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

/// 背景主题圆形色块：选中描当前主题 accent 边 + 打勾。
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.swatch,
    required this.selected,
    required this.selectedColor,
    required this.ringColor,
    required this.onTap,
  });

  final ReadingTheme swatch;
  final bool selected;
  final Color selectedColor;
  final Color ringColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: swatch.bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? selectedColor : ringColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 18, color: swatch.text)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            swatch.label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? selectedColor : swatch.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
