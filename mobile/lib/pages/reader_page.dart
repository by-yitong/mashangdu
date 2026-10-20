import 'dart:async' as async;
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/api_client.dart';
import '../state/auth_store.dart';
import '../state/library_store.dart';
import '../state/progress_store.dart';
import '../state/reader_prefs.dart';
import '../state/resume_store.dart';
import '../utils/drawer_snap.dart';
import '../utils/relative_time.dart' show formatHm;
import '../widgets/chapter_interaction.dart';
import '../widgets/code_block.dart';
import '../widgets/design.dart';
import '../widgets/offline_image.dart';
import '../widgets/reading_theme.dart';

/// 阅读页：小说 App 式沉浸阅读（immersiveSticky 沉浸式系统栏）。
///
/// Stack 分层：内容层（CustomScrollView，外层包全屏 translucent 手势层）
/// → 目录起手区（左 24px 竖条，仅横向拖动）→ 过卷翻章胶囊（IgnorePointer，
/// 菜单层之下）→ 底部融入式状态条（IgnorePointer）→ 菜单层（顶/底半透明
/// 沉浸条，200ms 动画）→ 目录层（自绘面板：遮罩 + 左侧 86% 宽面板，
/// 右滑 1:1 跟手、松手速度+位置双判定 250ms easeOutCubic 吸附）。
///
/// 翻页为纵向平滑滚屏（非横向真分页，代码块永不被切断）：
/// - tap 模式：点右 1/3 或左滑 = 下一屏（末屏进下一章）；点左 1/3 或右滑 = 上一屏
///   （首页进上一章）；点中间 1/3 = 切换菜单层；
/// - scroll 模式：自由滚动，点中间 1/3 同样切换菜单层；
/// - 到底/到顶继续拖拽：TG 式过卷胶囊，刻意慢拉累计 200 逻辑像素松手翻章
///   （快速甩动不计入）；下一章提示在页面底部、上一章在顶部
///   （dragDetails 为空 = 惯性滚动，不参与累计；首/末章对应方向只提示不导航）；
/// - 菜单层可见时，点任意处收起菜单。
///
/// 阅读主题/字号/行距/翻页模式走 [ReaderPrefs] + [ReadingTheme]，主题档
/// 'auto' 时按 App 深浅色取记忆槽（Theme.of(context).brightness 变化即时跟随）；
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

