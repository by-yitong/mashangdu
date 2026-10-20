import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import 'models/models.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/reader_page.dart';
import 'state/api_client.dart';
import 'state/library_store.dart';
import 'state/settings_store.dart';
import 'state/resume_store.dart';
import 'state/theme_store.dart';
import 'state/update_checker.dart';
import 'widgets/design.dart';
import 'widgets/update_dialog.dart';

/// 全局导航 Key：401 失效回调（main）在任意路由下定位 Navigator 跳登录页。
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CodeTutorialsApp extends StatelessWidget {
  const CodeTutorialsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '码上读',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: context.watch<ThemeStore>().mode,
      home: const HomeShell(),
    );
  }

  /// Material 3 + design.md token 覆盖（深色下 surface/container 用卡片/背景 token）。
  static ThemeData buildTheme(Brightness brightness) {
    final colors = brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.seedColor,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          onPrimary: colors.onAccent,
          primaryContainer: colors.accentDim,
          onPrimaryContainer: colors.accent,
          surface: colors.paper,
          surfaceContainerLowest: colors.card,
          surfaceContainerLow: colors.card,
          surfaceContainer: colors.card,
          surfaceContainerHigh: colors.card,
          surfaceContainerHighest: colors.card,
          onSurface: colors.ink,
          onSurfaceVariant: colors.inkMuted,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.paper,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.paper,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: colors.ink,
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.track, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.card,
        contentTextStyle: TextStyle(color: colors.ink, fontSize: 13),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 根壳：PageView 首页/设置（左右滑动切换）+ 底部液态玻璃胶囊导航。
///
/// 底栏跟随：本地分叉的 GlassTabBar 支持 `swipePosition`（页面位置
/// ValueNotifier，做法学自 timer0173/timerq）——PageController 每帧把
/// 小数页码写进去，药丸指示器逐像素跟手；松手后 onPageChanged 提交
/// 整数 selectedIndex。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  late final PageController _pageController = PageController(
    initialPage: _tabIndex,
  );

  /// 内容区实时页码（0..1 连续值），喂给底栏的 swipePosition。
  final ValueNotifier<double> _swipePosition = ValueNotifier<double>(0);

  /// 底栏玻璃亮度直通：主题切换时立即翻转，不等包内亮度级联重解析。
  late final ValueNotifier<Brightness> _barBrightness;
  late final ThemeStore _themeStore;

  @override
  void initState() {
    super.initState();
    _themeStore = context.read<ThemeStore>();
    WidgetsBinding.instance.addObserver(this);
    _barBrightness = ValueNotifier<Brightness>(_resolveBarBrightness());
    _themeStore.addListener(_syncBarBrightness);
    _pageController.addListener(_syncSwipePosition);
    // 首次进入即同步（网络失败自动回退缓存）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryStore>().refresh();
    });
    // 启动恢复上一次阅读：只执行一次（_resumeAttempted 守卫），等首帧 +
    // 400ms 缓冲再推栈，避免与同步/更新弹窗抢首屏；推栈前检查 mounted。
    // 用可取消 Timer（dispose 时取消），壳被销毁时不留悬挂定时器。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resumeTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) _tryRestoreReading();
      });
    });
    // 启动静默检查更新：有新版才弹窗，任何失败静默忽略。
    unawaited(_silentCheckUpdate());
  }

  /// 启动恢复守卫：_tryRestoreReading 只允许执行一次，防重复推栈。
  bool _resumeAttempted = false;

  /// 启动恢复的延迟定时器（首帧后 400ms），dispose 时取消。
  Timer? _resumeTimer;

  /// 读取 `resume.*` 记录并恢复：开关关 → 丢弃陈旧记录后停留首页；
  /// 记录不存在（退出阅读页时已清除）→ 正常停留首页；
  /// 记录存在且开关开 → 直接推 ReaderPage（章节内进度由其自身逻辑恢复）。
  void _tryRestoreReading() {
    if (_resumeAttempted) return;
    _resumeAttempted = true;
    if (!context.read<SettingsStore>().resumeOnLaunch) {
      unawaited(context.read<ResumeStore>().exitReading());
      return;
    }
    final pending = context.read<ResumeStore>().pendingResume();
    if (pending == null) return;
    final CourseSummary course = pending.course;
    final String chapterSlug = pending.chapterSlug;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(course: course, chapterSlug: chapterSlug),
      ),
    );
  }

  Future<void> _silentCheckUpdate() async {
    try {
      final release = await UpdateChecker(
        context.read<ApiClient>(),
      ).checkSilently();
      if (!mounted || release == null) return;
      await showUpdateDialog(context, release);
    } catch (_) {
      // 静默失败：不打扰启动。
    }
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _themeStore.removeListener(_syncBarBrightness);
    _barBrightness.dispose();
    _pageController
      ..removeListener(_syncSwipePosition)
      ..dispose();
    _swipePosition.dispose();
    super.dispose();
  }

  /// 显式指定浅/深时直接用；跟随系统时读平台亮度。
  /// 注意 initState 里就会调用——不能用 MediaQuery（继承查找），走
  /// platformDispatcher 的非 widget API。
  Brightness _resolveBarBrightness() {
    final mode = _themeStore.mode;
    if (mode == ThemeMode.light) return Brightness.light;
    if (mode == ThemeMode.dark) return Brightness.dark;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  void _syncBarBrightness() {
    if (mounted) _barBrightness.value = _resolveBarBrightness();
  }

  @override
  void didChangePlatformBrightness() {
    // 仅跟随系统模式下需要响应系统深浅切换。
    if (_themeStore.mode == ThemeMode.system) {
      _syncBarBrightness();
    }
  }

  void _syncSwipePosition() {
    final controller = _pageController;
    if (!controller.hasClients || !controller.position.hasContentDimensions) {
      return;
    }
    _swipePosition.value = controller.page ?? _tabIndex.toDouble();
  }

  /// 点 tab / 「去设置」跳页：页面与底栏药丸一起动画过去。
  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // GlassScaffold 不是 Material Scaffold，不提供 Material 祖先；
    // body 和 bottomBar 是它的两个平行子树，都得包进来——漏掉
    // bottomBar 的话，导航标签会落回框架兜底文本样式（双下划线）。
    return Material(
      type: MaterialType.transparency,
      child: GlassScaffold(
        backgroundColor: colors.paper,
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _tabIndex = index),
          children: [
            HomePage(onGoSettings: () => _goToPage(1)),
            const ProfilePage(),
          ],
        ),
        bottomBar: GlassTabBar.bottom(
          selectedIndex: _tabIndex,
          onTabSelected: _goToPage,
          swipePosition: _swipePosition,
          brightnessOverride: _barBrightness,
          iconSize: 18,
          horizontalPadding: 40,
          verticalPadding: 14,
          barHeight: 48,
          indicatorColor: colors.accentDim,
          selectedIconColor: colors.accent,
          selectedLabelColor: colors.accent,
          unselectedIconColor: colors.inkMuted,
          unselectedLabelColor: colors.inkMuted,
          tabs: const [
            GlassTab(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: '首页',
            ),
            GlassTab(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
