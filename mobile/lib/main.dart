import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'pages/login_page.dart';
import 'pages/splash_page.dart';
import 'state/api_client.dart';
import 'state/auth_store.dart';
import 'state/content_cache.dart';
import 'state/download_store.dart';
import 'state/library_store.dart';
import 'state/progress_store.dart';
import 'state/reader_prefs.dart';
import 'state/settings_store.dart';
import 'state/theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 液态玻璃：先预热着色器，再以 brightnessResolver 桥接 Material 主题。
  await LiquidGlassWidgets.initialize();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs)..load();
  final theme = ThemeStore(prefs)..load();
  final readerPrefs = ReaderPrefs(prefs)..load();
  final apiClient = ApiClient(settings.serverUrl);
  // 服务器地址变更时同步生效到 API 客户端。
  settings.addListener(() => apiClient.updateServerUrl(settings.serverUrl));

  final auth = AuthStore(prefs, apiClient)..load();
  // 401（AUTH_UNAUTHORIZED）：清登录态、提示并跳登录页。
  apiClient.onUnauthorized = () => _handleUnauthorized(auth);

  runApp(
    LiquidGlassWidgets.wrap(
      adaptiveQuality: true,
      respectSystemAccessibility: true,
      brightnessResolver: Theme.maybeBrightnessOf,
      child: _SplashGate(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsStore>.value(value: settings),
            ChangeNotifierProvider<ThemeStore>.value(value: theme),
            ChangeNotifierProvider<ReaderPrefs>.value(value: readerPrefs),
            Provider<ApiClient>.value(value: apiClient),
            ChangeNotifierProvider<AuthStore>.value(value: auth),
            Provider<ContentCache>(create: (_) => ContentCache(prefs)),
            ChangeNotifierProvider<ProgressStore>(
              create: (_) => ProgressStore(prefs),
            ),
            ChangeNotifierProvider<LibraryStore>(
              create: (context) => LibraryStore(
                context.read<ApiClient>(),
                context.read<ContentCache>(),
              ),
            ),
            ChangeNotifierProvider<DownloadStore>(
              create: (context) => DownloadStore(
                context.read<ApiClient>(),
                context.read<ContentCache>(),
              ),
            ),
          ],
          child: const CodeTutorialsApp(),
        ),
      ),
    ),
  );
}

/// 401（AUTH_UNAUTHORIZED）：清登录态、提示并跳登录页。
///
/// 用全局 [navigatorKey] 定位导航（回调发生时可能在任意路由）；
/// 登录页已压栈期间后续 401 不重复压栈（登录页 pop 后恢复）。
bool _loginPromptInFlight = false;

Future<void> _handleUnauthorized(AuthStore auth) async {
  if (_loginPromptInFlight) return;
  _loginPromptInFlight = true;
  // 先取导航/提示所需对象，再 await（BuildContext 不跨异步间隙使用）。
  final context = navigatorKey.currentContext;
  final messenger = context == null ? null : ScaffoldMessenger.maybeOf(context);
  final navigator = navigatorKey.currentState;
  await auth.handleUnauthorized();
  if (navigator != null) {
    await navigator
        .push(MaterialPageRoute<void>(builder: (_) => const LoginPage()))
        .then((_) => _loginPromptInFlight = false);
  } else {
    _loginPromptInFlight = false;
  }
  messenger?.showSnackBar(
    const SnackBar(content: Text('登录已失效，请重新登录')),
  );
}

/// 启动过渡根：先渲染 [SplashPage]（图标 + 应用名 + 加载指示），
/// 等首帧渲染完成且满 600ms 后切换到正式根（MultiProvider 结构原样保留）。
class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.child});

  final Widget child;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _enter();
  }

  Future<void> _enter() async {
    await Future.wait<void>([
      WidgetsBinding.instance.endOfFrame,
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    // Splash 阶段还没有 CodeTutorialsApp 的 MaterialApp，这里临时给一个
    // 同主题的壳，保证 SplashPage 取色/文字方向正常。
    return MaterialApp(
      title: '码上读',
      debugShowCheckedModeBanner: false,
      theme: CodeTutorialsApp.buildTheme(Brightness.light),
      darkTheme: CodeTutorialsApp.buildTheme(Brightness.dark),
      home: const SplashPage(),
    );
  }
}
