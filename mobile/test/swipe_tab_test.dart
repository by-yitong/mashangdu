import 'package:code_tutorials/app.dart';
import 'package:code_tutorials/state/api_client.dart';
import 'package:code_tutorials/state/auth_store.dart';
import 'package:code_tutorials/state/content_cache.dart';
import 'package:code_tutorials/state/download_store.dart';
import 'package:code_tutorials/state/library_store.dart';
import 'package:code_tutorials/state/progress_store.dart';
import 'package:code_tutorials/state/reader_prefs.dart';
import 'package:code_tutorials/state/settings_store.dart';
import 'package:code_tutorials/state/theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 首页 PageView 与底栏 GlassTabBar(swipePosition 注入)的联动回归：
/// 拖动中药丸小数跟随、松手停靠、点 tab 动画跳页。
///
/// 手势注意：
/// - 拖动必须拆成多段小 moveBy（每段 < touchSlop）。单次大位移在有垂直
///   滚动子树竞争时会被识别器整段当作 slop 起点吃掉，不产生 onUpdate。
/// - 玻璃组件与 DrivenScrollActivity 都要多帧小步 pump 推进，单次大时长
///   pump 只跑一帧，且不能用 pumpAndSettle（玻璃有常驻微动画）。
class _NoopLibraryStore extends LibraryStore {
  _NoopLibraryStore(super.api, super.cache);

  @override
  Future<void> refresh() async {}
}

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final apiClient = ApiClient('http://127.0.0.1:1');
  final cache = ContentCache(prefs);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(
          value: SettingsStore(prefs)..load(),
        ),
        ChangeNotifierProvider<ThemeStore>.value(
          value: ThemeStore(prefs)..load(),
        ),
        ChangeNotifierProvider<ReaderPrefs>.value(
          value: ReaderPrefs(prefs)..load(),
        ),
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthStore>.value(
          value: AuthStore(prefs, apiClient),
        ),
        Provider<ContentCache>.value(value: cache),
        ChangeNotifierProvider<ProgressStore>(
          create: (_) => ProgressStore(prefs),
        ),
        ChangeNotifierProvider<LibraryStore>(
          create: (_) => _NoopLibraryStore(apiClient, cache),
        ),
        ChangeNotifierProvider<DownloadStore>(
          create: (_) => DownloadStore(apiClient, cache),
        ),
      ],
      child: const CodeTutorialsApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// 药丸（AnimatedGlassIndicator）当前对齐 x：-1 = 左槽，+1 = 右槽。
double _pillAlignmentX(WidgetTester tester) {
  final indicators = tester
      .widgetList<AnimatedGlassIndicator>(find.byType(AnimatedGlassIndicator))
      .toList();
  expect(indicators, isNotEmpty, reason: '找不到药丸指示器');
  final alignment = indicators.first.alignment;
  expect(alignment, isA<Alignment>());
  return (alignment as Alignment).x;
}

Future<void> _settleFrames(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('拖动页面时药丸小数跟随，松手停靠到目标页', (tester) async {
    await _pumpApp(tester);
    expect(_pillAlignmentX(tester), closeTo(-1.0, 0.05));

    // 从无交互控件的区域起手（空态中央是「前往设置」玻璃按钮，会抢手势）。
    final gesture = await tester.startGesture(const Offset(120, 120));
    // 8 段 × -60px ≈ 拖过 55%，中途（前 5 段后）药丸应停在两页之间。
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(-60, 0));
      // 弹簧动画需要有时间步进的帧（pump() 的 0ms 帧推不动弹簧）。
      await tester.pump(const Duration(milliseconds: 30));
      if (i == 4) {
        final midX = _pillAlignmentX(tester);
        expect(midX, greaterThan(-0.9), reason: '拖动近半，药丸应离开左槽');
        expect(midX, lessThan(0.9), reason: '尚未松手，药丸不应已停在右槽');
      }
    }
    await gesture.up();
    await _settleFrames(tester);
    expect(_pillAlignmentX(tester), closeTo(1.0, 0.05));
    expect(find.text('我的'), findsWidgets);
  });

  testWidgets('点击底部 tab 动画切换页面', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('我的').first);
    await _settleFrames(tester);
    expect(_pillAlignmentX(tester), closeTo(1.0, 0.05));

    await tester.tap(find.text('首页').first);
    await _settleFrames(tester);
    expect(_pillAlignmentX(tester), closeTo(-1.0, 0.05));
  });
}
