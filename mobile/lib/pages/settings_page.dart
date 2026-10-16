import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/theme_store.dart';
import '../widgets/design.dart';

/// 设置页：外观（跟随系统/浅色/深色）。
///
/// 服务器地址配置已移除（SettingsStore/ApiClient 保留，App 内部仍使用
/// 默认地址）；页面只保留外观卡片与页脚。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final topPadding = MediaQuery.paddingOf(context).top + 12;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 120),
      children: [
        Text(
          '设置',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 16),
        const _AppearanceCard(),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Center(
            child: Text(
              '码上读 · 内容在线更新，支持离线阅读',
              style: TextStyle(fontSize: 13, color: colors.inkMuted),
            ),
          ),
        ),
      ],
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