class _ReaderPageState extends State<ReaderPage> with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();

  /// 当前阅读进度比例（0~1），驱动菜单 Slider 与百分比（避免整页 setState）。
  final ValueNotifier<double> _ratio = ValueNotifier<double>(0);

  ChapterContent? _chapter;
  List<ChapterRef> _chapters = const [];
  bool _loading = true;

  /// 首次阅读指引本次会话是否已关闭（持久记忆见 ReaderPrefs.coachShown）。
  bool _coachVisible = true;
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

  /// 启动恢复记录引用（同 _prefsRef 模式）：进入/切章写 `resume.*`，
  /// 退出阅读页清除——记录只在"停留在阅读页时被杀进程"才留存。
  ResumeStore? _resumeRef;

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

  /// 过卷翻章触发阈值（逻辑像素）。
  /// 过卷翻章阈值：需刻意慢拉累计 200 逻辑像素松手才翻章。
  static const double _flipThreshold = 200;

  /// 甩动守卫：单帧过卷超过此值视为快速甩动（惯性到边），不计入累计，
  /// 避免快速滑动碰到底部就瞬间翻章。
  static const double _flipFlickGuard = 24;

  /// 过卷翻章胶囊状态（ValueNotifier 驱动，避免拖拽期间整页 setState）。
  final ValueNotifier<_FlipHint> _flipHint = ValueNotifier<_FlipHint>(
    const _FlipHint.initial(),
  );

  /// 翻章触发时胶囊跳过消失动画（立即隐藏）。
  bool _flipHideInstant = false;

  // —— 自绘目录面板（替代 Scaffold.drawer） ——

  /// 开合进度 0..1（0 关、1 开）：拖动 1:1 写 value，松手 animateTo 吸附。
  late final AnimationController _drawerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 0,
  );

  /// 目录起手区宽度（屏幕左侧竖条，逻辑像素）。
  static const double _drawerEdgeWidth = 24;

  /// 面板宽度占屏宽比例。
  static const double _drawerWidthFactor = 0.86;

  /// 面板像素宽（didChangeDependencies 里刷新；拖动回调直接读缓存，
  /// 不在手势回调里查 MediaQuery）。
  double _drawerWidthPx = 0;

  double get _drawerPanelWidth => _drawerWidthPx;

  bool get _isDrawerOpen => _drawerCtrl.value > 0;

  void _openDrawerPanel() => _animateDrawer(to: 1);

  void _closeDrawerPanel() => _animateDrawer(to: 0);

  /// 250ms easeOutCubic 吸附动画（按钮开启 / 松手判定 / 遮罩点按共用）。
  void _animateDrawer({required double to}) {
    _drawerCtrl.animateTo(
      to.clamp(0.0, 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// 拖动 1:1 跟手：dx / 面板宽 → 开启度增量（起手区与遮罩共用）。
  void _onDrawerDragUpdate(DragUpdateDetails details) {
    _drawerCtrl.value =
        (_drawerCtrl.value + details.delta.dx / _drawerPanelWidth).clamp(
          0.0,
          1.0,
        );
  }

  /// 松手：速度优先（≥600px/s 甩动）、位置兜底（≥0.5）。
  void _onDrawerDragEnd(DragEndDetails details) {
    _animateDrawer(
      to: drawerSnapOpen(_drawerCtrl.value, details.velocity.pixelsPerSecond.dx)
          ? 1
          : 0,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentSlug = widget.chapterSlug;
    // didChangeDependencies 在 initState 之后才跑，这里先抓一次引用
    // （context.read 无依赖注册，initState 可用，见 app.dart 同款做法），
    // 写入启动恢复记录：停留在阅读页被杀进程时，下次启动恢复到本章。
    _resumeRef ??= context.read<ResumeStore>();
    _resumeRef?.enterReading(widget.course, widget.chapterSlug);
    _scroll.addListener(_onScroll);
    // 沉浸式阅读：状态栏/导航栏隐藏（下滑可临时呼出）。
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    _load(_currentSlug, markRead: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefsRef ??= context.read<ReaderPrefs>();
    _resumeRef ??= context.read<ResumeStore>();
    _drawerWidthPx = MediaQuery.sizeOf(context).width * _drawerWidthFactor;
  }

  @override
  void dispose() {
    // 离开页面兜底保存一次进度，再释放资源。
    _savePositionNow();
    // 正常返回（回课程页/首页）即清除启动恢复记录：dispose 在进程被杀时
    // 不会执行，这正是"记录只代表退出时停留在阅读页"的关键。
    // dispose 同步路径不能 await，fire-and-forget。
    async.unawaited(_resumeRef?.exitReading());
    _scroll.dispose();
    _ratio.dispose();
    _flipHint.dispose();
    _drawerCtrl.dispose();
    // 恢复全局主题样式（返回后各页 AppBar 也会自行声明，这里兜底）+
    // 退出沉浸模式，确保课程页状态栏正常回来。
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    final ratio = context.read<ReaderPrefs>().positionOf(
      widget.course.slug,
      chapter.slug,
    );
    _scheduleRestore(ratio ?? 0);

    if (markRead) {
      // 依赖先取引用再 await（BuildContext 不跨异步间隙使用）。
      final progressStore = context.read<ProgressStore>();
      final authStore = context.read<AuthStore>();
      final api = context.read<ApiClient>();
      await progressStore.markRead(
        widget.course.slug,
        chapter.slug,
        chapter.title,
      );
      // 云端观看历史上报：已登录才发，fire-and-forget，失败静默不影响阅读。
      if (authStore.isLoggedIn) {
        async.unawaited(
          api
              .putRecord(widget.course.slug, chapter.slug, chapter.title)
              .catchError((Object _) {}),
        );
      }
      // 阅读量上报：无需登录（未登录也计入），recordView 内部吞掉异常，
      // 同样 fire-and-forget，离线/失败静默。
      async.unawaited(api.recordView(widget.course.slug, chapter.slug));
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
    // 同步启动恢复记录到新章（进程被杀时恢复到最近停留的章）。
    _resumeRef?.enterReading(widget.course, slug);
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

  // —— 过卷翻章（TG 式过卷提示） ——

  /// 过卷累计：仅在用户拖拽（dragDetails 非空）时生效，惯性滚动忽略。
  /// Flutter 约定：越过 maxScrollExtent 时 overscroll 为正、越过 min 为负，
  /// 即底部继续上拉 → 下一章；顶部对称（继续下拉）→ 上一章；换向清零。
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is OverscrollNotification) {
      if (notification.dragDetails == null) return false;
      if (_loading || _chapter == null) return false;
      if (notification.overscroll.abs() > _flipFlickGuard) return false;
      final metrics = notification.metrics;
      final atBottom =
          notification.overscroll > 0 &&
          metrics.pixels >= metrics.maxScrollExtent - _pageEpsilon;
      final atTop =
          notification.overscroll < 0 &&
          metrics.pixels <= metrics.minScrollExtent + _pageEpsilon;
      if (!atBottom && !atTop) return false;
      final direction = atBottom ? 1 : -1;
      final current = _flipHint.value;
      final amount = current.direction == direction
          ? current.amount + notification.overscroll.abs()
          : notification.overscroll.abs();
      final target = direction > 0 ? _nextChapter : _prevChapter;
      _flipHideInstant = false;
      _flipHint.value = _FlipHint(
        direction: direction,
        amount: amount,
        blocked: target == null,
        title: target?.title ?? '',
        visible: true,
      );
    } else if (notification is ScrollEndNotification) {
      final current = _flipHint.value;
      if (current.direction == 0) return false;
      if (current.visible && current.progress >= 1 && !current.blocked) {
        // 达到阈值：立即隐藏胶囊并翻章（复用 _goChapter 的加载过渡）。
        _flipHideInstant = true;
        _flipHint.value = _FlipHint(
          direction: current.direction,
          amount: current.amount,
          blocked: current.blocked,
          title: current.title,
          visible: false,
        );
        final target = current.direction > 0 ? _nextChapter : _prevChapter;
        if (target != null && !_loading) _goChapter(target.slug);
      } else {
        // 未达阈值/灰态：播放消失动画收起，累计清零。
        _flipHideInstant = false;
        _flipHint.value = _FlipHint(
          direction: current.direction,
          amount: 0,
          blocked: current.blocked,
          title: current.title,
          visible: false,
        );
      }
    }
    return false;
  }

  /// 过卷翻章胶囊：方向决定位置——下一章从页面底部浮出（内容从下方来），
  /// 上一章在顶部浮出；菜单层之下、IgnorePointer。底部胶囊要避开
  /// 状态条 HUD 区（28px + 余量），左右各留 20px——部分设备屏幕
  /// 底部为圆角，贴边会被弯边裁切。不用 SafeArea——沉浸模式下它
  /// 仍会虚占已隐藏系统栏的高度。
  Widget _buildFlipHint(ReadingTheme theme) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: ValueListenableBuilder<_FlipHint>(
          valueListenable: _flipHint,
          builder: (context, hint, _) {
            // TweenAnimationBuilder 常驻：首次显示时 tween end 由 0 变 1，
            // 才会播放 140ms 出现动画（新挂载会直接跳到终值）。
            final isNext = hint.direction > 0;
            final fromBelow = isNext;
            final card = hint.direction == 0
                ? const SizedBox.shrink()
                : _buildFlipHintCard(hint, theme);
            return Align(
              alignment: isNext ? Alignment.bottomCenter : Alignment.topCenter,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: hint.visible ? 1.0 : 0.0),
                duration: hint.visible
                    ? const Duration(milliseconds: 140)
                    : (_flipHideInstant
                          ? Duration.zero
                          : const Duration(milliseconds: 120)),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    // 底部胶囊从下方 12px 滑入，顶部胶囊从上方滑入。
                    offset: Offset(0, (fromBelow ? 12 : -12) * (1 - t)),
                    child: child,
                  ),
                ),
                child: card,
              ),
            );
          },
        ),
      ),
    );
  }

  /// 胶囊本体：圆角 999、bg 92% 不透明 + divider 描边 + 轻阴影；
  /// 两行文字（主 13 w500 / 副 12 sec 目标章标题）+ 底部 3px accent 进度条。
  Widget _buildFlipHintCard(_FlipHint hint, ReadingTheme theme) {
    final gray = hint.blocked;
    final mainColor = gray ? theme.textSecondary : theme.text;
    final barColor = gray
        ? theme.textSecondary.withValues(alpha: 0.5)
        : theme.accent;
    final mainText = gray
        ? (hint.direction > 0 ? '已是最后一章' : '已是第一章')
        : (hint.direction > 0 ? '松开进入下一章' : '松开回到上一章');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        decoration: BoxDecoration(
          color: theme.bg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 11),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mainText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: mainColor,
                      ),
                    ),
                    if (!gray && hint.title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 底部内嵌 3px 进度条：宽度 = 累计/阈值。
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: hint.progress,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // —— 构建 ——

  @override
  Widget build(BuildContext context) {
    // watch：主题/字号/行距/翻页模式变化即时生效；Theme.of 依赖使
    // App 外观（themeMode）切换时阅读页即时跟随 auto 档深浅色。
    final appBrightness = Theme.of(context).brightness;
    final prefs = context.watch<ReaderPrefs>();
    final progress = context.watch<ProgressStore>();
    final theme = ReadingTheme.of(prefs.effectiveReadingTheme(appBrightness));
    final title = _chapter?.title ?? widget.course.title;

    // 记录全局主题样式，dispose 时恢复（阅读页 overlay 见 AnnotatedRegion）。
    final globalColors = AppColors.of(context);
    _globalOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: globalColors.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarIconBrightness:
          globalColors.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    );

    // 状态条章节序号（与底栏「第 X / Y 章」同源）。
    final chapterIndex = _chapters.indexWhere((c) => c.slug == _currentSlug);
    final orderText = chapterIndex >= 0 && _chapters.isNotEmpty
        ? '${_chapters[chapterIndex].order}/${_chapters.length}'
        : '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.overlayStyle,
      // 面板开合只重建 PopScope 包装；Scaffold 作为 child 传入，正文不重建。
      child: ListenableBuilder(
        listenable: _drawerCtrl,
        child: Scaffold(
          backgroundColor: theme.bg,
          body: Stack(
            children: [
              // 内容层 + 手势层：GestureDetector 是内容的全屏手势祖先
              // （translucent），子组件点击（代码块复制等）在竞技场中优先；
              // NotificationListener 承接过卷翻章（tap/scroll 模式共享同一
              // ScrollView，行为一致）。
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: _handleTapUp,
                  onHorizontalDragEnd: _handleHorizontalDragEnd,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    // 沉浸式下系统栏已隐藏，SafeArea 仍会预留状态栏高度，
                    // 顶部出现空白段——正文直接铺到屏幕顶缘；底部让出
                    // 状态条 HUD 区（时间/电量/进度），文字永不滚入遮挡。
                    // HUD 实占 ~23px（11 号字 + 底距 10），28 留少量余量。
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: CustomScrollView(
                        controller: _scroll,
                        // 短章（内容不满一屏）时 maxScrollExtent 为 0，默认物理
                        // 会拒绝拖拽、过卷通知不发出 → 强制接受，保证短章也能
                        // 拉出翻章提示。
                        physics: const _AlwaysAcceptDragPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
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
                          // 顶部呼吸间距放在滚动区内部：章首有留白，
                          // 上滑时随内容一起推走，不占常驻屏幕。
                          SliverPadding(
                            padding: const EdgeInsets.only(top: 20),
                            sliver: _buildBody(theme, prefs),
                          ),
                          // 章节末互动区：随正文滚动（不悬浮），按章节 slug
                          // 挂 key——切章即重挂载、互动状态重置；配色走
                          // ReadingTheme。章节未就绪（加载中/失败页）不显示。
                          if (_chapter != null)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                              sliver: SliverToBoxAdapter(
                                child: ChapterInteraction(
                                  key: ValueKey('interaction-${_chapter!.slug}'),
                                  courseSlug: widget.course.slug,
                                  chapterSlug: _chapter!.slug,
                                  theme: theme,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 目录起手区：左侧 24px 竖条，只挂横向拖动（translucent 不拦截
              // 该区域点击翻页/代码块点击）；其余区域的横向甩动仍走上面的
              // 过卷/翻章手势，互不影响。
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: _drawerEdgeWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: _onDrawerDragUpdate,
                  onHorizontalDragEnd: _onDrawerDragEnd,
                ),
              ),
              // 过卷翻章胶囊：菜单层之下，IgnorePointer 不挡任何点击。
              _buildFlipHint(theme),
              // 底部融入式状态条：IgnorePointer，菜单层打开时隐藏。
              _buildReaderStatusBar(theme, orderText),
              // 菜单层：顶栏 + 底栏，200ms 滑入滑出。
              _buildTopBar(theme, title),
              _buildBottomBar(theme),
              // 首次阅读指引：点按分区教学，展示一次。
              if (_coachVisible && !prefs.coachShown)
                Positioned.fill(child: _buildCoachOverlay(theme, prefs)),
              // 目录层：遮罩 + 左侧面板（自绘，替代 Scaffold.drawer）。
              _buildDrawerLayer(theme, progress),
            ],
          ),
        ),
        builder: (context, child) => PopScope(
          // 面板开着时返回键先收面板，再退页。
          canPop: !_isDrawerOpen,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _closeDrawerPanel();
          },
          child: child!,
        ),
      ),
    );
  }

  /// 底部状态条容器（定位于 Stack 底部、永不参与命中测试）。
  Widget _buildReaderStatusBar(ReadingTheme theme, String orderText) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: _ReaderStatusBar(
          ratio: _ratio,
          orderText: orderText,
          title: _chapter?.title ?? '',
          visible: !_menuVisible,
          color: theme.textSecondary,
          background: theme.bg,
        ),
      ),
    );
  }

  /// 目录层：遮罩（黑 alpha 随开度 0→0.4，点按/横拖关闭）+ 左侧面板
  /// （86% 屏宽，Transform.translate 滑入）。拖动与动画只驱动 Transform /
  /// 遮罩透明度——面板内容作为 AnimatedBuilder 的 child 复用，正文层不重建。
  Widget _buildDrawerLayer(ReadingTheme theme, ProgressStore progress) {
    return AnimatedBuilder(
      animation: _drawerCtrl,
      child: _buildDrawerPanel(theme, progress),
      builder: (context, panel) {
        final t = _drawerCtrl.value;
        return IgnorePointer(
          ignoring: t <= 0,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeDrawerPanel,
                  onHorizontalDragUpdate: _onDrawerDragUpdate,
                  onHorizontalDragEnd: _onDrawerDragEnd,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.4 * t),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: _drawerPanelWidth,
                child: Transform.translate(
                  offset: Offset(-_drawerPanelWidth * (1 - t), 0),
                  child: panel,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 目录面板本体：theme.bg 底 + 右侧圆角 22 + 细描边 + 轻阴影（菜单层同
  /// 风格）；当前章 accent 高亮 + 已读打勾，点击收面板并跳章（恢复该章
  /// 保存位置，无则到顶）。
  Widget _buildDrawerPanel(ReadingTheme theme, ProgressStore progress) {
    final detail = context.read<LibraryStore>().cachedDetail(
      widget.course.slug,
    );
    final chapters = detail?.chapters ?? _chapters;
    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(22)),
        border: Border(right: BorderSide(color: theme.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(6, 0),
          ),
        ],
      ),
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
                            _closeDrawerPanel();
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

  /// 首次阅读指引：半透明遮罩 + 左中右分区说明，点任意处消失并记忆。
  Widget _buildCoachOverlay(ReadingTheme theme, ReaderPrefs prefs) {
    Widget zone({
      required IconData icon,
      required String title,
      required String subtitle,
    }) => Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: theme.accent),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _coachVisible = false);
        prefs.markCoachShown();
      },
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.58),
        child: Column(
          children: [
            const Spacer(),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  zone(icon: Icons.west, title: '上一页', subtitle: '点击左侧区域'),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  zone(
                    icon: Icons.touch_app_outlined,
                    title: '菜单',
                    subtitle: '点击中间区域\n目录 · 设置 · 进度',
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  zone(icon: Icons.east, title: '下一页', subtitle: '点击右侧区域'),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                children: [
                  Text(
                    prefs.pageMode == 'tap'
                        ? '上下滑动也可翻页 · 滚到底继续拉动进入下一章'
                        : '上下滑动自由阅读 · 滚到底继续拉动进入下一章',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '点击任意处开始阅读',
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
              Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: theme.textSecondary,
              ),
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
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
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
    // 底部仅留小间距：正文之后紧跟章节末互动区，滚动尾部留白由互动区
    // 的 sliver padding 承担。
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: MarkdownBody(
          data: _chapter!.contentMd,
          styleSheet: styleSheet,
          builders: {
            'pre': CodeBlockBuilder(
              fontSize: prefs.codeFontSize,
              readingTheme: theme,
            ),
          },
          // 图片：优先读离线缓存，缺失时按需下载（与整课下载同一落盘规则）；
          // 相对路径经 ApiClient.resolve 拼到当前服务器地址。
          sizedImageBuilder: (config) => OfflineImage(
            url: config.uri.toString(),
            alt: config.alt ?? '',
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
                        icon: Icon(Icons.menu_book_rounded, color: theme.text),
                        onPressed: _openDrawerPanel,
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
                            onTap: prev == null
                                ? null
                                : () => _goChapter(prev.slug),
                          ),
                          navButton(
                            '目录',
                            enabled: true,
                            onTap: _openDrawerPanel,
                          ),
                          navButton(
                            'Aa 设置',
                            enabled: true,
                            onTap: _showSettingsSheet,
                          ),
                          navButton(
                            '下一章',
                            enabled: next != null,
                            onTap: next == null
                                ? null
                                : () => _goChapter(next.slug),
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

  /// 阅读设置面板：翻页模式 / 字号步进 / 行距 / 主题（自动 + 7 档），
  /// 改动即时生效并持久化。
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
    // 面板内取色同样走 effective 主题（auto 档跟随 App 深浅色）。
    final theme = ReadingTheme.of(
      prefs.effectiveReadingTheme(Theme.of(context).brightness),
    );
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
                    onTap: () => context.read<ReaderPrefs>().setScale(
                      ReaderPrefs.scales[scaleIndex - 1],
                    ),
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
                    onTap: () => context.read<ReaderPrefs>().setScale(
                      ReaderPrefs.scales[scaleIndex + 1],
                    ),
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
                onSelectionChanged: (selection) =>
                    context.read<ReaderPrefs>().setLineHeight(selection.first),
              ),
              _SectionLabel('主题', theme),
              Row(
                children: [
                  Expanded(
                    child: _AutoThemeCell(
                      selected: prefs.readingTheme == ReaderPrefs.autoTheme,
                      theme: theme,
                      onTap: () => context.read<ReaderPrefs>().setReadingTheme(
                        ReaderPrefs.autoTheme,
                      ),
                    ),
                  ),
                  for (final t in ReadingTheme.all)
                    Expanded(
                      child: _ThemeSwatch(
                        swatch: t,
                        selected: prefs.readingTheme == t.id,
                        selectedColor: theme.accent,
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

/// 主题自动档格子：圆形描边容器 + brightness_auto 图标，下方小字
/// 「跟随 App 深浅色」；选中时描当前主题 accent 边。
class _AutoThemeCell extends StatelessWidget {
  const _AutoThemeCell({
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final bool selected;
  final ReadingTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? theme.accent : theme.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.bg,
              border: Border.all(
                color: selected ? theme.accent : theme.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(Icons.brightness_auto_rounded, size: 20, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            '跟随 App\n深浅色',
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, height: 1.3, color: color),
          ),
        ],
      ),
    );
  }
}

/// 背景主题圆形色块：bg 填充 + 自身 divider 色 1px 描边，选中 accent 2px。
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.swatch,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final ReadingTheme swatch;
  final bool selected;
  final Color selectedColor;
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: swatch.bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? selectedColor : swatch.divider,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            swatch.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: selected ? selectedColor : swatch.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 阅读正文底部融入式状态条：`20:05 · 86% · 12/45 · 38%`。
///
/// - 整体被 IgnorePointer 包裹（由调用方负责），绝不挡翻页/菜单手势；
/// - 时间：立即一次 + Timer 15s 刷新；电量：battery_plus 流（charging 也
///   只显示百分比）；章节序号由父级传入；进度复用精确进度 ValueNotifier；
/// - 菜单层打开时淡出隐藏（菜单自身带进度信息），关闭后 150ms 淡入恢复。
class _ReaderStatusBar extends StatefulWidget {
  const _ReaderStatusBar({
    required this.ratio,
    required this.orderText,
    required this.title,
    required this.visible,
    required this.color,
    required this.background,
  });

  final ValueNotifier<double> ratio;

  /// 「当前章 order/总章数」，空串则整段隐藏。
  final String orderText;

  /// 当前章节标题，展示在状态条左侧（长标题省略）。
  final String title;

  final bool visible;

  final Color color;

  /// 主题背景色：底部渐变的基色，让 HUD 与正文区过渡自然。
  final Color background;

  @override
  State<_ReaderStatusBar> createState() => _ReaderStatusBarState();
}

class _ReaderStatusBarState extends State<_ReaderStatusBar> {
  String _clock = '';
  int? _batteryLevel;
  async.Timer? _clockTimer;
  async.StreamSubscription<BatteryState>? _batterySub;

  @override
  void initState() {
    super.initState();
    _tickClock();
    _refreshBattery();
    _clockTimer = async.Timer.periodic(const Duration(seconds: 15), (_) {
      _tickClock();
      // 电量随 15s 节拍一起刷新（v6 流只报充放电状态变化，不报 level）。
      _refreshBattery();
    });
    _listenBatteryState();
  }

  void _tickClock() {
    if (mounted) setState(() => _clock = formatHm(DateTime.now()));
  }

  void _refreshBattery() {
    Battery().batteryLevel
        .then((level) {
          if (mounted) setState(() => _batteryLevel = level);
        })
        .catchError((_) {
          // 插件不可用（部分桌面/测试环境）：电量段保持隐藏。
        });
  }

  /// 充放电状态变化（插/拔电源）立即刷一次电量。
  void _listenBatteryState() {
    try {
      _batterySub = Battery().onBatteryStateChanged.listen(
        (_) => _refreshBattery(),
        onError: (_) {},
        cancelOnError: true,
      );
    } catch (_) {
      // 平台通道缺失同样降级：只剩 15s 节拍刷新。
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _batterySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final segments = <String>[
      if (_clock.isNotEmpty) _clock,
      if (_batteryLevel != null) '$_batteryLevel%',
      if (widget.orderText.isNotEmpty) widget.orderText,
    ];
    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      // 沉浸式下系统导航栏已隐藏，SafeArea 反而虚占高度；改用主题背景色
      // 向上渐隐的薄雾底，让 HUD 与正文让位区过渡自然。
      child: Container(
        alignment: Alignment.bottomCenter,
        // 左右 16px：圆角屏底部弯边会裁掉贴边文字。
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [widget.background.withValues(alpha: 0), widget.background],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  letterSpacing: 0.5,
                  color: widget.color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder<double>(
              valueListenable: widget.ratio,
              builder: (context, ratio, _) => Text(
                [...segments, '${(ratio * 100).round()}%'].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  letterSpacing: 0.5,
                  color: widget.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 过卷翻章胶囊的瞬时状态（ValueNotifier 驱动，避免整页 setState）。
class _FlipHint {
  const _FlipHint.initial()
    : direction = 0,
      amount = 0,
      blocked = false,
      title = '',
      visible = false;

  const _FlipHint({
    required this.direction,
    required this.amount,
    required this.blocked,
    required this.title,
    required this.visible,
  });

  /// 1 = 底部过卷（下一章），-1 = 顶部过卷（上一章），0 = 隐藏。
  final int direction;

  /// 当前方向累计的过卷量（逻辑像素）。
  final double amount;

  /// 首章/末章：对应方向只提示「已是第一/最后一章」，永不导航。
  final bool blocked;

  /// 目标章标题（灰态为空）。
  final String title;

  /// 胶囊是否可见（收起动画期间保留内容但 visible=false）。
  final bool visible;

  /// 累计/阈值（0~1）。
  double get progress =>
      (amount / _ReaderPageState._flipThreshold).clamp(0.0, 1.0).toDouble();
}

/// 始终接受用户拖拽的滚动物理：内容不满一屏（maxScrollExtent==0）时默认
/// 物理会拒绝拖拽，短章就拉不出过卷翻章提示；此物理强制接受。
class _AlwaysAcceptDragPhysics extends ScrollPhysics {
  const _AlwaysAcceptDragPhysics({required ScrollPhysics parent})
    : super(parent: parent);

  @override
  @override
  ScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _AlwaysAcceptDragPhysics(parent: parent!.applyTo(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;
}
