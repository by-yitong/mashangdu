import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/api_client.dart';
import '../state/library_store.dart';
import '../state/settings_store.dart';
import '../state/theme_store.dart';
import '../state/update_checker.dart';
import '../widgets/design.dart';
import '../widgets/update_dialog.dart';

/// 设置子页（入口在个人页）：外观（跟随系统/浅色/深色）+ 关于与更新。
/// 账号、观看历史入口已移至个人页。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: colors.paper,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: const [
          _AppearanceCard(),
          SizedBox(height: 14),
          _ReadingCard(),
          SizedBox(height: 14),
          _AboutCard(),
        ],
      ),
    );
  }
}

/// 外观卡片:跟随系统 / 浅色 / 深色。
class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  static const Map<ThemeMode, String> _labels = {
    ThemeMode.system: '跟随系统',
    ThemeMode.light: '浅色',
    ThemeMode.dark: '深色',
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = context.watch<ThemeStore>();
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '外观',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '深浅色跟随此处设置，默认跟随系统',
            style: TextStyle(fontSize: 12, height: 1.4, color: colors.inkMuted),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: [
              for (final entry in _labels.entries)
                ButtonSegment(value: entry.key, label: Text(entry.value)),
            ],
            selected: {theme.mode},
            onSelectionChanged: (selection) =>
                context.read<ThemeStore>().setMode(selection.first),
            style: SegmentedButton.styleFrom(
              foregroundColor: colors.inkMuted,
              selectedForegroundColor: colors.onAccent,
              selectedBackgroundColor: colors.accent,
              side: BorderSide(color: colors.track),
            ),
          ),
        ],
      ),
    );
  }
}

/// 阅读卡片:打开 app 时继续上一次阅读开关（默认开，SettingsStore 持久化）。
class _ReadingCard extends StatelessWidget {
  const _ReadingCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final settings = context.watch<SettingsStore>();
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '阅读',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.read<SettingsStore>().setResumeOnLaunch(
              !settings.resumeOnLaunch,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '打开时继续上次阅读',
                          style: TextStyle(fontSize: 14, color: colors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '退出时停留在阅读页，下次打开直接回到该章节',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.resumeOnLaunch,
                    onChanged: (value) =>
                        context.read<SettingsStore>().setResumeOnLaunch(value),
                    activeThumbColor: colors.accent,
                    activeTrackColor: colors.accentDim,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 关于卡片：App 版本（package_info_plus）、内容版本（LibraryStore.meta
/// 的 versionDate）、检查更新按钮（GET /app/latest 对比 versionCode）。
class _AboutCard extends StatefulWidget {
  const _AboutCard();

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  String _appVersion = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    PackageInfo info;
    try {
      info = await PackageInfo.fromPlatform();
    } catch (_) {
      // 插件不可用（测试环境等）：保留占位版本号。
      return;
    }
    if (!mounted) return;
    setState(() => _appVersion = '${info.version}+${info.buildNumber}');
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final release = await UpdateChecker(context.read<ApiClient>()).checkNewer();
      if (!mounted) return;
      if (release == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('已是最新版本')),
        );
      } else {
        await showUpdateDialog(context, release);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(error.message.isEmpty ? '检查更新失败' : error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('网络不可用，检查更新失败')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final library = context.watch<LibraryStore>();
    final contentVersion = library.meta?.versionDate ?? '—';

    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '关于',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 10),
          _AboutRow(label: 'App 版本', value: _appVersion),
          _AboutRow(label: '内容版本', value: contentVersion),
          const SizedBox(height: 4),
          _RepoRow(),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _checking ? null : _checkUpdate,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.accent,
                side: BorderSide(color: colors.accent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _checking
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accent,
                      ),
                    )
                  : const Icon(Icons.system_update_alt_rounded, size: 18),
              label: Text(
                _checking ? '正在检查…' : '检查更新',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: colors.inkMuted),
          ),
          const Spacer(),
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(fontSize: 13, color: colors.ink),
          ),
        ],
      ),
    );
  }
}

/// 开源地址行：点按用浏览器打开仓库主页。
class _RepoRow extends StatelessWidget {
  static const String repoUrl = 'https://github.com/by-yitong/mashangdu';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => launchUrl(
        Uri.parse(repoUrl),
        mode: LaunchMode.externalApplication,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              '开源地址',
              style: TextStyle(fontSize: 13, color: colors.inkMuted),
            ),
            const Spacer(),
            Text(
              'github.com/by-yitong/mashangdu',
              style: TextStyle(
                fontSize: 13,
                color: colors.accent,
                decoration: TextDecoration.underline,
                decorationColor: colors.accent.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 14, color: colors.inkMuted),
          ],
        ),
      ),
    );
  }
}
