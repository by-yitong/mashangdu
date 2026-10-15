import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'state/library_store.dart';
import 'widgets/design.dart';

class CodeTutorialsApp extends StatelessWidget {
  const CodeTutorialsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '码上读',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
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

/// 根壳：IndexedStack 首页/设置 + 底部液态玻璃胶囊导航 + 圆形同步主按钮。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    // 首次进入即同步（网络失败自动回退缓存）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryStore>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GlassScaffold(
      backgroundColor: colors.paper,
      // GlassScaffold 不是 Material Scaffold，不提供 Material 祖先；
      // 页面里的 InkWell/TextButton 需要它才能渲染。
      body: Material(
        type: MaterialType.transparency,
        child: IndexedStack(
          index: _tabIndex,
          children: [
            HomePage(onGoSettings: () => setState(() => _tabIndex = 1)),
            const SettingsPage(),
          ],
        ),
      ),
      bottomBar: GlassTabBar.bottom(
        selectedIndex: _tabIndex,
        onTabSelected: (index) => setState(() => _tabIndex = index),
        iconSize: 20,
        horizontalPadding: 24,
        verticalPadding: 18,
        barHeight: 56,
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
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
