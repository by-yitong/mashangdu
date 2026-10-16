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
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GlassScaffold 的 bottomBar 子树必须有 Material 祖先，否则导航标签
/// 落回框架兜底文本样式（等宽字体 + 双下划线）。回归测试见
/// mobile/lib/app.dart HomeShell。
class _NoopLibraryStore extends LibraryStore {
  _NoopLibraryStore(super.api, super.cache);

  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('底部导航标签不继承兜底样式的双下划线', (tester) async {
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

    for (final label in const ['首页', '我的']) {
      final labelFinder = find
          .byWidgetPredicate((w) => w is Text && w.data == label)
          .first;
      expect(labelFinder, findsOneWidget, reason: '找不到标签 $label');

      // 实际渲染样式（RichText span = DefaultTextStyle.merge 后的结果）
      // 就近的 Material 文本样式会遮蔽更上层来源，这里只看最终生效值。
      final richText = tester.widget<RichText>(
        find
            .descendant(of: labelFinder, matching: find.byType(RichText))
            .first,
      );
      final span = richText.text as TextSpan;
      expect(
        span.style?.decoration?.contains(TextDecoration.underline),
        isFalse,
        reason: '[$label] 标签带上了下划线：${span.style}',
      );
      expect(
        span.style?.debugLabel?.contains('fallback style'),
        isFalse,
        reason: '[$label] 标签落回了框架兜底样式（缺 Material 祖先）',
      );
    }
  });
}
