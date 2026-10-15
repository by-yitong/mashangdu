import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'state/api_client.dart';
import 'state/content_cache.dart';
import 'state/library_store.dart';
import 'state/progress_store.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 液态玻璃：先预热着色器，再以 brightnessResolver 桥接 Material 主题。
  await LiquidGlassWidgets.initialize();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs)..load();
  final apiClient = ApiClient(settings.serverUrl);
  // 服务器地址变更时同步生效到 API 客户端。
  settings.addListener(() => apiClient.updateServerUrl(settings.serverUrl));

  runApp(
    LiquidGlassWidgets.wrap(
      adaptiveQuality: true,
      respectSystemAccessibility: true,
      brightnessResolver: Theme.maybeBrightnessOf,
      child: MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: settings),
          Provider<ApiClient>.value(value: apiClient),
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
        ],
        child: const CodeTutorialsApp(),
      ),
    ),
  );
}
